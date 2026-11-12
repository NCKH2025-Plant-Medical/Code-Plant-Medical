// lib/screens/garden/garden_plant_detail_screen.dart
//
// MÀN HÌNH 4 — CHI TIẾT CÂY
//
// Cấu trúc (Mục 5 của hướng dẫn sử dụng):
//   [Hero ảnh] Tên cây + tên khoa học
//   [Chip: giai đoạn] [Chip: N ngày] [Chip: mùa vụ]
//   ⚠️ BANNER CẢNH BÁO (canh_bao[])
//   📋 Công dụng / Cách dùng / Lưu ý / Mô tả   (tabs)
//   📍 Vị trí
//   📸 NHẬT KÝ TIẾN ĐỘ  (timeline ngang)
//   📖 SỔ THU HOẠCH
//   ⏱️ MỐC THỜI GIAN  (stage_history)
//   [📷 Chụp ảnh] [🌾 Thu hoạch] [🗑 Xóa cây]

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:thunghiem1/controllers/garden_notifier.dart';
import 'package:thunghiem1/core/image_compress.dart';
import 'package:thunghiem1/models/herbal_garden.dart';
import 'package:thunghiem1/screens/garden/garden_constants.dart';
import 'package:thunghiem1/screens/garden/garden_widgets.dart';
import 'package:thunghiem1/services/herbal_garden_api.dart';
import 'package:thunghiem1/theme/app_colors.dart';

class GardenPlantDetailScreen extends StatefulWidget {
  const GardenPlantDetailScreen({super.key, required this.plantId});

  final String plantId;

  @override
  State<GardenPlantDetailScreen> createState() =>
      _GardenPlantDetailScreenState();
}

class _GardenPlantDetailScreenState extends State<GardenPlantDetailScreen> {
  final HerbalGardenApi _api = HerbalGardenApi();
  final ImagePicker _picker = ImagePicker();

  GardenPlantDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = context.read<GardenNotifier>().uid;
      final detail = await _api.plantDetail(widget.plantId, uid: uid);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFDC2626) : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Chụp ảnh ────────────────────────────────────────────────────────────

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 82);
      if (picked == null) return;

      final note = await _askNote();
      if (note == null) return; // huỷ

      setState(() => _busy = true);
      final compressed = await compressImageForUpload(picked.path);

      // Lấy GPS tại thời điểm chụp (nếu được) — backend dùng để tính thời
      // tiết & gợi ý tưới đúng chỗ người dùng đang trồng cây.
      final pos = await _getCurrentPosition();
      if (!mounted) return;

      final uid = context.read<GardenNotifier>().uid;
      final timeline = await _api.addPhoto(
        widget.plantId,
        File(compressed),
        note: note,
        latitude: pos?.latitude,
        longitude: pos?.longitude,
        addressName: pos == null
            ? null
            : (_detail?.locations.isNotEmpty ?? false)
                ? _detail!.locations.first.addressName
                : null,
        uid: uid,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage('Đã thêm ảnh vào nhật ký tiến độ.');
      await _load();
      if (timeline.isNotEmpty && mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<String?> _askNote() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Ghi chú (không bắt buộc)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 2,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'VD: cây đã ra 5 lá',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Lưu ảnh'),
          ),
        ],
      ),
    );
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
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
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Đổi mốc giai đoạn ──────────────────────────────────────────────────

  Future<void> _updateStage() async {
    final current = _detail?.stage ?? 'gieo_trong';
    String picked = current;
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'Cập nhật giai đoạn',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đổi mốc cũng được tính là "đã chăm sóc cây" → gỡ cảnh báo '
                  '"Cần tưới" và "Bị bỏ rơi".',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                ...kGardenStages.map((s) {
                  return RadioListTile<String>(
                    value: s,
                    groupValue: picked,
                    onChanged: (v) => setDlgState(() => picked = v!),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primary,
                    title: Row(
                      children: [
                        Icon(stageIcon(s), size: 17, color: stageColor(s)),
                        const SizedBox(width: 8),
                        Text(
                          kStageLabels[s] ?? s,
                          style: const TextStyle(fontSize: 13.5),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ghi chú (không bắt buộc)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final garden = context.read<GardenNotifier>();
      final msg = await garden.updateStage(
        widget.plantId,
        picked,
        note: noteCtrl.text,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(msg);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  // ── Thu hoạch ──────────────────────────────────────────────────────────

  Future<void> _harvest() async {
    final weightCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var harvestedAt = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'Ghi nhận thu hoạch',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: harvestedAt,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                      locale: const Locale('vi', 'VN'),
                    );
                    if (d != null) setDlgState(() => harvestedAt = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFDDE5E1)),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_rounded,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 9),
                        Text(
                          'Ngày thu: ${formatVnDate(harvestedAt)}',
                          style: const TextStyle(fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: weightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Khối lượng (kg) — có thể bỏ trống',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú (không bắt buộc)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final weight = double.tryParse(weightCtrl.text.trim().replaceAll(',', '.'));
      final garden = context.read<GardenNotifier>();
      final record = await garden.harvest(
        widget.plantId,
        harvestedAt: harvestedAt,
        weightKg: weight,
        note: noteCtrl.text,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(record.warning ?? 'Đã ghi vào sổ thu hoạch.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  // ── Xoá cây ────────────────────────────────────────────────────────────

  Future<void> _delete() async {
    final name = _detail?.tenCay ?? 'cây này';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Xoá cây',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          'Xoá $name khỏi vườn? Ảnh nhật ký và sổ thu hoạch cũng sẽ bị ẩn. '
          'Bạn có thể khôi phục sau trong mục "Cây đã xoá".',
          style: const TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Xoá cây'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final garden = context.read<GardenNotifier>();
      final msg = await garden.deletePlant(widget.plantId);
      if (!mounted) return;
      _showMessage(msg);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(_detail!),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 44, color: Color(0xFF9AA5A1)),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6C757D)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(GardenPlantDetail d) {
    final botanical = d.botanical;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (d.imageUrl != null && d.imageUrl!.isNotEmpty)
                  Image.network(
                    d.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.primary,
                      child: const Icon(Icons.eco_rounded,
                          size: 70, color: Colors.white54),
                    ),
                  )
                else
                  Container(
                    color: AppColors.primary,
                    child: const Icon(Icons.eco_rounded,
                        size: 70, color: Colors.white54),
                  ),
                // Gradient để chữ dễ đọc
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tên + tên khoa học
                Text(
                  d.tenCay ?? d.tenLabel,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                if (d.tenQuocte != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    d.tenQuocte!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF6C757D),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Chip trạng thái
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StageChip(stage: d.stage, label: d.stageLabel),
                    GardenChip(
                      label: '${d.daysSincePlanted ?? 0} ngày đã trồng',
                      color: const Color(0xFF6C757D),
                      icon: Icons.calendar_today_rounded,
                    ),
                    SeasonChip(season: d.season),
                    if (d.soil?.soilLabel != null)
                      GardenChip(
                        label: d.soil!.soilLabel!,
                        color: const Color(0xFF8D6E63),
                        icon: Icons.grass_rounded,
                      ),
                  ],
                ),

                // ── Cảnh báo ──
                if (d.canhBao.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text(
                    '⚠️ CẢNH BÁO',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...d.canhBao.map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GardenBanner(
                        text: w,
                        kind: classifyBanner(
                          w,
                          isToxic: botanical?.toxicLookalike ?? false,
                        ),
                      ),
                    ),
                  ),
                ],

                // ── Cảnh báo loài dễ nhầm gây độc ──
                if (botanical?.toxicLookalike == true) ...[
                  const SizedBox(height: 4),
                  const GardenBanner(
                    text: 'Loài này có cây dễ nhầm gây ĐỘC trong tự nhiên. '
                        'Tuyệt đối không tự ý sử dụng nếu chưa có chuyên gia '
                        'xác nhận.',
                    kind: GardenBannerKind.danger,
                  ),
                ],

                // ── Đánh giá sinh trưởng ──
                if (d.growth != null) ...[
                  const SizedBox(height: 18),
                  _buildGrowthCard(d.growth!),
                ],

                // ── Công dụng & cách dùng ──
                if (botanical != null &&
                    (botanical.congDung != null ||
                        botanical.cachDung != null ||
                        botanical.luuYo != null ||
                        botanical.thongTin != null)) ...[
                  const SizedBox(height: 18),
                  _buildBotanicalCard(botanical),
                ],

                // ── Vị trí ──
                const SizedBox(height: 18),
                _buildLocationCard(d),

                // ── Nhật ký tiến độ ──
                const SizedBox(height: 18),
                _buildTimelineCard(d),

                // ── Sổ thu hoạch ──
                const SizedBox(height: 18),
                _buildHarvestCard(d),

                // ── Mốc thời gian ──
                const SizedBox(height: 18),
                _buildStageHistoryCard(d),

                // ── Thông tin nhóm cây ──
                if (d.nhomCayLabel != null) ...[
                  const SizedBox(height: 18),
                  _buildGroupCard(d),
                ],

                // ── Ghi chú ──
                if ((d.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _buildNotesCard(d),
                ],

                // ── Nút hành động ──
                const SizedBox(height: 24),
                _buildActionButtons(d),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Card sinh trưởng ───────────────────────────────────────────────────

  Widget _buildGrowthCard(GrowthInfo g) {
    final color = g.isWarning ? const Color(0xFFB45309) : const Color(0xFF2D6A4F);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bannerBg(g.isWarning
            ? GardenBannerKind.warning
            : GardenBannerKind.info),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                g.isWarning
                    ? Icons.trending_flat_rounded
                    : Icons.check_circle_outline_rounded,
                color: color,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  g.isWarning ? 'Đánh giá sinh trưởng — CẢNH BÁO' : 'Đánh giá sinh trưởng',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            g.nhanDien,
            style: const TextStyle(fontSize: 12.5, height: 1.45),
          ),
          if ((g.goiYa ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                g.goiYa!,
                style: const TextStyle(fontSize: 12.5, height: 1.45),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Card công dụng (tabs) ──────────────────────────────────────────────

  Widget _buildBotanicalCard(BotanicalInfo b) {
    return DefaultTabController(
      length: 4,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Row(
                children: [
                  Text('📖', style: TextStyle(fontSize: 15)),
                  SizedBox(width: 7),
                  Text(
                    'CÔNG DỤNG & CÁCH DÙNG',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: const Color(0xFF6C757D),
              indicatorColor: AppColors.primary,
              labelStyle:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Công dụng'),
                Tab(text: 'Cách dùng'),
                Tab(text: 'Lưu ý'),
                Tab(text: 'Mô tả'),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                height: 150,
                child: TabBarView(
                  children: [
                    _tabText(b.congDung, 'Chưa có thông tin công dụng.'),
                    _tabText(b.cachDung, 'Chưa có thông tin cách dùng.'),
                    _tabText(b.luuYo, 'Chưa có lưu ý nào được ghi nhận.'),
                    _tabText(b.thongTin, 'Chưa có mô tả.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabText(String? text, String fallback) {
    return SingleChildScrollView(
      child: Text(
        (text == null || text.trim().isEmpty) ? fallback : text,
        style: const TextStyle(fontSize: 12.5, height: 1.55),
      ),
    );
  }

  // ── Card vị trí ────────────────────────────────────────────────────────

  Widget _buildLocationCard(GardenPlantDetail d) {
    final saved = d.locations.where((l) => l.hasCoordinate).toList();
    final natural = d.locations.where((l) => !l.hasCoordinate).toList();

    if (d.locations.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAF8),
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Row(
          children: [
            Icon(Icons.location_off_rounded, size: 19, color: Color(0xFF6C757D)),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Chưa lưu vị trí trồng cây. Thời tiết sẽ dùng vùng mặc định.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF6C757D)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'VỊ TRÍ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Vị trí người dùng đã lưu (ưu tiên hiển thị đầu tiên)
          ...saved.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${l.addressName ?? 'Vị trí của bạn'} — '
                      '${l.latitude!.toStringAsFixed(4)}, '
                      '${l.longitude!.toStringAsFixed(4)}',
                      style: const TextStyle(fontSize: 12.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Các vùng trồng phổ biến (dữ liệu tra cứu, KHÔNG dùng tính thời tiết)
          ...natural.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.eco_outlined,
                      size: 15, color: Color(0xFF6C757D)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Vùng trồng phổ biến: ${l.addressName ?? '—'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6C757D),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Toạ độ dùng tính thời tiết là nơi BẠN đang trồng cây, '
            'không phải nơi sinh tự nhiên của loài.',
            style: TextStyle(fontSize: 11, color: Color(0xFF6C757D), height: 1.4),
          ),
        ],
      ),
    );
  }

  // ── Card timeline ảnh ──────────────────────────────────────────────────

  Widget _buildTimelineCard(GardenPlantDetail d) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('📸', style: TextStyle(fontSize: 15)),
                  SizedBox(width: 7),
                  Text(
                    'NHẬT KÝ TIẾN ĐỘ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              Text(
                '${d.timelineImages.length} ảnh',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF6C757D)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (d.timelineImages.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  'Chưa có ảnh nào. Chụp ảnh để dựng dòng thời gian sinh trưởng.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF6C757D)),
                ),
              ),
            )
          else
            SizedBox(
              height: 152,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: d.timelineImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final img = d.timelineImages[index];
                  return SizedBox(
                    width: 118,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 118,
                            height: 100,
                            child: img.url != null
                                ? Image.network(
                                    img.url!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: const Color(0xFFE8F4EF),
                                      child: const Icon(Icons.broken_image_rounded,
                                          color: Color(0xFF9AA5A1)),
                                    ),
                                  )
                                : Container(
                                    color: const Color(0xFFE8F4EF),
                                    child: const Icon(Icons.image_rounded,
                                        color: Color(0xFF9AA5A1)),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          formatVnDate(img.capturedAt),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if ((img.note ?? '').isNotEmpty)
                          Text(
                            img.note!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF6C757D),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ── Card sổ thu hoạch ──────────────────────────────────────────────────

  Widget _buildHarvestCard(GardenPlantDetail d) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('📖', style: TextStyle(fontSize: 15)),
                  SizedBox(width: 7),
                  Text(
                    'SỔ THU HOẠCH',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _harvest,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Ghi nhận', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (d.harvestHistory.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Chưa có lần thu hoạch nào.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF6C757D)),
                ),
              ),
            )
          else
            ...d.harvestHistory.map((h) {
              return Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAF8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border(
                    left: BorderSide(color: h.qualityColor, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          formatVnDate(h.harvestedAt),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (h.weightKg != null)
                          Text(
                            '${h.weightKg} kg',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        const Spacer(),
                        GardenChip(
                          label: h.qualityLabel,
                          color: h.qualityColor,
                        ),
                      ],
                    ),
                    if ((h.note ?? '').isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        h.note!,
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ],
                    if ((h.warning ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        h.warning!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Card mốc thời gian ─────────────────────────────────────────────────

  Widget _buildStageHistoryCard(GardenPlantDetail d) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('⏱️', style: TextStyle(fontSize: 15)),
                  SizedBox(width: 7),
                  Text(
                    'MỐC THỜI GIAN',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _updateStage,
                icon: const Icon(Icons.edit_rounded, size: 15),
                label: const Text('Cập nhật', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (d.stageHistory.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Chưa có mốc nào.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF6C757D)),
                ),
              ),
            )
          else
            ...d.stageHistory.asMap().entries.map((e) {
              final s = e.value;
              final isLast = e.key == d.stageHistory.length - 1;
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: stageColor(s.stage),
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: const Color(0xFFDDE5E1),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              formatVnDate(s.at) +
                                  ((s.note ?? '').isNotEmpty ? ' · ${s.note}' : ''),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF6C757D),
                              ),
                            ),
                          ],
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

  // ── Card nhóm cây ──────────────────────────────────────────────────────

  Widget _buildGroupCard(GardenPlantDetail d) {
    final soilWarning = d.soil?.soilWarning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grass_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                d.nhomCayLabel!,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow('Chu kỳ thu hoạch',
              d.soNgayThuHoach != null ? '${d.soNgayThuHoach} ngày' : '—'),
          _infoRow('Kỳ cắt tỉa',
              d.kyCatTia != null ? '${d.kyCatTia} ngày' : '—'),
          if ((d.ghiChuMuaVu ?? '').isNotEmpty)
            _infoRow('Ghi chú mùa vụ', d.ghiChuMuaVu!),
          if ((soilWarning ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            GardenBanner(
              text: soilWarning!,
              kind: GardenBannerKind.warning,
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF6C757D)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(GardenPlantDetail d) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sticky_note_2_outlined,
                  size: 17, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'GHI CHÚ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            d.notes!,
            style: const TextStyle(fontSize: 12.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── Nút hành động ──────────────────────────────────────────────────────

  Widget _buildActionButtons(GardenPlantDetail d) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'Chụp ảnh',
                icon: Icons.photo_camera_rounded,
                color: AppColors.primary,
                onTap: _busy ? null : () => _pickPhoto(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                label: 'Thư viện',
                icon: Icons.photo_library_rounded,
                color: const Color(0xFF1D4ED8),
                onTap: _busy ? null : () => _pickPhoto(ImageSource.gallery),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'Thu hoạch',
                icon: Icons.grass_rounded,
                color: const Color(0xFFE07A00),
                onTap: _busy ? null : _harvest,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                label: 'Xóa cây',
                icon: Icons.delete_outline_rounded,
                color: const Color(0xFFDC2626),
                onTap: _busy ? null : _delete,
              ),
            ),
          ],
        ),
        if (_busy) ...[
          const SizedBox(height: 14),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
