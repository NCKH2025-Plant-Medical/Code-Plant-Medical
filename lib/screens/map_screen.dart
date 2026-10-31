// lib/screens/map_screen.dart
//
// Màn hình Bản đồ GPS sử dụng OpenStreetMap (flutter_map):
//  ✅ 1. Nhận diện vị trí GPS máy ảo & nhắc chuyển về Việt Nam
//  ✅ 2. Tối ưu hoá 60 FPS cực mượt (chỉ re-render MarkerLayer, không rebuild Map)
//  ✅ 3. Tìm kiếm tức thì cây hệ thống (không dấu/có dấu, chống lỗi gõ)
//  ✅ 4. Khắc phục triệt để lỗi LatLngBounds out-of-range khi zoom xa
//  ✅ 5. Bộ lọc nguồn cây + chế độ "Quanh đây" (bán kính 1–5 km)
//  ✅ 6. Đồng bộ chuẩn 46x46dp cho cả nút Zoom (+ / -) và nút Định vị (My Location)
//  ✅ 7. 100% thông báo qua error_dialog

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:thunghiem1/controllers/auth_notifier.dart';
import 'package:thunghiem1/controllers/map_notifier.dart';
import 'package:thunghiem1/models/plant_map_marker.dart';
import 'package:thunghiem1/screens/account_screen.dart';
import 'package:thunghiem1/screens/sign_in_screen.dart';
import 'package:thunghiem1/theme/app_colors.dart';
import 'package:thunghiem1/widgets/back_nav_button.dart';
import 'package:thunghiem1/widgets/error_dialog.dart';
import 'package:thunghiem1/widgets/map_plant_detail_sheet.dart';
import 'package:thunghiem1/widgets/search_text_field.dart';

class PlantMapScreen extends StatefulWidget {
  /// Tọa độ cần zoom tới khi mở màn hình (từ Lịch sử bấm icon bản đồ).
  final LatLng? focusLocation;

  const PlantMapScreen({super.key, this.focusLocation});

  @override
  State<PlantMapScreen> createState() => _PlantMapScreenState();
}

class _PlantMapScreenState extends State<PlantMapScreen> {
  late final MapNotifier _notifier;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notifier = MapNotifier(onEvent: _handleUiEvent);
    _notifier.addListener(_handleNotifierChange);
    _notifier.initialize();

    final focus = widget.focusLocation;
    if (focus != null) {
      _notifier.focusOnLocation(focus);
    }

    // Thông báo trải nghiệm khách nếu chưa đăng nhập
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthNotifier>();
      if (!auth.isAuthenticated) {
        showErrorDialog(
          context,
          'Bạn đang trải nghiệm Bản đồ với tư cách Khách.\n'
          'Bạn có thể tự do xem các cây hệ thống trên bản đồ. '
          'Để xem và lưu trữ cây cá nhân của mình, vui lòng đăng nhập tài khoản.',
          title: 'Chế độ Khách',
        );
      }
    });
  }

  @override
  void dispose() {
    _notifier.removeListener(_handleNotifierChange);
    _notifier.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Lắng nghe state changes ───────────────────────────────────────────────

  void _handleNotifierChange() {
    if (!mounted) return;

    if (_searchController.text != _notifier.searchQuery) {
      _searchController.value = TextEditingValue(
        text: _notifier.searchQuery,
        selection: TextSelection.collapsed(offset: _notifier.searchQuery.length),
      );
    }

    final detailPlant = _notifier.detailSheetPlant;
    if (detailPlant != null) {
      _notifier.clearDetailSheetEvent();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        MapPlantDetailSheet.show(context, detailPlant, notifier: _notifier);
      });
    }

    final selected = _notifier.selectedMarker;
    if (selected != null) {
      _notifier.clearSelection();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        MapPlantDetailSheet.show(context, selected, notifier: _notifier);
      });
    }
  }

  // ── 7. Tất cả thông báo qua error_dialog ───────────────────────────────────

  void _handleUiEvent(MapUiEvent event) {
    if (!mounted) return;

    switch (event) {
      case MapDialogEvent(:final message, :final title):
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showErrorDialog(context, message, title: title);
        });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MapNotifier>.value(
      value: _notifier,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Consumer<MapNotifier>(
          builder: (context, notifier, _) {
            final isCarouselVisible =
                notifier.isCarouselVisible &&
                notifier.carouselPlants.isNotEmpty &&
                !notifier.isNavigating;
            final controlsBottomOffset = isCarouselVisible ? 186.0 : 24.0;

            return Stack(
              children: [
                // 1. OpenStreetMap Layer (Tối ưu mượt mà 60 FPS, không re-instantiate map)
                const Positioned.fill(child: _OsmMapLayer()),

                // 2. Loading overlay nhỏ gọn
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 160,
                  left: 0,
                  right: 0,
                  child: const _LoadingIndicator(),
                ),

                // 3. Header: Title + Search + Compact Unified Filter bar
                Positioned(top: 0, left: 0, right: 0, child: _buildHeader()),

                // 4. Panel kết quả tìm kiếm (Cây hệ thống theo tên)
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 116,
                  left: 16,
                  right: 16,
                  child: const _SearchResultsPanel(),
                ),

                // 5. Cụm nút điều khiển bản đồ (Theme + Zoom + My Location)
                // Luôn hiển thị kể cả khi bật bán kính 3km (nổi lên trên Card Carousel)
                Positioned(
                  bottom: controlsBottomOffset,
                  right: 16,
                  child: const _MapControlButtons(),
                ),

                // 6. Legend (chú thích màu)
                Positioned(
                  bottom: controlsBottomOffset,
                  left: 16,
                  child: const _MapLegend(),
                ),

                // 7. Carousel ngang danh sách cây (cho phép gỡt qua cây đè nhau & bay map)
                const Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: _NearbyPlantsCarousel(),
                ),

                // 8. Card dẫn đường / chỉ đường GPS ở đáy màn hình
                const Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: _NavigationBottomBanner(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40, height: 40, child: BackNavButton()),
                  Text(
                    'Plant Map',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  // 3. Avatar người dùng
                  const _UserHeaderAvatar(),
                ],
              ),
              const SizedBox(height: 10),
              // 1. Thanh Search tìm cây thuốc (có dấu / không dấu / lỗi gõ)
              SearchTextField(
                hintText: 'Tìm kiếm cây thuốc theo tên...',
                heroTag: 'search_bar_map',
                readOnly: false,
                controller: _searchController,
                onChanged: (value) => _notifier.setSearchQuery(value),
              ),
              const SizedBox(height: 10),
              // Cụm lọc ngang tích hợp: Tất cả / Hệ thống / Cá nhân + Quanh đây (bán kính)
              const _CompactFilterBar(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 2. OpenStreetMap Layer (Tối ưu 60 FPS, không re-instantiate FlutterMap) ───

class _OsmMapLayer extends StatelessWidget {
  const _OsmMapLayer();

  @override
  Widget build(BuildContext context) {
    // Chỉ đọc controller và config 1 lần duy nhất, tránh rebuild map gây lag
    final notifier = context.read<MapNotifier>();

    return FlutterMap(
      mapController: notifier.mapController,
      options: MapOptions(
        initialCenter: notifier.initialCenter,
        initialZoom: notifier.initialZoom,
        minZoom: 5.0,
        maxZoom: 18.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        onMapReady: notifier.onMapReady,
        onPositionChanged: notifier.onPositionChanged,
        onTap: (_, __) {
          FocusScope.of(context).unfocus();
          notifier.clearSearch();
          notifier.clearSpeciesHighlight();
        },
      ),
      children: [
        // Lớp nền gạch bản đồ đa theme (Tiêu chuẩn OSM / Sáng dịu mắt / Tối thanh lịch)
        Consumer<MapNotifier>(
          builder: (_, notif, __) => TileLayer(
            key: ValueKey(notif.currentTheme),
            urlTemplate: notif.currentTheme.urlTemplate,
            subdomains: notif.currentTheme.subdomains,
            userAgentPackageName: 'com.example.thunghiem1',
            maxZoom: 19,
            tileBuilder: (context, tileWidget, tile) {
              if (notif.currentTheme == MapTileTheme.dark) {
                return ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    -0.7, 0, 0, 0, 215,
                    0, -0.7, 0, 0, 215,
                    0, 0, -0.65, 0, 225,
                    0, 0, 0, 1, 0,
                  ]),
                  child: tileWidget,
                );
              } else if (notif.currentTheme == MapTileTheme.light) {
                // Sáng dịu mắt: Tông màu ấm dịu, lọc ánh sáng xanh
                return ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    0.96, 0.04, 0.0, 0, 10,
                    0.0, 0.96, 0.04, 0, 10,
                    0.0, 0.0, 0.88, 0, 4,
                    0,    0,    0,    1, 0,
                  ]),
                  child: tileWidget,
                );
              }
              return tileWidget;
            },
          ),
        ),
        // Lớp bán kính (quanh vị trí người dùng) khi bật Cây quanh đây
        Consumer<MapNotifier>(
          builder: (_, notif, __) => CircleLayer(
            circles: [
              if (notif.isNearbyActive && notif.userLocation != null)
                CircleMarker(
                  point: notif.userLocation!,
                  useRadiusInMeter: true,
                  radius: notif.nearbyRadiusKm * 1000.0,
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.16),
                  borderColor: const Color(0xFF1B5E20),
                  borderStrokeWidth: 2.8,
                ),
            ],
          ),
        ),
        // Lớp chỉ đường: Polyline lộ trình từ GPS người dùng tới cây
        Consumer<MapNotifier>(
          builder: (_, notif, __) => PolylineLayer(
            polylines: [
              if (notif.routePoints.isNotEmpty)
                Polyline(
                  points: notif.routePoints,
                  strokeWidth: 5.0,
                  color: const Color(0xFF1E88E5),
                  borderStrokeWidth: 2.5,
                  borderColor: Colors.white,
                ),
            ],
          ),
        ),
        // Chỉ re-render MarkerLayer khi danh sách markers thay đổi
        Consumer<MapNotifier>(
          builder: (_, notif, __) => MarkerLayer(
            markers: [
              ...notif.markers,
              // Marker vị trí người dùng (Xoay hướng realtime theo bearing/compass)
              if (notif.userLocation != null &&
                  notif.permissionState == MapPermissionState.granted)
                Marker(
                  point: notif.userLocation!,
                  width: notif.isNavigating ? 42 : 32,
                  height: notif.isNavigating ? 42 : 32,
                  child: Transform.rotate(
                    angle: notif.currentBearing * (pi / 180.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.navigation_rounded,
                          color: Colors.white,
                          size: notif.isNavigating ? 24 : 18,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 5. Cụm Listbox lọc gọn gàng: Nguồn cây & Quanh đây ──────────────────────

class _CompactFilterBar extends StatelessWidget {
  const _CompactFilterBar();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Listbox Nguồn cây (Tất cả, Cây hệ thống, Cây cá nhân)
          _SourceListbox(),
          SizedBox(width: 8),
          // 2. Listbox Cây quanh bạn (Tuỳ chỉnh bán kính 1km - 5km)
          _NearbyListbox(),
        ],
      ),
    );
  }
}

// ── Listbox Nguồn cây (Tất cả / Hệ thống / Cá nhân) ──────────────────────────

class _SourceListbox extends StatelessWidget {
  const _SourceListbox();

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<MapNotifier>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filter = notifier.filter;
    final String label;
    final IconData icon;
    final Color activeColor;

    switch (filter) {
      case MapSourceFilter.all:
        label = 'Tất cả';
        icon = Icons.layers_rounded;
        activeColor = AppColors.primary;
        break;
      case MapSourceFilter.system:
        label = 'Hệ thống';
        icon = Icons.eco_rounded;
        activeColor = const Color(0xFF1565C0);
        break;
      case MapSourceFilter.user:
        label = 'Cá nhân';
        icon = Icons.camera_alt_rounded;
        activeColor = const Color(0xFFE65100);
        break;
    }

    final isAll = filter == MapSourceFilter.all;

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: isDark ? AppColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 6,
        ),
      ),
      child: PopupMenuButton<MapSourceFilter>(
        tooltip: 'Chọn nguồn cây',
        offset: const Offset(0, 42),
        onSelected: (selected) {
          if (selected == MapSourceFilter.user) {
            final auth = context.read<AuthNotifier>();
            if (!auth.isAuthenticated) {
              _showLoginDialog(context);
              return;
            }
          }
          notifier.setFilter(selected);
        },
        itemBuilder: (context) => [
          _buildMenuItem(
            context,
            value: MapSourceFilter.all,
            label: 'Tất cả cây',
            icon: Icons.layers_rounded,
            iconColor: AppColors.primary,
            isSelected: filter == MapSourceFilter.all,
          ),
          _buildMenuItem(
            context,
            value: MapSourceFilter.system,
            label: 'Cây hệ thống',
            icon: Icons.eco_rounded,
            iconColor: const Color(0xFF1565C0),
            isSelected: filter == MapSourceFilter.system,
          ),
          _buildMenuItem(
            context,
            value: MapSourceFilter.user,
            label: 'Cây cá nhân',
            icon: Icons.camera_alt_rounded,
            iconColor: const Color(0xFFE65100),
            isSelected: filter == MapSourceFilter.user,
          ),
        ],
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: isAll
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.shade100)
                : activeColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAll
                  ? (isDark ? Colors.white24 : Colors.grey.shade300)
                  : activeColor,
              width: 1.2,
            ),
            boxShadow: !isAll
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isAll
                    ? (isDark ? Colors.white70 : Colors.grey.shade700)
                    : Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isAll
                      ? (isDark ? Colors.white : Colors.grey.shade800)
                      : Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: isAll
                    ? (isDark ? Colors.white70 : Colors.grey.shade600)
                    : Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<MapSourceFilter> _buildMenuItem(
    BuildContext context, {
    required MapSourceFilter value,
    required String label,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
  }) {
    return PopupMenuItem<MapSourceFilter>(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? iconColor : null,
              ),
            ),
          ),
          if (isSelected) Icon(Icons.check_rounded, size: 18, color: iconColor),
        ],
      ),
    );
  }
}

// ── Listbox Cây quanh bạn (Bán kính 1km - 5km) ───────────────────────────────

class _NearbyListbox extends StatelessWidget {
  const _NearbyListbox();

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<MapNotifier>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = notifier.isNearbyActive;
    final isLoading = notifier.isNearbyLoading;
    final radius = notifier.nearbyRadiusKm;
    const activeColor = Color(0xFF2E7D32);
    const radiusOptions = [1.0, 2.0, 3.0, 4.0, 5.0];

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: isDark ? AppColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 6,
        ),
      ),
      child: PopupMenuButton<double>(
        tooltip: 'Chọn bán kính quanh bạn',
        offset: const Offset(0, 42),
        onSelected: (selectedRadius) {
          if (selectedRadius == 0.0) {
            notifier.exitNearbyMode();
          } else {
            notifier.setNearbyRadius(selectedRadius);
          }
        },
        itemBuilder: (context) => [
          if (isActive) ...[
            PopupMenuItem<double>(
              value: 0.0,
              child: const Row(
                children: [
                  Icon(Icons.layers_clear_rounded, size: 16, color: Colors.redAccent),
                  SizedBox(width: 10),
                  Text(
                    'Tắt tìm quanh đây (Hiện tất cả)',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(height: 1),
          ],
          ...radiusOptions.map((r) {
            final isSelected = isActive && (radius - r).abs() < 0.1;
            return PopupMenuItem<double>(
              value: r,
              child: Row(
                children: [
                  Icon(
                    Icons.adjust_rounded,
                    size: 16,
                    color: isSelected ? activeColor : Colors.grey,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bán kính ${r.toInt()} km',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? activeColor : null,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_rounded, size: 18, color: activeColor),
                ],
              ),
            );
          }),
        ],
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor
                : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE8F5E9)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: activeColor, width: 1.2),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(
                  Icons.radar_rounded,
                  size: 15,
                  color: isActive
                      ? Colors.white
                      : (isDark ? const Color(0xFF81C784) : activeColor),
                ),
              const SizedBox(width: 6),
              Text(
                isActive ? 'Quanh đây (${radius.toInt()}km)' : 'Quanh đây',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? Colors.white
                      : (isDark ? Colors.white : activeColor),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: isActive ? Colors.white70 : activeColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showLoginDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: AppColors.primary),
          SizedBox(width: 8),
          Text(
            'Yêu cầu đăng nhập',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: const Text(
        'Bạn cần đăng nhập tài khoản để xem và quản lý danh sách cây cá nhân của mình trên bản đồ.',
        style: TextStyle(fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Để sau', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SignInScreen()),
            );
          },
          child: const Text(
            'Đăng nhập ngay',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

// ── 6. Cụm nút điều khiển bản đồ đồng bộ kích thước chuẩn 46x46dp ─────────────

class _MapControlButtons extends StatelessWidget {
  const _MapControlButtons();

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<MapNotifier>();
    final granted = notifier.permissionState == MapPermissionState.granted;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Chỉ ẩn cụm điều khiển khi đang ở chế độ dẫn đường chi tiết
    if (notifier.isNavigating) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Nút đổi màu / theme SDK bản đồ (2-3 màu lựa chọn dịu mắt)
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showThemeBottomSheet(context, notifier),
            icon: const Icon(
              Icons.palette_outlined,
              color: AppColors.primary,
              size: 22,
            ),
            tooltip: 'Đổi kiểu màu sắc bản đồ',
          ),
        ),
        const SizedBox(height: 12),

        // 2. Khối nút Zoom (+ / -) chuẩn 46dp chiều rộng
        Container(
          width: 46,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 46,
                height: 44,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.add_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  onPressed: notifier.zoomIn,
                  tooltip: 'Phóng to',
                ),
              ),
              const Divider(height: 1, thickness: 1, indent: 6, endIndent: 6),
              SizedBox(
                width: 46,
                height: 44,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.remove_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  onPressed: notifier.zoomOut,
                  tooltip: 'Thu nhỏ',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3. Nút Định vị My Location chuẩn 46x46dp đồng bộ hoàn hảo
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: notifier.focusMyLocation,
            icon: Icon(
              granted
                  ? Icons.my_location_rounded
                  : Icons.location_searching_rounded,
              color: granted ? AppColors.primary : Colors.grey.shade700,
              size: 22,
            ),
            tooltip: 'Vị trí của tôi',
          ),
        ),
      ],
    );
  }

  static void _showThemeBottomSheet(BuildContext context, MapNotifier notifier) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.palette_outlined, color: AppColors.primary),
                        SizedBox(width: 10),
                        Text(
                          'Kiểu màu sắc bản đồ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  ...MapTileTheme.values.map((theme) {
                    final isSelected = notifier.currentTheme == theme;
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          theme == MapTileTheme.standard
                              ? Icons.map_outlined
                              : theme == MapTileTheme.light
                              ? Icons.wb_sunny_outlined
                              : Icons.nightlight_round_outlined,
                          color: isSelected ? AppColors.primary : Colors.grey,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        theme.label,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: isSelected ? AppColors.primary : null,
                        ),
                      ),
                      subtitle: Text(
                        theme.description,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                            )
                          : null,
                      onTap: () {
                        notifier.setTheme(theme);
                        Navigator.pop(ctx);
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Banner chỉ đường GPS ở đáy màn hình ───────────────────────────────────────

class _NavigationBottomBanner extends StatelessWidget {
  const _NavigationBottomBanner();

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<MapNotifier>();
    if (!notifier.isNavigating) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFF1E88E5), width: 2),
      ),
      child: Row(
        children: [
          Transform.rotate(
            angle: notifier.currentBearing * (pi / 180.0),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF1E88E5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.navigation_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Dẫn đường tới: ${notifier.navigationDestination?.name ?? "Cây"}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      notifier.navigationDistanceDisplay.isNotEmpty
                          ? notifier.navigationDistanceDisplay
                          : '${notifier.navigationDistanceKm.toStringAsFixed(1).replaceAll('.', ',')} km',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E88E5),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•  ${notifier.navigationDurationDisplay.isNotEmpty ? notifier.navigationDurationDisplay : "Khoảng ${notifier.navigationDurationMinutes} phút"}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: notifier.stopNavigation,
            icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 26),
            tooltip: 'Dừng dẫn đường',
          ),
        ],
      ),
    );
  }
}

// ── 3. Panel kết quả tìm kiếm (Cây hệ thống theo tên) ─────────────────────────────

class _SearchResultsPanel extends StatelessWidget {
  const _SearchResultsPanel();

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<MapNotifier>();
    if (notifier.searchQuery.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: notifier.searchResults.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Không tìm thấy cây thuốc nào phù hợp với từ khóa.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: notifier.searchResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final plant = notifier.searchResults[index];
                final isSystem = plant.source == PlantSource.system;

                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: (isSystem
                              ? const Color(0xFF1565C0)
                              : const Color(0xFFE65100))
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isSystem ? Icons.eco_rounded : Icons.camera_alt_rounded,
                      color: isSystem
                          ? const Color(0xFF1565C0)
                          : const Color(0xFFE65100),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    plant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    plant.scientificName ??
                        (isSystem ? 'Cây hệ thống' : 'Cây cá nhân'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    notifier.focusPlant(plant);
                  },
                );
              },
            ),
    );
  }
}

// ── 5. Carousel ngang hiển thị cây (cho phép gỡt qua cây đè nhau & bay map) ─

class _NearbyPlantsCarousel extends StatefulWidget {
  const _NearbyPlantsCarousel();

  @override
  State<_NearbyPlantsCarousel> createState() => _NearbyPlantsCarouselState();
}

class _NearbyPlantsCarouselState extends State<_NearbyPlantsCarousel> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<MapNotifier>();
    if (!notifier.isCarouselVisible ||
        notifier.carouselPlants.isEmpty ||
        notifier.isNavigating) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plants = notifier.carouselPlants;

    // Đồng bộ trang carousel nếu vị trí chọn thay đổi từ tap marker trên map
    if (_pageController.hasClients &&
        _pageController.page?.round() != notifier.selectedCarouselIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            notifier.selectedCarouselIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Thanh tiêu đề phụ có nút đóng carousel
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface.withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      notifier.isNearbyActive
                          ? Icons.radar_rounded
                          : Icons.layers_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      notifier.isNearbyActive
                          ? 'Cây quanh bạn (${plants.length} cây)'
                          : (plants.length > 1 &&
                                  plants.every(
                                    (p) =>
                                        p.name.trim().toLowerCase() ==
                                        plants.first.name.trim().toLowerCase(),
                                  )
                              ? '${plants.first.name} (${plants.length} vị trí)'
                              : (plants.length > 1
                                  ? 'Cây tại vị trí này (${plants.length} cây)'
                                  : plants.first.name)),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: notifier.closeCarousel,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.close_rounded, size: 16),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 134,
          child: PageView.builder(
            controller: _pageController,
            itemCount: plants.length,
            onPageChanged: (index) {
              notifier.onCarouselPageChanged(index);
            },
            itemBuilder: (context, index) {
              final plant = plants[index];
              final isSystem = plant.source == PlantSource.system;
              final isSelected = index == notifier.selectedCarouselIndex;

              return AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: isSelected ? 1.0 : 0.96,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isSelected ? 0.2 : 0.08,
                        ),
                        blurRadius: isSelected ? 12 : 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(
                      color: isSelected
                          ? (isSystem
                                ? const Color(0xFF1565C0)
                                : const Color(0xFFE65100))
                          : Colors.grey.withValues(alpha: 0.2),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        // Nhấn vào Card Carousel -> mở bottom sheet cây
                        notifier.openPlantDetailFromCard(plant);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            // Thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 68,
                                height: 68,
                                color: (isSystem
                                        ? const Color(0xFF1565C0)
                                        : const Color(0xFFE65100))
                                    .withValues(alpha: 0.1),
                                child:
                                    (plant.imageUrl != null &&
                                        plant.imageUrl!.isNotEmpty)
                                    ? Image.network(
                                        plant.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          isSystem
                                              ? Icons.eco
                                              : Icons.camera_alt,
                                          color: isSystem
                                              ? const Color(0xFF1565C0)
                                              : const Color(0xFFE65100),
                                          size: 28,
                                        ),
                                      )
                                    : Icon(
                                        isSystem
                                            ? Icons.eco
                                            : Icons.camera_alt,
                                        color: isSystem
                                            ? const Color(0xFF1565C0)
                                            : const Color(0xFFE65100),
                                        size: 28,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    plant.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    plant.scientificName ??
                                        (isSystem
                                            ? 'Cây hệ thống'
                                            : 'Cây cá nhân'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Nguồn dữ liệu badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (isSystem
                                                      ? const Color(0xFF1565C0)
                                                      : const Color(0xFFE65100))
                                                  .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          plant.source.label,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isSystem
                                                ? const Color(0xFF1565C0)
                                                : const Color(0xFFE65100),
                                          ),
                                        ),
                                      ),
                                      // Nút chỉ đường rõ ràng, chuẩn kích thước mobile
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          notifier.startNavigationTo(plant);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF1E88E5,
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 7,
                                          ),
                                          minimumSize: const Size(0, 36),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.directions_rounded,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Chỉ đường',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Loading Indicator ─────────────────────────────────────────────────────────

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<MapNotifier>();

    if (notifier.loadState != MapLoadState.loading) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Đang tải dữ liệu...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Map Legend ────────────────────────────────────────────────────────────────

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifier = context.watch<MapNotifier>();

    // Chỉ ẩn khi đang ở chế độ dẫn đường chi tiết (để nhường chỗ cho banner dẫn đường)
    if (notifier.isNavigating) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendItem(color: Color(0xFF1565C0), label: 'Cây hệ thống'),
          SizedBox(height: 6),
          _LegendItem(color: Color(0xFFE65100), label: 'Cây cá nhân'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 3,
                offset: Offset(0, 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

// ── 3. Avatar người dùng trên Header ──────────────────────────────────────────

class _UserHeaderAvatar extends StatelessWidget {
  const _UserHeaderAvatar();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthNotifier>(
      builder: (context, auth, _) {
        final avatarUrl = auth.userProfile?['avatar_url'] as String?;
        final isAuthenticated = auth.isAuthenticated;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountScreen()),
            );
          },
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: (isAuthenticated &&
                      avatarUrl != null &&
                      avatarUrl.trim().isNotEmpty)
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildFallback(),
                    )
                  : _buildFallback(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallback() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 22),
    );
  }
}
