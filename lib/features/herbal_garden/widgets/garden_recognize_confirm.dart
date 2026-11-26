// lib/features/herbal_garden/widgets/garden_recognize_confirm.dart
//
// Màn hình xác nhận kết quả nhận diện từ ảnh.
//
// ⚠️ YÊU CẦU UX: sau khi chụp/chọn ảnh, KHÔNG tự động gán loài cây vào vườn.
// App phải đưa ra kết quả (tên cây + độ tin cậy + ảnh) và hỏi người dùng:
//   • "Đồng ý — dùng cây này"  → chọn loài đó làm cây trong vườn
//   • "Chọn cây khác"           → về màn tìm theo tên
// Nếu không có màn này, người dùng bị "ép" nhận diện sai và không có cách
// sửa lại ngoài việc xoá cây.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:thunghiem1/features/herbal_garden/models/garden_models.dart';
import 'package:thunghiem1/features/herbal_garden/widgets/garden_style.dart';
import 'package:thunghiem1/theme/app_colors.dart';

/// Kết quả người dùng chọn ở màn xác nhận.
enum RecognizeConfirmChoice {
  /// Đồng ý với kết quả → dùng làm cây trong vườn.
  accept,

  /// Chọn cây khác → về màn tìm theo tên.
  chooseAnother,
}

/// Màn xác nhận kết quả nhận diện.
///
/// Trả về `RecognizeConfirmChoice?` — null nếu người dùng đóng màn.
class GardenRecognizeConfirmSheet extends StatelessWidget {
  final PlantPrediction prediction;
  final String? localImagePath;

  const GardenRecognizeConfirmSheet({
    super.key,
    required this.prediction,
    this.localImagePath,
  });

  @override
  Widget build(BuildContext context) {
    final p = prediction;
    final confidence = p.confidenceValue;
    // ⚠️ Thông báo thân thiện: KHÔNG hiển thị chuỗi cảnh báo dài dòng của
    // server (chứa "mô hình phụ", "AI model"…). Thay bằng 1 câu ngắn.
    final warning = p.friendlyWarning;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Đây là cây này?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),

            // Ảnh cây nhận diện
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: localImagePath != null
                    ? Image.file(
                        File(localImagePath!),
                        width: 132,
                        height: 132,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imageBox(),
                      )
                    : _imageBox(),
              ),
            ),
            const SizedBox(height: 14),

            // Tên cây
            Text(
              p.commonName.isEmpty ? 'Không rõ tên' : p.commonName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            if ((p.scientificName ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: 3),
              Text(
                p.scientificName!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Độ tin cậy
            if (confidence != null)
              Center(
                child: GardenChip(
                  label: 'Tin cậy ${(confidence * 100).round()}%',
                  icon: Icons.verified_rounded,
                  color: confidence >= 0.6
                      ? AppColors.success
                      : const Color(0xFFE2703A),
                  filled: true,
                ),
              ),

            // Thông báo nhẹ — KHÔNG nói tới "mô hình phụ", chỉ nói "tham khảo".
            if (warning != null) ...<Widget>[
              const SizedBox(height: 14),
              GardenWarningBanner(message: warning),
            ],

            const SizedBox(height: 18),

            // Nút hành động
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      RecognizeConfirmChoice.chooseAnother,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.35),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: const Text(
                      'Chọn cây khác',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, RecognizeConfirmChoice.accept),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: const Text(
                      'Đồng ý, dùng cây này',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
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
      width: 132,
      height: 132,
      color: AppColors.primary.withValues(alpha: 0.07),
      alignment: Alignment.center,
      child: const Icon(Icons.eco_rounded, size: 42, color: Color(0xFF7FA894)),
    );
  }
}
