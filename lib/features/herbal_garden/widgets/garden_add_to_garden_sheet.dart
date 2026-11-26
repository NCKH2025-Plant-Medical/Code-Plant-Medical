// lib/features/herbal_garden/widgets/garden_add_to_garden_sheet.dart
//
// MÀN HỎI "BẠN CÓ MUỐN THÊM CÂY NÀY VÀO VƯỜN KHÔNG?"
//
// ⚠️ YÊU CẦU UX (sau khi nhận diện ảnh):
//   • Chụp ảnh → hệ thống trả về 3 KẾT QUẢ.
//   • Người dùng CHỌN 1 kết quả → hiện sheet này hỏi có muốn đưa cây đó
//     vào vườn dược liệu không.
//   • "Có" → mở màn "Thêm cây vào vườn" (đã pre-fill loài cây đã chọn).
//   • "Không" → về màn kết quả nhận diện.
//
// ⚠️ Về thông báo: KHÔNG nói tới "mô hình phụ", "AI model", "source"… Người
// dùng không cần biết kỹ thuật. Chỉ nói ngắn gọn: "Kết quả chỉ là tham khảo".

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:thunghiem1/models/plants_model.dart';
import 'package:thunghiem1/theme/app_colors.dart';

/// Kết quả người dùng chọn ở sheet này.
enum AddToGardenChoice {
  /// Có — mở màn "Thêm cây vào vườn" với loài cây đã chọn.
  add,

  /// Không — ở lại màn kết quả nhận diện.
  cancel,
}

/// Sheet xác nhận thêm cây đã nhận diện vào vườn.
class GardenAddToGardenSheet extends StatelessWidget {
  final PlantPrediction plant;
  final String? localImagePath;

  const GardenAddToGardenSheet({
    super.key,
    required this.plant,
    this.localImagePath,
  });

  @override
  Widget build(BuildContext context) {
    final warning = plant.friendlyWarning;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Thêm vào vườn dược liệu?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),

            // Ảnh + tên cây vừa chọn.
            Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 68,
                    height: 68,
                    child: localImagePath != null
                        ? Image.file(
                            File(localImagePath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imageBox(),
                          )
                        : _imageBox(),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        plant.commonName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        plant.scientificName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                      ),
                      if (plant.confidence > 0) ...<Widget>[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Tin cậy ${plant.confidenceLabel}',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Thông báo thân thiện — KHÔNG nói tới "mô hình phụ".
            if (warning != null) ...<Widget>[
              const SizedBox(height: 14),
              _SoftNotice(message: warning, danger: plant.toxicLookalike),
            ],

            const SizedBox(height: 18),

            // Nút hành động.
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, AddToGardenChoice.cancel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.35),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Không',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, AddToGardenChoice.add),
                    icon: const Icon(Icons.yard_rounded, size: 19),
                    label: const Text(
                      'Thêm vào vườn',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageBox() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.07),
      alignment: Alignment.center,
      child: const Icon(Icons.eco_rounded, size: 30, color: Color(0xFF7FA894)),
    );
  }
}

/// Thông báo nhẹ trong sheet — cam cho "tham khảo", đỏ cho "nguy hiểm".
class _SoftNotice extends StatelessWidget {
  final String message;
  final bool danger;

  const _SoftNotice({required this.message, required this.danger});

  @override
  Widget build(BuildContext context) {
    final bg = danger ? const Color(0xFFFDECEC) : const Color(0xFFFFF4E5);
    final border = danger ? const Color(0xFFF3C4C4) : const Color(0xFFF7D9AE);
    final fg = danger ? const Color(0xFF8A2B2B) : const Color(0xFF8A4B12);
    final icon = danger
        ? Icons.report_gmailerrorred_rounded
        : Icons.info_outline_rounded;
    final iconColor = danger
        ? const Color(0xFFD64545)
        : const Color(0xFFE2703A);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: fg,
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
