// lib/features/herbal_garden/widgets/garden_note_dialog.dart
//
// Dialog nhập ghi chú ngắn (dùng chung cho "Đổi mốc" và "Thêm ảnh").
//
// ⚠️ LÝ DO TÁCH FILE: trước đây `_askNote()` trong
// `garden_plant_detail_screen.dart` tạo `TextEditingController` BÊN NGOÀI
// rồi `dispose()` ngay sau khi `showDialog` trả về. Khi người dùng bấm
// "Bỏ qua" (pop với `null`), luồng điều khiển đi tiếp với `note = null` và
// gọi API `updateStage` — nhưng `context` đã qua `await` nên `BuildContext`
// bị dùng sau khi widget dispose → **app treo / crash (use_build_context)**.
//
// Sửa: dialog dùng `StatefulWidget` tự quản lý controller, dispose trong
// `dispose()` của State (đúng vòng đời Flutter), và trả về một record có
// `cancelled` để caller biết người dùng đã bấm "Bỏ qua" hay chưa.

import 'package:flutter/material.dart';
import 'package:thunghiem1/theme/app_colors.dart';

/// Kết quả của [GardenNoteDialog].
class GardenNoteResult {
  /// Người dùng bấm "Bỏ qua" → không ghi gì cả, hủy toàn bộ thao tác.
  final bool cancelled;

  /// Nội dung ghi chú (có thể rỗng nếu người dùng bấm "Lưu" mà không nhập).
  final String note;

  const GardenNoteResult({required this.cancelled, required this.note});

  const GardenNoteResult.cancelled() : cancelled = true, note = '';

  const GardenNoteResult.saved(String value) : cancelled = false, note = value;
}

/// Dialog nhập ghi chú 1 dòng.
class GardenNoteDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String skipLabel;
  final String saveLabel;

  const GardenNoteDialog({
    super.key,
    required this.title,
    required this.hint,
    this.skipLabel = 'Bỏ qua',
    this.saveLabel = 'Lưu',
  });

  @override
  State<GardenNoteDialog> createState() => _GardenNoteDialogState();
}

class _GardenNoteDialogState extends State<GardenNoteDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(context, GardenNoteResult.saved(_controller.text.trim()));
  }

  void _skip() {
    Navigator.pop(context, const GardenNoteResult.cancelled());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 2,
        minLines: 1,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          hintText: widget.hint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: _skip, child: Text(widget.skipLabel)),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(widget.saveLabel),
        ),
      ],
    );
  }
}
