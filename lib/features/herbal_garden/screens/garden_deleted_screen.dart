// lib/features/herbal_garden/screens/garden_deleted_screen.dart
//
// MÀN HÌNH 4 — CÂY ĐÃ XOÁ (THÙNG RÁC)
//
// Server xoá MỀM theo mặc định: cây bị ẩn khỏi danh sách nhưng dữ liệu vẫn
// còn và có thể khôi phục.
//
// API:
//   GET  /api/v1/herbal-garden/deleted        → danh sách cây đã xoá
//   POST /api/v1/herbal-garden/{id}/restore    → khôi phục cây

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:thunghiem1/features/herbal_garden/models/garden_models.dart';
import 'package:thunghiem1/features/herbal_garden/state/herbal_garden_state.dart';
import 'package:thunghiem1/features/herbal_garden/widgets/garden_cards.dart';
import 'package:thunghiem1/features/herbal_garden/widgets/garden_style.dart';
import 'package:thunghiem1/theme/app_colors.dart';

class GardenDeletedScreen extends StatefulWidget {
  const GardenDeletedScreen({super.key});

  @override
  State<GardenDeletedScreen> createState() => _GardenDeletedScreenState();
}

class _GardenDeletedScreenState extends State<GardenDeletedScreen> {
  String? _restoringId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HerbalGardenController>().loadDeleted();
    });
  }

  Future<void> _restore(DeletedGardenPlant plant) async {
    final controller = context.read<HerbalGardenController>();
    setState(() => _restoringId = plant.id);
    try {
      final message = await controller.restorePlant(plant.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Không khôi phục được: $e',
              style: const TextStyle(fontSize: 13),
            ),
            backgroundColor: const Color(0xFFB0621A),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _restoringId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HerbalGardenController>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Cây đã xoá',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.loadDeleted(),
        color: AppColors.primary,
        child: _buildBody(controller),
      ),
    );
  }

  Widget _buildBody(HerbalGardenController controller) {
    if (controller.isLoadingDeleted && controller.deletedPlants.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }

    if (controller.deletedError != null && controller.deletedPlants.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const SizedBox(height: 40),
          GardenErrorBanner(
            message: controller.deletedError!,
            onRetry: () => controller.loadDeleted(),
          ),
        ],
      );
    }

    if (controller.deletedPlants.isEmpty) {
      return ListView(
        children: <Widget>[
          const SizedBox(height: 60),
          const GardenEmptyState(
            icon: Icons.delete_outline_rounded,
            title: 'Thùng rác đang trống',
            message:
                'Các cây bạn xoá sẽ nằm ở đây và có thể khôi phục bất cứ lúc nào.',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      itemCount: controller.deletedPlants.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        if (i == 0) {
          return const GardenInfoBanner(
            message:
                'Xoá trong ứng dụng chỉ ẩn cây khỏi vườn — dữ liệu vẫn được giữ '
                'đầy đủ và có thể khôi phục bất cứ lúc nào.',
            icon: Icons.info_outline_rounded,
          );
        }
        final plant = controller.deletedPlants[i - 1];
        return _buildDeletedTile(plant, controller);
      },
    );
  }

  Widget _buildDeletedTile(
    DeletedGardenPlant plant,
    HerbalGardenController controller,
  ) {
    final restoring = _restoringId == plant.id;

    return GardenCard(
      child: Row(
        children: <Widget>[
          GardenNetworkImage(url: plant.imageUrl, width: 56, height: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  plant.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Xoá ngày ${gardenFormatDate(plant.deletedAt)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    GardenChip(
                      label:
                          kGardenStageLabels[plant.stage ?? ''] ?? 'Mới gieo',
                      icon: GardenStageStyle.icon(plant.stage ?? 'gieo_trong'),
                      color: GardenStageStyle.color(
                        plant.stage ?? 'gieo_trong',
                      ),
                    ),
                    const SizedBox(width: 6),
                    GardenChip(
                      label: '${plant.soAnhTimeline} ảnh',
                      color: const Color(0xFF8A9BA8),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          restoring
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : IconButton(
                  onPressed: () => _restore(plant),
                  icon: const Icon(Icons.restore_rounded),
                  color: AppColors.primary,
                  tooltip: 'Khôi phục',
                ),
        ],
      ),
    );
  }
}
