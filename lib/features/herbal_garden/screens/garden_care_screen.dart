// lib/features/herbal_garden/screens/garden_care_screen.dart
//
// MÀN HÌNH "VIỆC HÔM NAY" — trang con thứ 2 của Vườn Dược Liệu
//
// Tách riêng phần "Việc hôm nay" khỏi màn hình "Vườn của tôi" để người dùng
// có 1 nơi duy nhất để xem & xử lý toàn bộ việc chăm sóc trong ngày.
//
// API được gọi:
//   GET  /api/v1/herbal-garden/care-today     → danh sách việc
//   POST /api/v1/herbal-garden/{id}/water      → ghi nhận đã tưới
//   POST /api/v1/herbal-garden/{id}/harvest    → ghi sổ thu hoạch
//   POST /api/v1/herbal-garden/{id}/task/dismiss → gỡ thẻ việc / chọn lựa chọn

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:thunghiem1/features/herbal_garden/models/garden_models.dart';
import 'package:thunghiem1/features/herbal_garden/screens/garden_plant_detail_screen.dart';
import 'package:thunghiem1/features/herbal_garden/services/herbal_garden_api.dart';
import 'package:thunghiem1/features/herbal_garden/state/herbal_garden_state.dart';
import 'package:thunghiem1/features/herbal_garden/widgets/garden_cards.dart';
import 'package:thunghiem1/features/herbal_garden/widgets/garden_harvest_dialog.dart';
import 'package:thunghiem1/features/herbal_garden/widgets/garden_harvest_outcome_sheet.dart';
import 'package:thunghiem1/features/herbal_garden/widgets/garden_style.dart';
import 'package:thunghiem1/theme/app_colors.dart';

class GardenCareScreen extends StatefulWidget {
  const GardenCareScreen({super.key});

  @override
  State<GardenCareScreen> createState() => _GardenCareScreenState();
}

class _GardenCareScreenState extends State<GardenCareScreen> {
  /// Task đang xử lý (để disable nút + hiện spinner đúng chỗ).
  String? _busyTaskKey;

  /// Loại việc đang được LỌC (null = hiện tất cả).
  ///
  /// ⚠️ Yêu cầu UX: bấm vào 1 chip tóm tắt (VD "🌾 Thu hoạch 3") thì danh
  /// sách chỉ hiện đúng loại việc đó. Bấm lần 2 → bỏ lọc.
  String? _taskTypeFilter;

  static const Map<String, List<String>> _filterGroups = <String, List<String>>{
    // Nhóm "Cần tưới" gộp cả tưới nước lẫn bỏ rơi (cùng hành động).
    'tuoi': <String>['tuoi', 'bo_roi'],
    'thu_hoach': <String>['thu_hoach'],
    'ngoai_mua': <String>['ngoai_mua'],
    'chup_anh': <String>['chup_anh'],
    'cat_tia': <String>['cat_tia'],
    'nay_mam': <String>['nay_mam'],
    'co_the_chet': <String>['co_the_chet'],
  };

  String _taskKey(CareTask task) => '${task.plantId}:${task.taskType}';

  /// Danh sách việc sau khi áp bộ lọc loại.
  List<CareTask> _filteredTasks(CareToday care) {
    final filter = _taskTypeFilter;
    if (filter == null) return care.tasks;
    final types = _filterGroups[filter] ?? <String>[filter];
    return care.tasks.where((t) => types.contains(t.taskType)).toList();
  }

  // ── Điều hướng ───────────────────────────────────────────────────────────

  Future<void> _openPlantDetail(String plantId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GardenPlantDetailScreen(plantId: plantId),
      ),
    );
    if (mounted) await context.read<HerbalGardenController>().loadAll();
  }

  // ── Hành động trên thẻ việc ─────────────────────────────────────────────

  Future<void> _handleWater(CareTask task) async {
    final controller = context.read<HerbalGardenController>();
    setState(() => _busyTaskKey = _taskKey(task));
    try {
      final message = await controller.waterPlant(task.plantId);
      if (!mounted) return;
      _showSnack(message, ok: true);
    } on GardenApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, ok: false);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Không ghi nhận được lần tưới. Thử lại nhé.', ok: false);
    } finally {
      if (mounted) setState(() => _busyTaskKey = null);
    }
  }

  Future<void> _handleHarvest(CareTask task) async {
    final controller = context.read<HerbalGardenController>();
    final input = await showDialog<({double? weightKg, String? note})>(
      context: context,
      builder: (_) => const GardenHarvestDialog(),
    );
    if (input == null || !mounted) return;

    setState(() => _busyTaskKey = _taskKey(task));
    bool harvested = false;
    try {
      final result = await controller.harvest(
        task.plantId,
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
      if (mounted) setState(() => _busyTaskKey = null);
    }

    if (!harvested || !mounted) return;
    await _askKeepAfterHarvest(task);
  }

  /// Sau khi thu hoạch — hỏi giữ cây (chuẩn bị mùa vụ mới) hay bỏ cây.
  Future<void> _askKeepAfterHarvest(CareTask task) async {
    final controller = context.read<HerbalGardenController>();
    final plantName = (task.tenCay ?? task.tenLabel).trim();

    final choice = await showModalBottomSheet<HarvestOutcomeChoice>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => GardenHarvestOutcomeSheet(plantName: plantName),
    );
    if (choice == null || !mounted) return;

    if (choice == HarvestOutcomeChoice.keep) {
      // Giữ cây → đánh dấu lại mốc "Mới gieo" để bắt đầu vụ mới.
      setState(() => _busyTaskKey = _taskKey(task));
      try {
        final message = await controller.updateStage(
          task.plantId,
          stage: 'gieo_trong',
          note: 'Bắt đầu vụ mới sau khi thu hoạch',
        );
        if (!mounted) return;
        _showSnack(message, ok: true);
      } on GardenApiException catch (e) {
        if (!mounted) return;
        _showSnack(e.message, ok: false);
      } catch (_) {
        if (!mounted) return;
        _showSnack('Không đánh dấu lại được cây.', ok: false);
      } finally {
        if (mounted) setState(() => _busyTaskKey = null);
      }
      return;
    }

    // Không giữ → xoá mềm cây (vẫn xem lại được ở "Cây đã xoá").
    setState(() => _busyTaskKey = _taskKey(task));
    try {
      final message = await controller.deletePlant(task.plantId);
      if (!mounted) return;
      _showSnack(message, ok: true);
    } on GardenApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, ok: false);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Không bỏ được cây. Vui lòng thử lại.', ok: false);
    } finally {
      if (mounted) setState(() => _busyTaskKey = null);
    }
  }

  Future<void> _handleDismiss(CareTask task) async {
    final controller = context.read<HerbalGardenController>();
    setState(() => _busyTaskKey = _taskKey(task));
    try {
      final message = await controller.dismissTask(
        task.plantId,
        taskType: task.taskType,
      );
      if (!mounted) return;
      _showSnack(message, ok: true);
    } on GardenApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, ok: false);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Không gỡ được thẻ việc.', ok: false);
    } finally {
      if (mounted) setState(() => _busyTaskKey = null);
    }
  }

  Future<void> _handleChoice(CareTask task, TaskChoice choice) async {
    final controller = context.read<HerbalGardenController>();
    setState(() => _busyTaskKey = _taskKey(task));
    try {
      final message = await controller.dismissTask(
        task.plantId,
        taskType: task.taskType,
        choiceId: choice.id,
      );
      if (!mounted) return;
      _showSnack(message, ok: true);
      if (choice.canhBao != null && choice.canhBao!.isNotEmpty) {
        _showSnack(choice.canhBao!, ok: false);
      }
    } on GardenApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, ok: false);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Không ghi nhận được lựa chọn.', ok: false);
    } finally {
      if (mounted) setState(() => _busyTaskKey = null);
    }
  }

  void _showSnack(String message, {required bool ok}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          backgroundColor: ok ? AppColors.primary : const Color(0xFFB0621A),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: ok ? 2 : 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
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
          onRefresh: () => controller.loadCare(refresh: true),
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: <Widget>[
              _buildHeader(controller),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                  child: _buildTasks(controller),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(HerbalGardenController controller) {
    final total = controller.care.total;

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
        child: Row(
          children: <Widget>[
            // Nút quay lại tường minh — không bắt người dùng dùng nút back
            // của hệ điều hành.
            _RoundIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 12),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Việc hôm nay',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    controller.care.date.isNotEmpty
                        ? gardenFormatDate(
                            DateTime.tryParse(controller.care.date),
                          )
                        : 'Danh sách việc chăm sóc',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            if (total > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.pending_actions_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Danh sách việc ──────────────────────────────────────────────────────

  Widget _buildTasks(HerbalGardenController controller) {
    final care = controller.care;
    final tasks = _filteredTasks(care);
    final hasFilter = _taskTypeFilter != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildSummary(care),
        const SizedBox(height: 16),
        if (controller.isLoadingCare && care.tasks.isEmpty)
          const _LoadingBox(height: 120)
        else if (controller.careError != null && care.tasks.isEmpty)
          GardenErrorBanner(
            message: controller.careError!,
            onRetry: () => controller.loadCare(),
          )
        else if (care.tasks.isEmpty)
          const GardenCard(
            child: GardenInfoBanner(
              message:
                  'Hôm nay không có việc nào cần làm. Cây của bạn đang ổn!',
              icon: Icons.check_circle_rounded,
            ),
          )
        else if (tasks.isEmpty)
          GardenCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const GardenInfoBanner(
                  message:
                      'Không có việc nào thuộc nhóm đang lọc. '
                      'Bấm "Bỏ lọc" để xem tất cả.',
                  icon: Icons.filter_alt_off_rounded,
                ),
                const SizedBox(height: 12),
                GardenOutlineButton(
                  label: 'Bỏ lọc',
                  icon: Icons.filter_alt_off_rounded,
                  onPressed: () => setState(() => _taskTypeFilter = null),
                ),
              ],
            ),
          )
        else ...<Widget>[
          // Dòng báo đang lọc + nút bỏ lọc.
          if (hasFilter)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.filter_alt_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Đang lọc: ${_filterLabel(_taskTypeFilter!)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _taskTypeFilter = null),
                    icon: const Icon(Icons.close_rounded, size: 15),
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
            ),
          ...tasks.map((task) {
            final key = _taskKey(task);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GardenCareTaskCard(
                task: task,
                busy: _busyTaskKey == key,
                onOpenPlant: () => _openPlantDetail(task.plantId),
                onWater: task.taskType == 'tuoi' || task.taskType == 'bo_roi'
                    ? () => _handleWater(task)
                    : null,
                onHarvest: task.taskType == 'thu_hoach'
                    ? () => _handleHarvest(task)
                    : null,
                onDismiss: task.coTheDismiss
                    ? () => _handleDismiss(task)
                    : null,
                onChoose: task.luaChon.isNotEmpty
                    ? (choice) => _handleChoice(task, choice)
                    : null,
              ),
            );
          }),
        ],
      ],
    );
  }

  /// Nhãn nhóm việc tương ứng với mã lọc.
  String _filterLabel(String code) {
    switch (code) {
      case 'tuoi':
        return 'Cần tưới';
      case 'thu_hoach':
        return 'Thu hoạch';
      case 'ngoai_mua':
        return 'Ngoài mùa';
      case 'chup_anh':
        return 'Chụp ảnh';
      case 'cat_tia':
        return 'Cắt tỉa';
      case 'nay_mam':
        return 'Nảy mầm';
      case 'co_the_chet':
        return 'Có thể đã chết';
      default:
        return GardenTaskStyle.label(code);
    }
  }

  /// Dải chip tóm tắt số việc theo loại — BẤM ĐƯỢC để lọc.
  Widget _buildSummary(CareToday care) {
    final entries = <(String, String, int, Color)>[
      ('💧', 'tuoi', care.soCanTuoi, const Color(0xFF3B82C4)),
      ('🌾', 'thu_hoach', care.soSanSangThuHoach, AppColors.success),
      ('📅', 'ngoai_mua', care.soNgoaiMua, const Color(0xFFE2703A)),
      ('📸', 'chup_anh', care.soNhacChupAnh, const Color(0xFF8A9BA8)),
      ('✂️', 'cat_tia', care.soDenKyCatTia, const Color(0xFFE8A33D)),
      ('🌱', 'nay_mam', care.soChuaNayMam, const Color(0xFFE8A33D)),
      ('⚠️', 'co_the_chet', care.soCoTheChet, const Color(0xFFD64545)),
    ].where((e) => e.$3 > 0).toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, i) {
          final e = entries[i];
          return GardenSelectChip(
            label: '${e.$1} ${_filterLabel(e.$2)} ${e.$3}',
            color: e.$4,
            selected: _taskTypeFilter == e.$2,
            onTap: () => setState(() {
              _taskTypeFilter = _taskTypeFilter == e.$2 ? null : e.$2;
            }),
          );
        },
      ),
    );
  }
}

// ── Widget phụ ────────────────────────────────────────────────────────────

/// Nút tròn trên nền gradient — dùng cho nút quay lại.
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
