import 'package:flutter/material.dart';

Future<bool?> showErrorDialog(
  BuildContext context,
  String message, {
  String title = 'Thông báo',
  String? confirmLabel,
}) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF2D6A4F)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Text(message, style: const TextStyle(fontSize: 14, height: 1.5)),
      actions: [
        if (confirmLabel != null)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ'),
          ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            confirmLabel ?? 'Đã hiểu',
            style: TextStyle(
              color: Color(0xFF2D6A4F),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}
