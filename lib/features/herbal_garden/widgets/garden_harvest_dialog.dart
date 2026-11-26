// lib/features/herbal_garden/widgets/garden_harvest_dialog.dart
//
// Dialog nhập khối lượng + ghi chú cho sổ thu hoạch.
// Dùng chung cho màn hình chính (thẻ việc "đến kỳ thu hoạch") và màn hình
// chi tiết cây → tránh trùng logic.

import 'package:flutter/material.dart';
import 'package:thunghiem1/theme/app_colors.dart';

class GardenHarvestDialog extends StatefulWidget {
  const GardenHarvestDialog({super.key});

  @override
  State<GardenHarvestDialog> createState() => _GardenHarvestDialogState();
}

class _GardenHarvestDialogState extends State<GardenHarvestDialog> {
  final _weightController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _weightController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Ghi sổ thu hoạch',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Khối lượng (kg)',
              hintText: 'VD: 1.5',
              prefixIcon: Icon(Icons.scale_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Ghi chú (tuỳ chọn)',
              hintText: 'VD: Lứa 1',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () {
            final raw = _weightController.text.trim().replaceAll(',', '.');
            final weight = double.tryParse(raw);
            final note = _noteController.text.trim();
            Navigator.pop(context, (
              weightKg: weight,
              note: note.isEmpty ? null : note,
            ));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Ghi nhận'),
        ),
      ],
    );
  }
}
