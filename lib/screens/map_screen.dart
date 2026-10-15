// lib/screens/map_screen.dart
//
// Màn hình Bản đồ GPS tích hợp đầy đủ:
//  ✅ Google Maps (GoogleMapWidget)
//  ✅ Xin quyền định vị, focus current location
//  ✅ onCameraIdle + Debounce 500ms
//  ✅ Future.wait gọi đồng thời 2 API (system + user plants)
//  ✅ Cluster Marker (ClusterManager)
//  ✅ Custom Icons pre-loaded (tránh jank)
//  ✅ Partial Failure → Toast
//  ✅ Permission Denied → Default location + Banner "Bật vị trí"
//  ✅ Mất mạng → Load cache + Snackbar đỏ
//  ✅ Provider quản lý state (MapNotifier)

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'package:thunghiem1/controllers/map_notifier.dart';
import 'package:thunghiem1/theme/app_colors.dart';
import 'package:thunghiem1/widgets/search_text_field.dart';
import 'package:thunghiem1/widgets/back_nav_button.dart';

class PlantMapScreen extends StatefulWidget {
  const PlantMapScreen({super.key});

  @override
  State<PlantMapScreen> createState() => _PlantMapScreenState();
}

class _PlantMapScreenState extends State<PlantMapScreen> {
  late final MapNotifier _notifier;

  @override
  void initState() {
    super.initState();
    // Tạo notifier và khởi tạo (xin quyền + pre-load icons)
    _notifier = MapNotifier();
    _notifier.addListener(_handleNotifierChange);
    _notifier.initialize
      ();
  }

  @override
  void dispose() {
    _notifier.removeListener(_handleNotifierChange);
    _notifier.dispose();
    super.dispose();
  }

  // ── Lắng nghe state changes ───────────────────────────────────────────────

  void _handleNotifierChange() {
    if (!mounted) return;

    // Partial failure → fluttertoast
    if (_notifier.partialError != null) {
      Fluttertoast.showToast(
        msg: _notifier.partialError!,
        backgroundColor: Colors.orange.shade800,
        textColor: Colors.white,
        gravity: ToastGravity.TOP,
        toastLength: Toast.LENGTH_LONG,
      );
    }

    // Offline → Snackbar đỏ
    if (_notifier.isOffline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Không có mạng – đang hiển thị dữ liệu đã lưu',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MapNotifier>.value(
      value: _notifier,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Stack(
          children: [
            // 1. Google Maps lấp đầy màn hình
            const Positioned.fill(child: _GoogleMapLayer()),

            // 2. Banner cảnh báo mất quyền định vị
            const _LocationPermissionBanner(),

            // 3. Loading overlay nhỏ gọn (không block map)
            const _LoadingIndicator(),

            // 4. Header (Search + Title) đè lên map
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildHeader(),
            ),

            // 5. FAB My Location
            const Positioned(
              bottom: 24,
              right: 16,
              child: _MyLocationFab(),
            ),

            // 6. Legend (chú thích màu)
            const Positioned(
              bottom: 80,
              left: 16,
              child: _MapLegend(),
            ),
          ],
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
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(25)),
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: BackNavButton(),
                  ),
                  Text(
                    'Plant Map',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  // Nút làm mới thủ công
                  Consumer<MapNotifier>(
                    builder: (_, notifier, __) => Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: notifier.loadState == MapLoadState.loading
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.refresh,
                                  color: Colors.white, size: 18),
                              onPressed: notifier.retry,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SearchTextField(
                hintText: 'Tìm kiếm cây trồng....',
                heroTag: 'search_bar_map',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Google Map Layer ──────────────────────────────────────────────────────────

class _GoogleMapLayer extends StatelessWidget {
  const _GoogleMapLayer();

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<MapNotifier>();

    return GoogleMap(
      initialCameraPosition: notifier.initialCamera,
      markers: notifier.markers,
      myLocationEnabled: notifier.permissionState == MapPermissionState.granted,
      myLocationButtonEnabled: false, // dùng FAB tuỳ chỉnh
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: notifier.onMapCreated,
      onCameraIdle: notifier.onCameraIdle,
      onCameraMoveStarted: notifier.onCameraMoveStarted,
    );
  }
}

// ── Permission Banner ─────────────────────────────────────────────────────────

class _LocationPermissionBanner extends StatelessWidget {
  const _LocationPermissionBanner();

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<MapNotifier>();

    if (!notifier.showLocationBanner) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade800,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.location_off, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chưa có quyền định vị',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notifier.permissionState ==
                              MapPermissionState.deniedForever
                          ? 'Vào Cài đặt để cấp quyền vị trí cho ứng dụng'
                          : 'Đang hiển thị bản đồ mặc định (Hà Nội)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: notifier.permissionState ==
                        MapPermissionState.deniedForever
                    ? notifier.openLocationSettings
                    : notifier.initialize, // thử lại xin quyền
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.orange.shade800,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  notifier.permissionState == MapPermissionState.deniedForever
                      ? 'Bật vị trí'
                      : 'Cấp quyền',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

    return Positioned(
      top: 160, // dưới header
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
      ),
    );
  }
}

// ── My Location FAB ───────────────────────────────────────────────────────────

class _MyLocationFab extends StatelessWidget {
  const _MyLocationFab();

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<MapNotifier>();

    return FloatingActionButton.small(
      heroTag: 'map_location_fab',
      onPressed: notifier.permissionState == MapPermissionState.granted
          ? () => notifier.initialize() // re-focus vị trí
          : notifier.openLocationSettings,
      backgroundColor: Colors.white,
      elevation: 4,
      child: Icon(
        notifier.permissionState == MapPermissionState.granted
            ? Icons.my_location
            : Icons.location_disabled,
        color: notifier.permissionState == MapPermissionState.granted
            ? AppColors.primary
            : Colors.grey,
        size: 20,
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendItem(
            color: const Color(0xFF1565C0),
            label: 'Cây hệ thống',
          ),
          const SizedBox(height: 6),
          _LegendItem(
            color: const Color(0xFFE65100),
            label: 'Cây cá nhân',
          ),
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
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}