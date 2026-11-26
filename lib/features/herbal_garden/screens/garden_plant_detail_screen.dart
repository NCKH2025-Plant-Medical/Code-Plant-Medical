// lib/features/herbal_garden/screens/garden_plant_detail_screen.dart
//
// MÀN HÌNH 2 — CHI TIẾT CÂY TRONG VƯỜN
//
// API được gọi:
//   GET    /api/v1/herbal-garden/{plant_id}         → toàn bộ dữ liệu cây
//   POST   /api/v1/herbal-garden/{plant_id}/water   → ghi nhận đã tưới
//   POST   /api/v1/herbal-garden/{plant_id}/stage   → đổi mốc giai đoạn
//   POST   /api/v1/herbal-garden/{plant_id}/photo   → thêm ảnh nhật ký
//   POST   /api/v1/herbal-garden/{plant_id}/harvest → ghi sổ thu hoạch
//   DELETE /api/v1/herbal-garden/{plant_id}         → xoá cây (xoá mềm)
//
// Lưu ý: `provider` dùng chung [HerbalGardenController] với màn hình chính nên
// mọi thao tác ghi sẽ tự đồng bộ danh sách vườn + việc hôm nay.

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:thunghiem1/core/image_compress.dart';
import 'package:thunghiem1/features/herbal_garden/models/garden_models.dart';
import 'package:thunghiem1/features/herbal_garden/services/herbal_garden_api.dart';
import 'package:thunghiem1/features/herbal_garden/state/herbal_garden_state.dart';
import 'package:thunghiem1/features/herbal_garden/widgets/garden_harvest_dialog.dart';
import 'package:thunghiem1/features/herbal_garden/widgets/garden_harvest_outcome_sheet.dart';
import 'package:thunghiem1/features/herbal_garden/widgets/garden_note_dialog.dart';
import 'package:thunghiem1/features/herbal_garden/widgets/garden_style.dart';
import 'package:thunghiem1/theme/app_colors.dart';

class GardenPlantDetailScreen extends StatefulWidget {
  final String plantId;

  const GardenPlantDetailScreen({super.key, required this.plantId});

  @override
  State<GardenPlantDetailScreen> createState() =>
      _GardenPlantDetailScreenState();
}

class _GardenPlantDetailScreenState extends State<GardenPlantDetailScreen> {
  final ImagePicker _picker = ImagePicker();

  GardenPlantDetail? _detail;
  bool _loading = true;
  String? _error;

  /// Đang ghi dữ liệu (disable nút trong lúc chờ server).
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await context.read<HerbalGardenController>().loadDetail(
        widget.plantId,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on GardenApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được thông tin cây. Vui lòng thử lại.';
        _loading = false;
      });
    }
  }

  // ── Hành động ───────────────────────────────────────────────────────────

  void _showSnack(String message, {required bool ok}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
          // ⚠️ Lỗi thường → CAM. Đỏ = nghiêm trọng (cây chết, loài độc).
          backgroundColor: ok ? AppColors.primary : const Color(0xFFB0621A),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: ok ? 2 : 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    if (ok) _load();
  }

  Future<void> _runWrite(Future<String> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await action();
      if (!mounted) return;
      _showSnack(message, ok: true);
    } on GardenApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, ok: false);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Thao tác thất bại. Thử lại nhé.', ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Số giờ tối thiểu giữa 2 lần tưới — phải khớp với
  /// `WATER_COOLDOWN_HOURS` của backend (`API/herbal_garden/config.py`).
  ///
  /// Dùng để VÔ HIỆU hoá nút "Đã tưới" ngay trên client, trước khi gọi
  /// API (server vẫn chặn lần 2 như lưới an toàn).
  static const int _waterCooldownHours = 8;

  Future<void> _water() async {
    final detail = _detail;
    if (detail == null) return;

    // Chặn ngay trên client nếu vừa tưới xong (trong 8 giờ gần nhất).
    final last = detail.lastWateredAt;
    if (last != null) {
      final elapsed = DateTime.now().toUtc().difference(last.toUtc());
      final cooldown = Duration(hours: _waterCooldownHours);
      if (elapsed >= Duration.zero && elapsed < cooldown) {
        final remaining = cooldown - elapsed;
        final hoursLeft = remaining.inHours;
        final minutesLeft = remaining.inMinutes.remainder(60);
        final wait = hoursLeft > 0
            ? '$hoursLeft giờ $minutesLeft phút'
            : '$minutesLeft phút';
        _showSnack(
          'Bạn đã tưới cây này lúc '
          '${gardenFormatDateTime(last).split('·').last.trim()} hôm nay. '
          'Hãy đợi thêm $wait nữa rồi tưới tiếp nhé.',
          ok: false,
        );
        return;
      }
    }

    final id = widget.plantId;
    await _runWrite(
      () => context.read<HerbalGardenController>().waterPlant(id),
    );
  }

  Future<void> _changeStage() async {
    final detail = _detail;
    if (detail == null) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _StagePickerSheet(current: detail.stage),
    );
    if (selected == null || selected == detail.stage || !mounted) return;

    // ⚠️ Dùng StatefulWidget dialog (GardenNoteDialog) thay vì tạo
    // TextEditingController bên ngoài + dispose() sớm — bản cũ gây
    // "use_build_context_synchronously" → app treo khi bấm "Bỏ qua".
    final noteResult = await showDialog<GardenNoteResult>(
      context: context,
      builder: (ctx) => const GardenNoteDialog(
        title: 'Ghi chú mốc (tuỳ chọn)',
        hint: 'VD: Mọc chồi, ra hoa...',
      ),
    );
    // Người dùng bấm "Bỏ qua" → hủy thao tác, KHÔNG gọi API.
    if (noteResult == null || noteResult.cancelled || !mounted) return;

    await _runWrite(
      () => context.read<HerbalGardenController>().updateStage(
        widget.plantId,
        stage: selected,
        note: noteResult.note.isEmpty ? null : noteResult.note,
      ),
    );
  }

  Future<void> _addPhoto() async {
    if (_busy) return;

    // Lấy controller TRƯỚC mọi await để không dùng BuildContext qua async gap.
    final controller = context.read<HerbalGardenController>();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Chụp ảnh mới'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null || !mounted) return;

      // Nén ảnh trước khi gửi (server giới hạn dung lượng).
      final compressed = await compressImageForUpload(picked.path);
      if (!mounted) return;

      final noteResult = await showDialog<GardenNoteResult>(
        context: context,
        builder: (ctx) => const GardenNoteDialog(
          title: 'Ghi chú ảnh (tuỳ chọn)',
          hint: 'VD: Cây đã ra 5 lá',
        ),
      );
      if (noteResult == null || noteResult.cancelled || !mounted) return;

      // GPS tại thời điểm chụp → server dùng để tính thời tiết đúng chỗ trồng.
      final position = await _tryGetPosition();

      setState(() => _busy = true);
      try {
        await controller.addPhoto(
          widget.plantId,
          filePath: compressed,
          note: noteResult.note.isEmpty ? null : noteResult.note,
          latitude: position?.latitude,
          longitude: position?.longitude,
        );
        if (!mounted) return;
        _showSnack('Đã thêm ảnh vào nhật ký tiến độ.', ok: true);
      } on GardenApiException catch (e) {
        if (!mounted) return;
        _showSnack(e.message, ok: false);
      } catch (_) {
        if (!mounted) return;
        _showSnack('Không lưu được ảnh. Vui lòng thử lại.', ok: false);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Không chọn được ảnh: $e', ok: false);
    }
  }

  Future<void> _harvest() async {
    final input = await showDialog<({double? weightKg, String? note})>(
      context: context,
      builder: (_) => const GardenHarvestDialog(),
    );
    if (input == null || !mounted) return;

    setState(() => _busy = true);
    bool harvested = false;
    try {
      final result = await context.read<HerbalGardenController>().harvest(
        widget.plantId,
        weightKg: input.weightKg,
        note: input.note,
      );
      harvested = true;
      if (!mounted) return;
      _showSnack(result.message, ok: result.warning == null);
      if (result.warning != null && result.warning!.isNotEmpty) {
        _showSnack(result.warning!, ok: false);
      }
    } on GardenApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, ok: false);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Không ghi được sổ thu hoạch.', ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    // Chỉ hỏi hậu-thu-hoạch khi ghi sổ THÀNH CÔNG.
    if (!harvested || !mounted) return;
    await _askKeepAfterHarvest();
  }

  /// Sau khi thu hoạch: hỏi người dùng giữ cây (chuẩn bị mùa vụ mới) hay
  /// bỏ cây (xoá mềm → vào mục "Cây đã xoá" / lịch sử).
  Future<void> _askKeepAfterHarvest() async {
    final detail = _detail;
    if (detail == null) return;

    final choice = await showModalBottomSheet<HarvestOutcomeChoice>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) =>
          GardenHarvestOutcomeSheet(plantName: detail.displayName),
    );
    if (choice == null || !mounted) return;

    if (choice == HarvestOutcomeChoice.keep) {
      await _reseedAfterHarvest();
      return;
    }

    // Không giữ → xoá mềm cây (vẫn xem lại được ở "Cây đã xoá").
    setState(() => _busy = true);
    try {
      final message = await context.read<HerbalGardenController>().deletePlant(
        widget.plantId,
      );
      if (!mounted) return;
      _showSnack(message, ok: true);
      if (mounted) Navigator.pop(context);
    } on GardenApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, ok: false);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Không bỏ được cây. Vui lòng thử lại.', ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Giữ cây → cho chọn lại mốc để bắt đầu vụ mới.
  Future<void> _reseedAfterHarvest() async {
    final detail = _detail;
    if (detail == null) return;

    final stage = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => GardenReseedStageSheet(currentStage: detail.stage),
    );
    if (stage == null || !mounted) return;

    await _runWrite(
      () => context.read<HerbalGardenController>().updateStage(
        widget.plantId,
        stage: stage,
        note: 'Bắt đầu vụ mới sau khi thu hoạch',
      ),
    );
  }

  Future<void> _delete() async {
    final detail = _detail;
    if (detail == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Xoá cây khỏi vườn?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Xoá "${detail.displayName}" khỏi vườn? Cây sẽ không hiển thị nữa '
          'nhưng vẫn có thể khôi phục trong mục "Cây đã xoá".',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD64545),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final message = await context.read<HerbalGardenController>().deletePlant(
        widget.plantId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } on GardenApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, ok: false);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Không xoá được cây.', ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Position?> _tryGetPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.6))
          : _error != null
          ? _buildErrorState()
          : _buildContent(),
      // ⚠️ Thanh thao tác CỐ ĐỊnh ở đáy màn hình.
      // Trước đây 3 nút "Đã tưới / Đổi mốc / Thu hoạch" nằm cuối nội
      // dung, sau ~10 card → người dùng phải lướt hết cả trang mới tới
      // được. Giờ ghim xuống đáy → luôn bấm được, không cần cuộn.
      bottomNavigationBar: _detail == null ? null : _buildActionBar(_detail!),
    );
  }

  /// Thanh thao tác ghim đáy: Đã tưới · Đổi mốc · Thu hoạch.
  Widget _buildActionBar(GardenPlantDetail d) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: _buildActions(d),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const Spacer(),
            GardenErrorBanner(message: _error!, onRetry: _load),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final d = _detail!;
    final botanical = d.botanical;

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(child: _buildHero(d)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ...d.canhBao.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _WarningBannerAuto(message: c),
                  ),
                ),
                if (botanical?.toxicLookalike == true) ...<Widget>[
                  const GardenDangerBanner(
                    message:
                        'Loài này có loài trông giống gây ĐỘC. Hãy thận trọng '
                        'khi nhận diện và sử dụng.',
                  ),
                  const SizedBox(height: 8),
                ],
                if (d.soil?.hasWarning == true) ...<Widget>[
                  GardenWarningBanner(message: d.soil!.soilWarning!),
                  const SizedBox(height: 8),
                ],
                if (d.growth != null) ...<Widget>[
                  _buildGrowthCard(d.growth!),
                  const SizedBox(height: 14),
                ],
                if (botanical != null) ...<Widget>[
                  _buildBotanicalCard(botanical),
                  const SizedBox(height: 14),
                ],
                _buildSeasonCard(d),
                const SizedBox(height: 14),
                _buildStatsCard(d),
                const SizedBox(height: 14),
                _buildTimelineCard(d),
                const SizedBox(height: 14),
                _buildHarvestCard(d),
                const SizedBox(height: 14),
                _buildStageHistoryCard(d),
                const SizedBox(height: 14),
                if (d.locations.isNotEmpty) ...<Widget>[
                  _buildLocationCard(d),
                  const SizedBox(height: 14),
                ],
                if ((d.notes ?? '').trim().isNotEmpty) ...<Widget>[
                  _buildNotesCard(d.notes!),
                  const SizedBox(height: 14),
                ],
                // ⚠️ 3 nút thao tác đã chuyển xuống thanh ghim đáy màn hình
                // (`bottomNavigationBar`) → không cần lướt sâu để bấm.
                GardenOutlineButton(
                  label: 'Xoá cây khỏi vườn',
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFD64545),
                  onPressed: _busy ? null : _delete,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero(GardenPlantDetail d) {
    // ⚠️ Hàm này được bọc trong `SliverToBoxAdapter` ở `_buildContent()` →
    // KHÔNG được trả về `SliverToBoxAdapter` lần nữa (sẽ lỗi "expected a
    // child of type RenderBox but received RenderSliverToBoxAdapter").
    return Stack(
      children: <Widget>[
        GardenNetworkImage(
          url: d.imageUrl,
          width: double.infinity,
          height: 260,
          fit: BoxFit.cover,
          fallbackIcon: GardenStageStyle.icon(d.stage),
          fallbackColor: Colors.white,
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Colors.black.withValues(alpha: 0.45),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.55),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const <double>[0, 0.45, 1],
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          top: MediaQuery.of(context).padding.top + 6,
          child: _RoundIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
        ),
        Positioned(
          right: 12,
          top: MediaQuery.of(context).padding.top + 6,
          child: _RoundIconButton(icon: Icons.refresh_rounded, onTap: _load),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  GardenChip(
                    label: d.stageLabel,
                    icon: GardenStageStyle.icon(d.stage),
                    color: Colors.white,
                    filled: true,
                  ),
                  if (d.daysSincePlanted != null)
                    GardenChip(
                      label: 'Đã trồng ${d.daysSincePlanted} ngày',
                      icon: Icons.schedule_rounded,
                      color: Colors.white,
                    ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                d.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              if ((d.tenQuocte ?? '').isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  d.tenQuocte!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Card: Sinh trưởng ───────────────────────────────────────────────────

  Widget _buildGrowthCard(GrowthInfo growth) {
    final isWarn = growth.isWarning;
    final color = isWarn ? const Color(0xFFE2703A) : AppColors.success;

    return GardenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                isWarn ? Icons.trending_up_rounded : Icons.check_circle_rounded,
                size: 19,
                color: color,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Đánh giá sinh trưởng',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              GardenChip(
                label: isWarn ? 'Cần theo dõi' : 'Bình thường',
                color: color,
                filled: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            growth.nhanDien,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Colors.black.withValues(alpha: 0.7),
            ),
          ),
          if ((growth.goiYa ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            GardenInfoBanner(
              message: growth.goiYa!,
              icon: Icons.lightbulb_outline_rounded,
            ),
          ],
        ],
      ),
    );
  }

  // ── Card: Dược liệu ─────────────────────────────────────────────────────

  Widget _buildBotanicalCard(BotanicalInfo b) {
    return GardenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Thông tin dược liệu',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if ((b.thongTin ?? '').isNotEmpty)
            _InfoBlock(title: 'Mô tả', body: b.thongTin!),
          if ((b.congDung ?? '').isNotEmpty)
            _InfoBlock(title: 'Công dụng', body: b.congDung!),
          if ((b.cachDung ?? '').isNotEmpty)
            _InfoBlock(title: 'Cách dùng', body: b.cachDung!),
          if ((b.luuYo ?? '').isNotEmpty)
            _InfoBlock(title: 'Lưu ý', body: b.luuYo!, warning: true),
        ],
      ),
    );
  }

  // ── Card: Mùa vụ ────────────────────────────────────────────────────────

  Widget _buildSeasonCard(GardenPlantDetail d) {
    final season = d.season;

    return GardenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.calendar_month_rounded,
                size: 19,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Mùa vụ & chu kỳ',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              GardenSeasonChip(season: season),
            ],
          ),
          const SizedBox(height: 12),
          // ⚠️ Giải thích rõ "Đúng mùa / Ngoài mùa" nghĩa là gì — người
          // dùng mới thường không hiểu chip màu này báo gì.
          if (season != null && season.coMuaVu && season.inSeason)
            const GardenInfoBanner(
              message:
                  'Đang đúng mùa thu hoạch — thu hoạch lúc này cho hoạt chất '
                  'tốt nhất.',
              icon: Icons.eco_rounded,
            )
          else if (season != null && season.coMuaVu)
            const GardenWarningBanner(
              message:
                  'Ngoài mùa thu hoạch — thu hoạch lúc này hoạt chất chỉ đạt '
                  'khoảng 60%. Nên chờ đúng mùa.',
              icon: Icons.event_rounded,
            ),
          if (season != null && season.coMuaVu) const SizedBox(height: 10),
          if ((d.nhomCayLabel ?? '').isNotEmpty)
            _KeyValue(label: 'Nhóm cây', value: d.nhomCayLabel!),
          if (d.soNgayThuHoach != null)
            _KeyValue(
              label: 'Chu kỳ thu hoạch',
              value: '${d.soNgayThuHoach} ngày',
            ),
          if (d.kyCatTia != null)
            _KeyValue(label: 'Kỳ cắt tỉa', value: 'Tháng ${d.kyCatTia}'),
          if ((season?.kyThuHoachToi ?? '').isNotEmpty)
            _KeyValue(
              label: 'Kỳ thu hoạch kế tiếp',
              value: season!.kyThuHoachToi!,
            ),
          if ((d.ghiChuMuaVu ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            GardenInfoBanner(
              message: d.ghiChuMuaVu!,
              icon: Icons.info_outline_rounded,
            ),
          ],
        ],
      ),
    );
  }

  // ── Card: Thống kê ─────────────────────────────────────────────────────

  Widget _buildStatsCard(GardenPlantDetail d) {
    return GardenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Thống kê vườn',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _MiniStatBox(
                  label: 'Ảnh nhật ký',
                  value: '${d.soAnhTimeline}',
                  icon: Icons.photo_camera_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStatBox(
                  label: 'Lần thu hoạch',
                  value: '${d.soLanThuHoach}',
                  icon: Icons.menu_book_rounded,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStatBox(
                  label: 'Sản lượng',
                  value: '${d.tongKhoiLuongThuHoachKg.toStringAsFixed(2)} kg',
                  icon: Icons.scale_rounded,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          if (d.lastWateredAt != null) ...<Widget>[
            const SizedBox(height: 12),
            _KeyValue(
              label: 'Lần tưới gần nhất',
              value: gardenFormatDateTime(d.lastWateredAt),
            ),
          ],
          if (d.soLanTuoi > 0) ...<Widget>[
            const SizedBox(height: 6),
            _KeyValue(label: 'Tổng số lần tưới', value: '${d.soLanTuoi}'),
          ],
          if (d.soil?.soilLabel != null) ...<Widget>[
            const SizedBox(height: 6),
            _KeyValue(
              label: 'Loại đất',
              value:
                  d.soil!.soilLabel! +
                  (d.soil!.plantingMediumLabel != null
                      ? ' · ${d.soil!.plantingMediumLabel}'
                      : ''),
            ),
          ],
          if (d.ngayChupAnhToiNhat != null) ...<Widget>[
            const SizedBox(height: 6),
            _KeyValue(
              label: 'Ảnh gần nhất',
              value:
                  '${gardenFormatDate(d.ngayChupAnhToiNhat)} '
                  '(${d.soNgayTuLanChupAnhCuoi} ngày trước)',
            ),
          ],
        ],
      ),
    );
  }

  // ── Card: Timeline ảnh ─────────────────────────────────────────────────

  Widget _buildTimelineCard(GardenPlantDetail d) {
    return GardenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.photo_library_rounded,
                size: 19,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Nhật ký tiến độ',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${d.timelineImages.length} ảnh',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (d.timelineImages.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Chưa có ảnh nào. Hãy chụp ảnh để theo dõi cây phát triển.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            )
          else
            SizedBox(
              height: 152,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: d.timelineImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 9),
                itemBuilder: (_, i) {
                  final img = d.timelineImages[i];
                  return GestureDetector(
                    onTap: () => _showImageViewer(context, img),
                    child: Container(
                      width: 116,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.07),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(13),
                            ),
                            child: GardenNetworkImage(
                              url: img.url,
                              width: 116,
                              height: 96,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(7, 5, 7, 0),
                            child: Text(
                              gardenFormatDate(img.capturedAt),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.black.withValues(alpha: 0.65),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(7, 1, 7, 6),
                            child: Text(
                              img.note ?? img.stageLabel ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.black.withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          GardenOutlineButton(
            label: 'Thêm ảnh vào nhật ký',
            icon: Icons.add_a_photo_rounded,
            onPressed: _busy ? null : _addPhoto,
          ),
        ],
      ),
    );
  }

  // ── Card: Sổ thu hoạch ─────────────────────────────────────────────────

  Widget _buildHarvestCard(GardenPlantDetail d) {
    return GardenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.menu_book_rounded,
                size: 19,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Sổ thu hoạch',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${d.harvestHistory.length} lần',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (d.harvestHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Chưa ghi nhận lần thu hoạch nào.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            )
          else
            ...d.harvestHistory.map((h) {
              final ratio = h.activeRatio;
              final color = ratio == null
                  ? const Color(0xFF8A9BA8)
                  : (ratio >= 1.0
                        ? AppColors.success
                        : const Color(0xFFE2703A));
              return Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.22)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            gardenFormatDate(h.harvestedAt),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (h.weightKg != null)
                          Text(
                            '${h.weightKg!.toStringAsFixed(2)} kg',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    GardenChip(
                      label: h.qualityLabel,
                      color: color,
                      filled: true,
                    ),
                    if ((h.note ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        h.note!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    if ((h.warning ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      GardenWarningBanner(message: h.warning!),
                    ],
                  ],
                ),
              );
            }),
          const SizedBox(height: 4),
          GardenOutlineButton(
            label: 'Ghi vào sổ thu hoạch',
            icon: Icons.add_rounded,
            onPressed: _busy ? null : _harvest,
          ),
        ],
      ),
    );
  }

  // ── Card: Lịch sử mốc ──────────────────────────────────────────────────

  Widget _buildStageHistoryCard(GardenPlantDetail d) {
    return GardenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.timeline_rounded, size: 19, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Lịch sử sinh trưởng',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (d.stageHistory.isEmpty)
            Text(
              'Chưa có mốc nào được ghi nhận.',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.black.withValues(alpha: 0.5),
              ),
            )
          else
            ...d.stageHistory.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              final isLast = i == d.stageHistory.length - 1;
              final color = GardenStageStyle.color(s.stage);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Icon(
                          GardenStageStyle.icon(s.stage),
                          size: 13,
                          color: color,
                        ),
                      ),
                      // Đường nối giữa 2 mốc — chiều cao cố định để không
                      // phụ thuộc IntrinsicHeight (tránh lỗi layout runtime).
                      if (!isLast)
                        Container(
                          width: 1.5,
                          height: 34,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          color: color.withValues(alpha: 0.25),
                        ),
                    ],
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            s.label,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            gardenFormatDateTime(s.at),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.black.withValues(alpha: 0.45),
                            ),
                          ),
                          if ((s.note ?? '').isNotEmpty) ...<Widget>[
                            const SizedBox(height: 3),
                            Text(
                              s.note!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  // ── Card: Vị trí ───────────────────────────────────────────────────────

  Widget _buildLocationCard(GardenPlantDetail d) {
    return GardenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.location_on_rounded,
                size: 19,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                'Vị trí',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...d.locations.map((loc) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.place_rounded,
                    size: 15,
                    color: Colors.black38,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      loc.addressName ??
                          '${loc.latitude?.toStringAsFixed(5)}, '
                              '${loc.longitude?.toStringAsFixed(5)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: Colors.black.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Card: Ghi chú ──────────────────────────────────────────────────────

  Widget _buildNotesCard(String notes) {
    return GardenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.sticky_note_2_rounded,
                size: 19,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                'Ghi chú',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            notes,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.black.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ── Thao tác ───────────────────────────────────────────────────────────

  /// 3 nút thao tác — dạng **pill compact**, tự co theo nội dung.
  ///
  /// ⚠️ Trước đây dùng `Expanded` cho cả 3 → mỗi nút trải hết 1/3 màn hình,
  /// nhìn như 3 nút "dài cả màn hình" rất kỳ. Giờ là pill icon + chữ, canh
  /// giữa, chiều rộng theo nội dung.
  Widget _buildActions(GardenPlantDetail d) {
    // Nút "Đã tưới" bị khoá nếu vừa tưới xong (< 8 giờ) → người dùng thấy
    // ngay nút đang "mờ" kèm giờ còn lại, không bấm vô rồi mới nhận lỗi.
    final cooldown = _waterCooldownRemaining(d);
    final canWater = cooldown == null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _ActionTile(
          icon: Icons.water_drop_rounded,
          label: canWater ? 'Đã tưới' : 'Tưới lại sau $cooldown',
          color: const Color(0xFF3B82C4),
          enabled: !_busy && canWater,
          onTap: _water,
        ),
        const SizedBox(width: 8),
        _ActionTile(
          icon: Icons.timeline_rounded,
          label: 'Đổi mốc',
          color: AppColors.primary,
          enabled: !_busy,
          onTap: _changeStage,
        ),
        const SizedBox(width: 8),
        _ActionTile(
          icon: Icons.grass_rounded,
          label: 'Thu hoạch',
          color: AppColors.accent,
          enabled: !_busy,
          onTap: _harvest,
        ),
      ],
    );
  }

  /// Số giờ còn lại trước khi được tưới lại — `null` nghĩa là ĐƯỢC tưới.
  String? _waterCooldownRemaining(GardenPlantDetail d) {
    final last = d.lastWateredAt;
    if (last == null) return null;
    final elapsed = DateTime.now().toUtc().difference(last.toUtc());
    final cooldown = Duration(hours: _waterCooldownHours);
    if (elapsed.isNegative || elapsed >= cooldown) return null;
    final remaining = cooldown - elapsed;
    if (remaining.inHours > 0) {
      return '${remaining.inHours}h${remaining.inMinutes.remainder(60)}';
    }
    return '${remaining.inMinutes} phút';
  }

  void _showImageViewer(BuildContext context, TimelineImage img) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            GardenNetworkImage(url: img.url, width: 320, height: 320),
            const SizedBox(height: 10),
            Text(
              gardenFormatDateTime(img.capturedAt),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            if ((img.note ?? '').isNotEmpty)
              Text(
                img.note!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Widget phụ ────────────────────────────────────────────────────────────

class _WarningBannerAuto extends StatelessWidget {
  final String message;

  const _WarningBannerAuto({required this.message});

  @override
  Widget build(BuildContext context) {
    final lower = message.toLowerCase();
    // ⚠️ ĐỎ chỉ dành cho "cây đã chết" hoặc "loài độc" — nguy hiểm thật sự.
    // Mọi cảnh báo khác (ngoài mùa, chậm, cảnh báo y tế thường) → cam.
    if (lower.contains('có thể đã chết') || lower.contains('đã chết')) {
      return GardenDangerBanner(message: message);
    }
    if (lower.contains('độc')) {
      return GardenDangerBanner(message: message);
    }
    return GardenWarningBanner(message: message);
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
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

class _InfoBlock extends StatelessWidget {
  final String title;
  final String body;
  final bool warning;

  const _InfoBlock({
    required this.title,
    required this.body,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = warning ? const Color(0xFFB0621A) : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: Colors.black.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  final String label;
  final String value;

  const _KeyValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 17, color: color),
          const SizedBox(height: 5),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet chọn giai đoạn sinh trưởng.
class _StagePickerSheet extends StatelessWidget {
  final String current;

  const _StagePickerSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Đổi mốc sinh trưởng',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          ...kGardenStages.map(
            (stage) => ListTile(
              leading: Icon(
                GardenStageStyle.icon(stage),
                color: GardenStageStyle.color(stage),
              ),
              title: Text(
                kGardenStageLabels[stage] ?? stage,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: stage == current
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: GardenStageStyle.color(stage),
                    )
                  : null,
              onTap: () => Navigator.pop(context, stage),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
