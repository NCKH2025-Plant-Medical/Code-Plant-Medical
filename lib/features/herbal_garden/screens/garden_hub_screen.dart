// lib/features/herbal_garden/screens/garden_hub_screen.dart
//
// TRANG TỔNG QUAN "VƯỜN DƯỢC LIỆU" (hub)
//
// Đây là trang cửa vào của chức năng vườn — người dùng bấm thẻ "Vườn Dược
// Liệu" ở Dashboard (thẻ 3) sẽ vào đây. Trang này KHÔNG đổ dữ liệu chi tiết
// mà chỉ làm 2 việc:
//
//   1. Tóm tắt nhanh: số cây, số việc hôm nay, tổng kg đã thu, thời tiết.
//   2. Bảng "ô bánh" (hub tiles) — mỗi ô là 1 trang con:
//        • Vườn của tôi   → GardenScreen
//        • Việc hôm nay  → GardenCareScreen (trang mới)
//        • Thêm cây       → GardenAddPlantScreen
//        • Cây đã xoá    → GardenDeletedScreen
//
// API được gọi (giống hệt màn hình "Vườn của tôi"):
//   GET  /api/v1/herbal-garden
//   GET  /api/v1/herbal-garden/care-today
//   GET  /api/v1/herbal-garden/weather
//   GET  /api/v1/herbal-garden/deleted

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:thunghiem1/config/app_config.dart';
import 'package:thunghiem1/controllers/auth_notifier.dart';
import 'package:thunghiem1/features/herbal_garden/screens/garden_add_plant_screen.dart';
import 'package:thunghiem1/features/herbal_garden/screens/garden_care_screen.dart';
import 'package:thunghiem1/features/herbal_garden/screens/garden_deleted_screen.dart';
import 'package:thunghiem1/features/herbal_garden/screens/garden_screen.dart';
import 'package:thunghiem1/features/herbal_garden/state/herbal_garden_state.dart';
import 'package:thunghiem1/features/herbal_garden/utils/garden_location.dart';
import 'package:thunghiem1/features/herbal_garden/widgets/garden_cards.dart';
import 'package:thunghiem1/features/herbal_garden/widgets/garden_style.dart';
import 'package:thunghiem1/theme/app_colors.dart';

class GardenHubScreen extends StatefulWidget {
  const GardenHubScreen({super.key});

  @override
  State<GardenHubScreen> createState() => _GardenHubScreenState();
}

class _GardenHubScreenState extends State<GardenHubScreen> {
  @override
  void dispose() {
    // Huỷ yêu cầu vị trí để không để lại timer pending.
    _locationRequest?.cancel();
    _locationRequest = null;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final controller = context.read<HerbalGardenController>();
    // ⚠️ Đọc `auth` TRƯỚC mọi await để không dùng BuildContext qua async gap.
    final auth = context.read<AuthNotifier>();

    // 1) Tải dữ liệu chính NGAY — không chờ plugin (auth/GPS) vì nếu plugin
    //    treo thì `await` sẽ chặn vĩnh viễn → màn hình trắng.
    await controller.loadAll();
    if (mounted) await controller.loadDeleted();

    // 2) Đồng bộ uid nếu backend bật chế độ vườn riêng theo tài khoản.
    //
    // ⚠️ KHÔNG `await auth.ready` ở đây: đọc secure storage là call plugin
    // native, có thể treo → chặn luồng. Và `ready` dùng `Future.timeout`
    // sẽ tạo timer pending → widget test assert fail.
    if (AppConfig.gardenPerUser) {
      await auth.ready.timeout(const Duration(seconds: 5), onTimeout: () {});
      if (!mounted) return;
      controller.setUid(auth.userId);
      await controller.loadAll(refresh: true);
      if (mounted) await controller.loadDeleted();
    }

    // 3) Cập nhật thời tiết theo vị trí thật (nếu lấy được GPS).
    //
    // ⚠️ KHÔNG await ở đây: trong widget test plugin Geolocator không có
    // handler → Future treo → timer 8s còn pending → assert fail.
    if (!mounted) return;
    unawaited(_refreshWeatherByPosition(controller));
  }

  /// Lấy GPS rồi cập nhật thời tiết — không chặn luồng chính.
  Future<void> _refreshWeatherByPosition(
    HerbalGardenController controller,
  ) async {
    final position = await _tryGetPosition();
    if (position == null) return;
    await controller.loadWeather(
      refresh: true,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<void> _refresh() async {
    final controller = context.read<HerbalGardenController>();
    final position = await _tryGetPosition();
    await controller.loadAll(
      refresh: true,
      latitude: position?.latitude,
      longitude: position?.longitude,
    );
    if (mounted) await controller.loadDeleted();
  }

  /// Yêu cầu vị trí đang chạy — huỷ khi màn hình bị dispose để không để lại
  /// timer pending (widget test assert "A Timer is still pending").
  GardenLocationRequest? _locationRequest;

  /// Lấy GPS hiện tại — trả `null` nếu người dùng từ chối quyền hoặc
  /// plugin bị treo (xem `garden_location.dart`).
  Future<Position?> _tryGetPosition() async {
    _locationRequest?.cancel();
    final request = requestGardenPosition();
    _locationRequest = request;
    final position = await request.future;
    if (identical(_locationRequest, request)) _locationRequest = null;
    return position;
  }

  // ── Điều hướng ───────────────────────────────────────────────────────────

  Future<void> _open(GardenHubTile tile) async {
    final controller = context.read<HerbalGardenController>();
    switch (tile) {
      case GardenHubTile.myGarden:
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const GardenScreen()),
        );
        // ⚠️ `refreshAll()` — gồm cả `loadDeleted()` để badge "Cây đã xoá" và
        // "cây trong vườn" trên Hub luôn khớp với server sau khi xoá/khôi phục.
        if (mounted) await controller.refreshAll();
      case GardenHubTile.todayTasks:
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const GardenCareScreen()),
        );
        if (mounted) await controller.loadCare(refresh: true);
      case GardenHubTile.addPlant:
        final added = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(builder: (_) => const GardenAddPlantScreen()),
        );
        if (added == true && mounted) await controller.refreshAll();
      case GardenHubTile.deleted:
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const GardenDeletedScreen()),
        );
        if (mounted) await controller.refreshAll();
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HerbalGardenController>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: <Widget>[
              _buildHero(controller),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildQuickStats(controller),
                      const SizedBox(height: 22),
                      _buildSectionTitle(
                        'Các chức năng',
                        'Chọn một ô để bắt đầu',
                      ),
                      const SizedBox(height: 12),
                      _buildTiles(controller),
                      const SizedBox(height: 24),
                      _buildSectionTitle(
                        'Thời tiết vườn',
                        'Gợi ý tưới nước hôm nay',
                      ),
                      const SizedBox(height: 12),
                      GardenWeatherCard(
                        weather: controller.weather,
                        loading: controller.isLoadingWeather,
                        error: controller.weatherError,
                        onRetry: () => controller.loadWeather(),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero (header gradient) ──────────────────────────────────────────────

  Widget _buildHero(HerbalGardenController controller) {
    final deletedCount = controller.deletedPlants.length;
    final careCount = controller.care.total;

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFF1B4332), Color(0xFF2D6A4F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                // Nút quay lại tường minh.
                _RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Quay lại',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.yard_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Vườn Dược Liệu',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        controller.care.date.isNotEmpty
                            ? 'Hôm nay · ${gardenFormatDate(DateTime.tryParse(controller.care.date))}'
                            : 'Khu vườn dược liệu của bạn',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                _RoundIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Làm mới',
                  onTap: _refresh,
                ),
              ],
            ),
            const SizedBox(
              height: 16,
            ), // Nhịp sống của vườn — 3 chỉ số nhỏ trên nền hero.
            Row(
              children: <Widget>[
                _HeroPill(
                  icon: Icons.local_florist_rounded,
                  value: '${controller.totalPlants}',
                  label: 'cây',
                ),
                const SizedBox(width: 8),
                _HeroPill(
                  icon: Icons.task_alt_rounded,
                  value: '$careCount',
                  label: 'việc',
                  highlight: careCount > 0,
                ),
                const SizedBox(width: 8),
                _HeroPill(
                  icon: Icons.delete_outline_rounded,
                  value: '$deletedCount',
                  label: 'đã xoá',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.black.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  // ── Số liệu nhanh ───────────────────────────────────────────────────────

  Widget _buildQuickStats(HerbalGardenController controller) {
    return GardenStatStrip(
      totalPlants: controller.totalPlants,
      tasksToday: controller.care.total,
      totalHarvestKg: controller.tongKhoiLuongThuHoachKg,
    );
  }

  // ── Bảng ô bánh ─────────────────────────────────────────────────────────

  Widget _buildTiles(HerbalGardenController controller) {
    final care = controller.care;
    final tiles = <_HubTileData>[
      _HubTileData(
        tile: GardenHubTile.myGarden,
        title: 'Vườn của tôi',
        subtitle: 'Xem & quản lý cây',
        icon: Icons.yard_rounded,
        color: AppColors.primary,
        badge: '${controller.totalPlants}',
        badgeLabel: 'cây',
        big: true,
      ),
      _HubTileData(
        tile: GardenHubTile.todayTasks,
        title: 'Việc hôm nay',
        subtitle: 'Tưới · cắt tỉa · thu hoạch',
        icon: Icons.task_alt_rounded,
        color: const Color(0xFF3B82C4),
        badge: '${care.total}',
        badgeLabel: 'việc',
        badgeAlert: care.total > 0,
      ),
      _HubTileData(
        tile: GardenHubTile.addPlant,
        title: 'Thêm cây',
        subtitle: 'Tìm loài theo tên',
        icon: Icons.add_circle_rounded,
        color: AppColors.success,
      ),
      _HubTileData(
        tile: GardenHubTile.deleted,
        title: 'Cây đã xoá',
        subtitle: 'Khôi phục cây đã ẩn',
        icon: Icons.restore_rounded,
        color: const Color(0xFF8A9BA8),
        badge: '${controller.deletedPlants.length}',
        badgeLabel: 'cây',
        badgeAlert: false,
      ),
    ];

    return Column(
      children: <Widget>[
        // Ô lớn (chiếm 1/2 hàng) — "Vườn của tôi".
        _HubBigTile(data: tiles[0], onTap: () => _open(tiles[0].tile)),
        const SizedBox(height: 12),
        // 3 ô nhỏ xếp dọc.
        ...tiles
            .skip(1)
            .map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HubSmallTile(data: t, onTap: () => _open(t.tile)),
              ),
            ),
      ],
    );
  }
}

// ── Enum các ô của hub ────────────────────────────────────────────────────

enum GardenHubTile { myGarden, todayTasks, addPlant, deleted }

class _HubTileData {
  final GardenHubTile tile;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? badge;
  final String? badgeLabel;
  final bool badgeAlert;
  final bool big;

  const _HubTileData({
    required this.tile,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.badge,
    this.badgeLabel,
    this.badgeAlert = false,
    this.big = false,
  });
}

// ── Widget: pill nhỏ trên hero ────────────────────────────────────────────

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool highlight;

  const _HeroPill({
    required this.icon,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: highlight ? 0.22 : 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget: ô bánh lớn ────────────────────────────────────────────────────

class _HubBigTile extends StatelessWidget {
  final _HubTileData data;
  final VoidCallback onTap;

  const _HubBigTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: <Color>[data.color, data.color.withValues(alpha: 0.78)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: data.color.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              // Họa tiết trang trí góc phải — giúp ô bớt "cứng".
              Positioned(
                right: -26,
                top: -26,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.09),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                right: 22,
                bottom: -34,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(data.icon, size: 22, color: Colors.white),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      data.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12.5,
                      ),
                    ),
                    if (data.badge != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              data.badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              data.badgeLabel ?? '',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget: ô bánh nhỏ (ngang) ────────────────────────────────────────────

class _HubSmallTile extends StatelessWidget {
  final _HubTileData data;
  final VoidCallback onTap;

  const _HubSmallTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkSurfaceVariant
        : Colors.white;

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: Theme.of(context).brightness == Brightness.dark
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: data.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(data.icon, size: 21, color: data.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              data.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (data.badge != null) ...<Widget>[
                            const SizedBox(width: 6),
                            _TileBadge(
                              value: data.badge!,
                              label: data.badgeLabel ?? '',
                              color: data.badgeAlert
                                  ? const Color(0xFFD64545)
                                  : data.color,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.black26,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widget: badge số nhỏ ──────────────────────────────────────────────────

class _TileBadge extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _TileBadge({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (label.isNotEmpty) ...<Widget>[
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.85),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Widget: nút tròn trên hero ────────────────────────────────────────────

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 19, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
