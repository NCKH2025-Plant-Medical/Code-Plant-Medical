// lib/widgets/map_plant_detail_sheet.dart
//
// Bottom sheet hiển thị chi tiết cây khi bấm vào marker trên bản đồ.
//
// Phân luồng theo nguồn dữ liệu:
//   • PlantSource.system → PlantDetailSheet (tra cứu MySQL theo plantId)
//   • PlantSource.user   → UserPlantDetailSheet (thông tin cây user tự chụp)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:thunghiem1/controllers/map_notifier.dart';
import 'package:thunghiem1/models/plant_map_marker.dart';
import 'package:thunghiem1/models/plant_suggestion.dart';
import 'package:thunghiem1/models/user_plant.dart';
import 'package:thunghiem1/screens/plant_detail_sheet.dart';
import 'package:thunghiem1/theme/app_colors.dart';
import 'package:thunghiem1/widgets/user_plant_detail_sheet.dart';

class MapPlantDetailSheet extends StatelessWidget {
  final PlantMapMarker plant;
  final MapNotifier? notifier;

  const MapPlantDetailSheet({
    super.key,
    required this.plant,
    this.notifier,
  });

  static Future<void> show(
    BuildContext context,
    PlantMapMarker plant, {
    MapNotifier? notifier,
  }) {
    final effectiveNotifier =
        notifier ??
        (() {
          try {
            return context.read<MapNotifier>();
          } catch (_) {
            return null;
          }
        })();

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MapPlantDetailSheet(
        plant: plant,
        notifier: effectiveNotifier,
      ),
    );
  }

  /// Mở màn hình chi tiết đúng theo nguồn dữ liệu.
  ///
  /// Yêu cầu: "Khi bấm nút 'Xem thông tin chi tiết' → xử lý rẽ nhánh theo
  /// nguồn dữ liệu".
  ///
  /// Lưu ý: [navigator] được truyền vào từ bên ngoài vì sheet này sẽ bị
  /// `Navigator.pop()` ngay trước khi mở sheet mới — dùng lại `context` của
  /// widget đã bị deactivate sẽ gây lỗi runtime.
  static void _openDetail(NavigatorState navigator, PlantMapMarker plant) {
    if (plant.source == PlantSource.system) {
      // 1. Cây hệ thống → tra cứu MySQL qua PlantDetailSheet
      showModalBottomSheet(
        context: navigator.context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PlantDetailSheet(
          prediction: PlantSuggestion(
            plantId: plant.plantId,
            scientificName: plant.scientificName ?? plant.name,
            commonName: plant.name,
            imageUrl: plant.imageUrl,
          ),
          showActions: false,
        ),
      );
    } else {
      // 2. Cây cá nhân → hiển thị sheet chi tiết cây người dùng tự chụp
      UserPlantDetailSheet.show(
        navigator.context,
        UserPlant.fromMapMarker(
          id: plant.id,
          plantId: plant.plantId,
          name: plant.name,
          scientificName: plant.scientificName,
          imageUrl: plant.imageUrl,
          description: plant.description,
          latitude: plant.latitude,
          longitude: plant.longitude,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = plant.source.color;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
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
                            color: isDark ? AppColors.darkOnSurface : Colors.black87,
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
                        _SourceBadge(plant: plant),
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

              if (plant.description != null &&
                  plant.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  plant.description!,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Vị trí
              Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${plant.latitude.toStringAsFixed(5)}, '
                      '${plant.longitude.toStringAsFixed(5)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final nav = notifier ?? context.read<MapNotifier>();
                          Navigator.pop(context);
                          nav.startNavigationTo(plant);
                        },
                        icon: const Icon(
                          Icons.directions_rounded,
                          color: Color(0xFF1565C0),
                          size: 20,
                        ),
                        label: const Text(
                          'Chỉ đường',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFF1565C0),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed:
                            (plant.source == PlantSource.system &&
                                plant.plantId.isEmpty)
                            ? null
                            : () {
                                final navigator = Navigator.of(context);
                                Navigator.pop(context);
                                _openDetail(navigator, plant);
                              },
                        icon: const Icon(
                          Icons.info_outline_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: const Text(
                          'Xem chi tiết',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final PlantMapMarker plant;
  final Color accent;

  const _Thumbnail({required this.plant, required this.accent});

  @override
  Widget build(BuildContext context) {
    final hasImage = plant.imageUrl != null && plant.imageUrl!.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 72,
        height: 72,
        child: hasImage
            ? Image.network(
                plant.imageUrl!,
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
      child: Icon(Icons.eco_rounded, color: accent, size: 32),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final PlantMapMarker plant;

  const _SourceBadge({required this.plant});

  @override
  Widget build(BuildContext context) {
    final accent = plant.source.color;
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
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            plant.source.label,
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
