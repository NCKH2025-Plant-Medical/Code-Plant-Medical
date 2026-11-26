// lib/features/herbal_garden/screens/garden_screen.dart
//
// MÀN HÌNH 1 — "VƯỜN CỦA TÔI"
//
// Đây là màn hình trung tâm của chức năng Vườn Dược Liệu. Toàn bộ luồng
// được gói trong 1 trang cuộn duy nhất: thời tiết → việc hôm nay → cây trong
// vườn → thao tác nhanh. Các màn hình con (chi tiết cây, thêm cây, cây đã
// xoá) được push từ đây.
//
// API được gọi:
//   GET  /api/v1/herbal-garden          → danh sách cây
//   GET  /api/v1/herbal-garden/care-today → việc hôm nay
//   GET  /api/v1/herbal-garden/weather    → thời tiết + gợi ý tưới
//   POST /api/v1/herbal-garden/{id}/water → ghi nhận đã tưới
//   POST /api/v1/herbal-garden/{id}/harvest → ghi sổ thu hoạch
//   POST /api/v1/herbal-garden/{id}/task/dismiss → gỡ thẻ việc

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:thunghiem1/config/app_config.dart';
import 'package:thunghiem1/controllers/auth_notifier.dart';
import 'package:thunghiem1/features/herbal_garden/models/garden_models.dart';
import 'package:thunghiem1/features/herbal_garden/screens/garden_add_plant_screen.dart';
import 'package:thunghiem1/features/herbal_garden/screens/garden_deleted_screen.dart';
import 'package:thunghiem1/features/herbal_garden/screens/garden_plant_detail_screen.dart';
import 'package:thunghiem1/features/herbal_garden/state/herbal_garden_state.dart';
import 'package:thunghiem1/features/herbal_garden/utils/garden_location.dart';
import 'package:thunghiem1/features/herbal_garden/widgets/garden_cards.dart';
import 'package:thunghiem1/features/herbal_garden/widgets/garden_style.dart';
import 'package:thunghiem1/theme/app_colors.dart';

class GardenScreen extends StatefulWidget {
  const GardenScreen({super.key});

  @override
  State<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends State<GardenScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    // Huỷ yêu cầu vị trí để không để lại timer pending.
    _locationRequest?.cancel();
    _locationRequest = null;
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final controller = context.read<HerbalGardenController>();
    // ⚠️ Đọc `auth` TRƯỚC mọi await để không dùng BuildContext qua async gap.
    final auth = context.read<AuthNotifier>();

    // 1) Tải dữ liệu chính NGAY, không chờ bất kỳ plugin nào.
    //
    // ⚠️ `auth.ready` và GPS đều là call tới plugin native. Nếu plugin treo
    // hoặc lỗi, `await` sẽ chặn vĩnh viễn → màn hình trắng, không có dữ
    // liệu, không có banner lỗi. Vì vậy: tải dữ liệu trước, phần phụ làm sau.
    await controller.loadAll();
    if (mounted) await controller.loadDeleted();

    // 2) Đồng bộ uid nếu backend bật vườn riêng theo tài khoản.
    //
    // ⚠️ KHÔNG `await auth.ready` ở đây: đọc secure storage là call plugin
    // native, có thể treo → chặn luồng. Và `ready` dùng `Future.timeout`
    // sẽ tạo timer pending → widget test assert fail.
    //
    // Cách an toàn: đọc trạng thái đăng nhập KHÔNG chặn — chỉ dùng uid nếu
    // đã sẵn sàng, còn không thì vẫn dùng vườn mẫu như cũ.
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
    // Chạy "fire and forget": dữ liệu chính đã tải xong, thời tiết là phần
    // phụ nên cập nhật sau cũng được.
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

  /// Yêu cầu vị trí đang chạy — huỷ khi màn hình bị dispose để không để lại
  /// timer pending (widget test assert "A Timer is still pending").
  GardenLocationRequest? _locationRequest;

  /// Lấy GPS hiện tại — trả `null` nếu người dùng từ chối quyền hoặc
  /// plugin bị treo (xem `garden_location.dart` để biết lý do).
  Future<Position?> _tryGetPosition() async {
    _locationRequest?.cancel();
    final request = requestGardenPosition();
    _locationRequest = request;
    final position = await request.future;
    if (identical(_locationRequest, request)) _locationRequest = null;
    return position;
  }

  Future<void> _refresh() async {
    final controller = context.read<HerbalGardenController>();
    final position = await _tryGetPosition();
    await controller.loadAll(
      refresh: true,
      latitude: position?.latitude,
      longitude: position?.longitude,
    );
  }

  // ── Điều hướng ───────────────────────────────────────────────────────────

  Future<void> _openPlantDetail(String plantId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GardenPlantDetailScreen(plantId: plantId),
      ),
    );
    // ⚠️ Dùng `refreshAll()` (gồm cả `loadDeleted`) — nếu chỉ `loadAll()` thì
    // badge "Cây đã xoá" trên Hub vẫn hiện số cũ sau khi xoá cây.
    if (mounted) {
      await context.read<HerbalGardenController>().refreshAll();
    }
  }

  Future<void> _openAddPlant({String? tenLabel, String? tenCay}) async {
    final controller = context.read<HerbalGardenController>();
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => GardenAddPlantScreen(
          initialTenLabel: tenLabel,
          initialTenCay: tenCay,
        ),
      ),
    );
    if (added == true && mounted) await controller.loadAll();
  }

  Future<void> _openDeleted() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const GardenDeletedScreen()),
    );
    if (mounted) await context.read<HerbalGardenController>().loadAll();
  }

  // ── Hành động trên thẻ việc ─────────────────────────────────────────────
  //
  // ⚠️ Đã bỏ toàn bộ handler của thẻ việc khỏi màn này — "Việc hôm nay"
  // chuyển hẳn sang màn riêng [GardenCareScreen]. Màn "Vườn của tôi" chỉ
  // lo phần CÂY TRONG VƯỜN.

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
            controller: _scrollController,
            slivers: <Widget>[
              _buildHeader(controller),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // ── Thời tiết ────────────────────────────────────
                      GardenWeatherCard(
                        weather: controller.weather,
                        loading: controller.isLoadingWeather,
                        error: controller.weatherError,
                        onRetry: () => controller.loadWeather(),
                      ),
                      const SizedBox(height: 14),

                      // ── Số liệu tổng quan ─────────────────────────────
                      GardenStatStrip(
                        totalPlants: controller.totalPlants,
                        tasksToday: controller.care.total,
                        totalHarvestKg: controller.tongKhoiLuongThuHoachKg,
                      ),
                      const SizedBox(height: 22),

                      // ⚠️ KHÔNG hiện "Việc hôm nay" ở màn "Vườn của tôi".
                      //
                      // Việc hôm nay đã có 1 màn riêng (GardenCareScreen) và
                      // có 1 ô riêng trên trang Hub ("Việc hôm nay"). Hiện
                      // ở cả 2 nơi → trùng lặp, và người dùng tưởng đây là
                      // 2 danh sách khác nhau. Màn này chỉ lo phần CÂY TRONG
                      // VƯỜN; việc hôm nay → vào ô "Việc hôm nay" ở Hub.

                      // ── Cây trong vườn ────────────────────────────────
                      _buildPlantsSection(controller),
                      const SizedBox(height: 90),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddPlant(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Thêm cây',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(HerbalGardenController controller) {
    final deletedCount = controller.deletedPlants.length;

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.86),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(26),
            bottomRight: Radius.circular(26),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                // Nút quay lại — KHÔNG bắt người dùng phải dùng nút back
                // của hệ điều hành (không ai biết nó ở đâu).
                _RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
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
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Theo dõi cây trồng của bạn',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                _HeaderIconButton(
                  icon: Icons.restore_rounded,
                  badge: deletedCount > 0 ? deletedCount : null,
                  tooltip: 'Cây đã xoá',
                  onTap: _openDeleted,
                ),
                const SizedBox(width: 8),
                _HeaderIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Làm mới',
                  onTap: _refresh,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SearchField(
              controller: _searchController,
              onChanged: (v) => controller.setQuery(v),
              onClear: () {
                _searchController.clear();
                controller.setQuery('');
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Section: Việc hôm nay ──────────────────────────────────────────────
  //
  // ⚠️ ĐÃ BỎ: màn "Vườn của tôi" không hiện "Việc hôm nay" nữa.
  // Việc hôm nay nằm ở màn riêng [GardenCareScreen] (mở từ ô "Việc hôm
  // nay" trên trang Hub).

  // ── Section: Cây trong vườn ─────────────────────────────────────────────

  Widget _buildPlantsSection(HerbalGardenController controller) {
    final filtered = controller.filteredPlants;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(
              Icons.local_florist_rounded,
              size: 19,
              color: AppColors.primary,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'Cây trong vườn',
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (controller.hasFilter)
              TextButton.icon(
                onPressed: () {
                  controller.clearFilters();
                  _searchController.clear();
                },
                icon: const Icon(Icons.filter_alt_off_rounded, size: 15),
                label: const Text('Bỏ lọc'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _buildFilterBar(controller),
        const SizedBox(height: 12),
        if (controller.isLoadingList && controller.plants.isEmpty)
          const _LoadingBox(height: 160)
        else if (controller.hasFatalError)
          GardenErrorBanner(
            message: controller.listError ?? 'Không tải được danh sách cây.',
            onRetry: () => controller.loadPlants(),
          )
        else if (controller.plants.isEmpty)
          GardenEmptyState(
            icon: Icons.local_florist_outlined,
            title: 'Vườn của bạn còn trống',
            message:
                'Thêm loài cây đầu tiên để bắt đầu theo dõi mùa vụ, lịch tưới '
                'và sổ thu hoạch.',
            action: GardenPrimaryButton(
              label: 'Thêm cây đầu tiên',
              icon: Icons.add_rounded,
              onPressed: () => _openAddPlant(),
            ),
          )
        else if (filtered.isEmpty)
          const GardenEmptyState(
            icon: Icons.filter_alt_off_rounded,
            title: 'Không có cây phù hợp',
            message: 'Thử bỏ bớt bộ lọc để xem toàn bộ cây trong vườn.',
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            // ⚠️ Dùng `mainAxisExtent` (chiều cao cố định) thay vì
            // `childAspectRatio`: tỉ lệ theo bề rộng khiến thẻ bị tràn dọc
            // trên màn hình hẹp (RenderFlex overflow). Chiều cao cố định
            // đảm bảo mọi thẻ cây có cùng kích thước, giao diện đều nhau.
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 300,
            ),
            itemCount: filtered.length,
            itemBuilder: (_, i) => GardenPlantCard(
              plant: filtered[i],
              onTap: () => _openPlantDetail(filtered[i].id),
            ),
          ),
      ],
    );
  }

  /// Thanh lọc: giai đoạn + "cần chăm sóc hôm nay".
  Widget _buildFilterBar(HerbalGardenController controller) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          _FilterChip(
            label: 'Cần chăm sóc hôm nay',
            icon: Icons.priority_high_rounded,
            selected: controller.onlyNeedsCare,
            color: const Color(0xFFE2703A),
            onTap: () => controller.setOnlyNeedsCare(!controller.onlyNeedsCare),
          ),
          const SizedBox(width: 7),
          ...kGardenStages.map((stage) {
            final selected = controller.stageFilter == stage;
            return Padding(
              padding: const EdgeInsets.only(right: 7),
              child: _FilterChip(
                label: kGardenStageLabels[stage] ?? stage,
                icon: GardenStageStyle.icon(stage),
                selected: selected,
                color: GardenStageStyle.color(stage),
                onTap: () => controller.setStageFilter(selected ? null : stage),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Widget phụ ────────────────────────────────────────────────────────────

/// Nút tròn trên nền hero — dùng cho nút quay lại & làm mới.
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
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
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int? badge;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Material(
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
        if (badge != null)
          Positioned(
            right: -2,
            top: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFE2703A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13.5, color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Tìm cây trong vườn...',
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 13,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: Colors.white.withValues(alpha: 0.8),
          size: 20,
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, value, __) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  onPressed: onClear,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.15),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.14) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : Colors.black.withValues(alpha: 0.08),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 14, color: selected ? color : Colors.black54),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? color
                      : Colors.black.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  final double height;

  const _LoadingBox({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
    );
  }
}
