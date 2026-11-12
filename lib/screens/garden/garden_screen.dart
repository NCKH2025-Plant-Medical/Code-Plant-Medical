// lib/screens/garden/garden_screen.dart
//
// MÀN HÌNH 1 — "VƯỜN CỦA TÔI"
//
// Cấu trúc (Mục 2 của bàn giao):
//   [Ảnh hero] Vườn Dược Liệu   🔔 badge việc hôm nay   [⟳ Làm mới]
//   ┌ Weather widget ─────────────────────────┐
//   ⭐ VIỆC HÔM NAY  (GET /care-today)
//   CÂY TRONG VƯỜN   (GET /api/v1/herbal-garden)
//   [ 📷 Chụp ảnh cây ]  [ 🔍 Tìm trong danh mục ]

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:thunghiem1/config/app_config.dart';
import 'package:thunghiem1/controllers/auth_notifier.dart';
import 'package:thunghiem1/controllers/garden_notifier.dart';
import 'package:thunghiem1/models/herbal_garden.dart';
import 'package:thunghiem1/screens/garden/add_garden_plant_screen.dart';
import 'package:thunghiem1/screens/garden/deleted_plants_screen.dart';
import 'package:thunghiem1/screens/garden/garden_constants.dart';
import 'package:thunghiem1/screens/garden/garden_plant_detail_screen.dart';
import 'package:thunghiem1/screens/garden/garden_task_card.dart';
import 'package:thunghiem1/screens/garden/garden_widgets.dart';
import 'package:thunghiem1/theme/app_colors.dart';

class GardenScreen extends StatefulWidget {
  const GardenScreen({super.key});

  @override
  State<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends State<GardenScreen> {
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  /// Nạp dữ liệu lần đầu + đồng bộ UID theo account đang đăng nhập.
  Future<void> _bootstrap() async {
    final garden = context.read<GardenNotifier>();
    final auth = context.read<AuthNotifier>();
    await auth.ready;
    if (!mounted) return;

    // Vườn mẫu `demo` (mặc định) thì không cần uid riêng; chỉ khi bật chế độ
    // vườn riêng (`GARDEN_PER_USER=true`) mới gắn uid của account.
    if (AppConfig.gardenPerUser) {
      garden.setUid(auth.userId);
    }
    await garden.load();

    // Làm mới định kỳ mỗi 5 phút — backend không cache nên mỗi lần gọi
    // `care-today` đều trạng thái mới nhất.
    _autoRefresh = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) garden.refresh();
    });
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

  // ── Xử lý hành động trên thẻ việc ─────────────────────────────────────

  Future<void> _handleTaskAction(CareTask task) async {
    final garden = context.read<GardenNotifier>();
    try {
      switch (task.taskType) {
        case 'tuoi':
          final msg = await garden.water(task.plantId);
          _showMessage(msg);
          break;
        case 'cat_tia':
          // Cắt tỉa → ghi nhận bằng cách cập nhật lại giai đoạn hiện tại.
          final msg = await garden.updateStage(
            task.plantId,
            task.stage ?? 'dang_lon',
            note: 'Đã cắt tỉa',
          );
          _showMessage(msg);
          break;
        case 'thu_hoach':
          // Thu hoạch → mở màn hình chi tiết cây để nhập khối lượng.
          await _openPlant(task.plantId);
          break;
        case 'chup_anh':
        case 'nay_mam':
          await _openPlant(task.plantId);
          break;
        case 'co_the_chet':
          await _openPlant(task.plantId);
          break;
        default:
          await _openPlant(task.plantId);
      }
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _handleDismiss(CareTask task) async {
    final garden = context.read<GardenNotifier>();
    try {
      final msg = await garden.dismiss(task);
      _showMessage(msg);
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _handleChoice(CareTask task, TaskChoice choice) async {
    final garden = context.read<GardenNotifier>();
    try {
      final msg = await garden.dismiss(task, choice: choice.id);
      _showMessage(msg);
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _openPlant(String plantId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GardenPlantDetailScreen(plantId: plantId),
      ),
    );
    if (mounted) context.read<GardenNotifier>().refresh();
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Consumer<GardenNotifier>(
        builder: (context, garden, _) {
          return SafeArea(
            child: RefreshIndicator(
              onRefresh: () => garden.refresh(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(garden)),
                  if (garden.status == GardenStatus.loading &&
                      garden.plants.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (garden.status == GardenStatus.error &&
                      garden.plants.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ErrorState(
                        message: garden.error ?? 'Không tải được dữ liệu.',
                        onRetry: () => garden.load(),
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(child: _buildWeather(garden)),
                    SliverToBoxAdapter(child: _buildCareToday(garden)),
                    SliverToBoxAdapter(child: _buildPlants(garden)),
                    SliverToBoxAdapter(child: _buildBottomActions()),
                    const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(GardenNotifier garden) {
    final care = garden.careToday;
    final taskCount = care?.total ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFF2D6A4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VƯỜN DƯỢC LIỆU',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${garden.plants.length} cây · '
                      '${garden.totalHarvestKg.toStringAsFixed(2)} kg đã thu hoạch',
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              // Badge số việc hôm nay
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$taskCount việc hôm nay',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Nút làm mới (bắt buộc theo Đợt 5)
              IconButton(
                tooltip: 'Làm mới',
                onPressed: () {
                  garden.refresh();
                  _showMessage('Đã làm mới dữ liệu.');
                },
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Thanh tóm tắt nhanh
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatPill(
                label: 'Cần tưới',
                value: care?.soCanTuoi ?? 0,
                color: const Color(0xFFDC2626),
              ),
              _StatPill(
                label: 'Cắt tỉa',
                value: care?.soDenKyCatTia ?? 0,
                color: const Color(0xFFD97706),
              ),
              _StatPill(
                label: 'Ngoài mùa',
                value: care?.soNgoaiMua ?? 0,
                color: const Color(0xFF6C757D),
              ),
              _StatPill(
                label: 'Sẵn sàng thu',
                value: care?.soSanSangThuHoach ?? 0,
                color: const Color(0xFFE07A00),
              ),
              _StatPill(
                label: 'Bị bỏ rơi',
                value: care?.soBoRoi ?? 0,
                color: const Color(0xFFDC2626),
              ),
              _StatPill(
                label: 'Có thể chết',
                value: care?.soCoTheChet ?? 0,
                color: const Color(0xFF991B1B),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Thời tiết ───────────────────────────────────────────────────────────

  Widget _buildWeather(GardenNotifier garden) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: WeatherWidget(weather: garden.weather),
    );
  }

  // ── Việc hôm nay ───────────────────────────────────────────────────────

  Widget _buildCareToday(GardenNotifier garden) {
    final care = garden.careToday;
    if (care == null || care.tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '📅 VIỆC HÔM NAY',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '· ${formatVnDate(DateTime.tryParse(care.date))}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...care.tasks.map(
            (task) => GardenTaskCard(
              task: task,
              onAction: _handleTaskAction,
              onDismiss: _handleDismiss,
              onChoice: _handleChoice,
              onOpenPlant: () => _openPlant(task.plantId),
            ),
          ),
        ],
      ),
    );
  }

  // ── Cây trong vườn ──────────────────────────────────────────────────────

  Widget _buildPlants(GardenNotifier garden) {
    final plants = garden.plants;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🌿 CÂY TRONG VƯỜN',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DeletedPlantsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text('Cây đã xoá', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (plants.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                children: [
                  Icon(Icons.yard_rounded, size: 40, color: Color(0xFF9AA5A1)),
                  SizedBox(height: 10),
                  Text(
                    'Vườn của bạn còn trống.',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Thêm cây đầu tiên để bắt đầu theo dõi.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF6C757D)),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: plants.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) {
                final plant = plants[index];
                return GardenPlantCard(
                  plant: plant,
                  onTap: () => _openPlant(plant.id),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Nút dưới ───────────────────────────────────────────────────────────

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _BottomAction(
              label: 'Chụp ảnh cây',
              icon: Icons.photo_camera_rounded,
              onTap: () {
                // Đi qua luồng nhận diện → chọn cây → thêm vào vườn.
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddGardenPlantScreen(
                      mode: AddGardenPlantMode.recognize,
                    ),
                  ),
                ).then((_) {
                  if (mounted) context.read<GardenNotifier>().refresh();
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _BottomAction(
              label: 'Tìm trong danh mục',
              icon: Icons.search_rounded,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddGardenPlantScreen(
                      mode: AddGardenPlantMode.search,
                    ),
                  ),
                ).then((_) {
                  if (mounted) context.read<GardenNotifier>().refresh();
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Thành phần nhỏ ─────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 19),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44, color: Color(0xFF9AA5A1)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6C757D)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
