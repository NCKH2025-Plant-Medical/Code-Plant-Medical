// lib/features/herbal_garden/widgets/garden_harvest_outcome_sheet.dart
//
// Bottom sheet hỏi người dùng sau khi thu hoạch: giữ cây cho mùa vụ mới
// hay bỏ cây (xoá mềm → vào lịch sử "Cây đã xoá").
//
// Luồng nghiệp vụ:
//   Thu hoạch xong → hỏi "giữ cây lại để chuẩn bị cho mùa vụ mới không?"
//     • GIỮ  → mở sheet chọn mốc mới (thường là "Mới gieo" để bắt đầu vụ)
//     • BỎ   → xoá mềm cây → cây nằm trong mục "Cây đã xoá" (lịch sử)

import 'package:flutter/material.dart';
import 'package:thunghiem1/features/herbal_garden/models/garden_models.dart';
import 'package:thunghiem1/features/herbal_garden/widgets/garden_style.dart';
import 'package:thunghiem1/theme/app_colors.dart';

/// Kết quả người dùng chọn sau khi thu hoạch.
enum HarvestOutcomeChoice {
  /// Giữ cây → chọn lại mốc để bắt đầu vụ mới.
  keep,

  /// Không giữ → xoá cây (xoá mềm, vẫn xem được trong "Cây đã xoá").
  remove,
}

/// Bottom sheet hỏi giữ hay bỏ cây sau khi thu hoạch.
class GardenHarvestOutcomeSheet extends StatelessWidget {
  final String plantName;

  const GardenHarvestOutcomeSheet({super.key, required this.plantName});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 6),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.grass_rounded,
                    color: AppColors.success,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bạn đã thu hoạch $plantName',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Bạn có muốn giữ cây này lại để chuẩn bị cho mùa vụ mới không?',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: Colors.black.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 18),
            // Nút chính — GIỮ cây
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pop(context, HarvestOutcomeChoice.keep),
                icon: const Icon(Icons.spa_rounded, size: 19),
                label: const Text(
                  'Giữ cây — chuẩn bị mùa vụ mới',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Nút phụ — BỎ cây (xoá mềm)
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pop(context, HarvestOutcomeChoice.remove),
                icon: const Icon(Icons.archive_rounded, size: 18),
                label: const Text(
                  'Không giữ — bỏ cây vào lịch sử',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB0621A),
                  side: const BorderSide(color: Color(0xFFE2703A)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet chọn mốc mới cho cây được giữ lại sau thu hoạch.
///
/// Mặc định gợi ý "Mới gieo" (bắt đầu vụ mới) — nhưng người dùng có thể
/// chọn giai đoạn khác nếu cây còn sống (VD: cây thân gỗ ra hoa nhiều lần).
class GardenReseedStageSheet extends StatelessWidget {
  final String currentStage;

  const GardenReseedStageSheet({super.key, required this.currentStage});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Chọn mốc cho vụ mới',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              'Cây sẽ được đánh dấu lại từ giai đoạn này để theo dõi vụ mới.',
              style: TextStyle(fontSize: 12.5, height: 1.4),
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
              trailing: stage == currentStage
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
