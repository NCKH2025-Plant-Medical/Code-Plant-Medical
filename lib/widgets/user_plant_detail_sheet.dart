// lib/widgets/user_plant_detail_sheet.dart
//
// Bottom sheet chi tiết cho CÂY CÁ NHÂN (cây do chính người dùng chụp).
//
// Khác với [PlantDetailSheet] (cây hệ thống → tra cứu MySQL),
// sheet này hiển thị thông tin do người dùng lưu: ảnh, tên, tọa độ GPS,
// độ tin cậy nhận diện, ghi chú và thời điểm chụp.

import 'package:flutter/material.dart';
import 'package:thunghiem1/models/user_plant.dart';
import 'package:thunghiem1/theme/app_colors.dart';

class UserPlantDetailSheet extends StatelessWidget {
  final UserPlant plant;

  const UserPlantDetailSheet({super.key, required this.plant});

  static Future<void> show(BuildContext context, UserPlant plant) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserPlantDetailSheet(plant: plant),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = AppColors.primaryVariant;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Thumbnail(plant: plant, accent: accent),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plant.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppColors.darkOnSurface
                                  : Colors.black87,
                            ),
                          ),
                          if (plant.scientificName != null &&
                              plant.scientificName!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              plant.scientificName!,
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          const _SourceBadge(),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Đóng',
                    ),
                  ],
                ),

                if (plant.notes != null && plant.notes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    plant.notes!,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // Các dòng thông tin
                _InfoRow(
                  icon: Icons.place_outlined,
                  label: 'Tọa độ',
                  value: plant.hasLocation
                      ? '${plant.latitude!.toStringAsFixed(5)}, '
                            '${plant.longitude!.toStringAsFixed(5)}'
                      : 'Không có dữ liệu GPS',
                ),
                _InfoRow(
                  icon: Icons.percent_rounded,
                  label: 'Độ tin cậy nhận diện',
                  value: plant.confidence != null
                      ? '${plant.confidence!.toStringAsFixed(2)}%'
                      : 'Không có',
                ),
                if (plant.capturedAt != null)
                  _InfoRow(
                    icon: Icons.schedule_rounded,
                    label: 'Thời điểm chụp',
                    value: _formatDate(plant.capturedAt!),
                  ),
                _InfoRow(
                  icon: Icons.eco_outlined,
                  label: 'Mã cây',
                  value: plant.plantId.isEmpty ? '—' : plant.plantId,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}

// ── Thành phần con ──────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  final UserPlant plant;
  final Color accent;

  const _Thumbnail({required this.plant, required this.accent});

  @override
  Widget build(BuildContext context) {
    final url = plant.displayImageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 88,
        height: 88,
        child: (url != null && url.isNotEmpty)
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: accent.withValues(alpha: 0.12),
      child: Icon(Icons.photo_camera_rounded, color: accent, size: 34),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge();

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.primaryVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Cây cá nhân',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDark ? Colors.white54 : Colors.grey),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
