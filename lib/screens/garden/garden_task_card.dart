// lib/screens/garden/garden_task_card.dart
//
// Thẻ việc "Việc hôm nay" — trái tim của màn hình vườn.
//
// Mỗi thẻ hiển thị (Mục 3.3 của hướng dẫn sử dụng):
//   • viền màu theo `priority` (đỏ / vàng / xám)
//   • tiêu đề + mô tả (NGUYÊN VĂN từ server)
//   • checklist `huong_dan`
//   • các nút lựa chọn `lua_chon` (task ngoài mùa)
//   • nút hành động theo `task_type`

import 'package:flutter/material.dart';
import 'package:thunghiem1/models/herbal_garden.dart';
import 'package:thunghiem1/screens/garden/garden_constants.dart';
import 'package:thunghiem1/screens/garden/garden_widgets.dart';

class GardenTaskCard extends StatelessWidget {
  const GardenTaskCard({
    super.key,
    required this.task,
    required this.onAction,
    required this.onDismiss,
    required this.onChoice,
    required this.onOpenPlant,
  });

  final CareTask task;

  /// Hành động chính (Tưới xong / Thu hoạch / Đã cắt tỉa / Chụp ảnh).
  final void Function(CareTask task) onAction;

  /// Gỡ thẻ / bỏ qua.
  final void Function(CareTask task) onDismiss;

  /// Chọn 1 lựa chọn trong `lua_chon`.
  final void Function(CareTask task, TaskChoice choice) onChoice;

  /// Mở màn hình chi tiết cây.
  final VoidCallback onOpenPlant;

  @override
  Widget build(BuildContext context) {
    final color = taskPriorityColor(task.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tiêu đề ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(taskIcon(task.taskType), color: color, size: 19),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      if (task.stageLabel != null) ...[
                        const SizedBox(height: 4),
                        StageChip(stage: task.stage ?? '', label: task.stageLabel!),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // ── Mô tả (nguyên văn) ──
            if (task.description != null && task.description!.isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(
                task.description!,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: Colors.black.withValues(alpha: 0.75),
                ),
              ),
            ],

            // ── Checklist "Bạn cần làm gì" ──
            if (task.huongDan.isNotEmpty) ...[
              const SizedBox(height: 11),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAF8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bạn cần làm gì',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D6A4F),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...task.huongDan.asMap().entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${e.key + 1}.',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2D6A4F),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                e.value,
                                style: const TextStyle(fontSize: 12.5, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

            // ── Các lựa chọn (task ngoài mùa) ──
            if (task.luaChon.isNotEmpty) ...[
              const SizedBox(height: 11),
              ...task.luaChon.map((choice) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: InkWell(
                    onTap: () => onChoice(task, choice),
                    borderRadius: BorderRadius.circular(11),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAF8),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: const Color(0xFFDDE5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  choice.label,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: Color(0xFF2D6A4F),
                              ),
                            ],
                          ),
                          if (choice.moTa != null && choice.moTa!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              choice.moTa!,
                              style: const TextStyle(fontSize: 12, height: 1.4),
                            ),
                          ],
                          if (choice.canhBao != null &&
                              choice.canhBao!.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              choice.canhBao!,
                              style: const TextStyle(
                                fontSize: 11.5,
                                height: 1.4,
                                color: Color(0xFFB45309),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],

            // ── Nút hành động ──
            const SizedBox(height: 12),
            Row(
              children: [
                if (!_hasChoiceOnly) ...[
                  Expanded(
                    child: _TaskActionButton(
                      label: _actionLabel,
                      icon: taskIcon(task.taskType),
                      color: color,
                      onPressed: () => onAction(task),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (task.coTheDismiss) ...[
                  Expanded(
                    child: _TaskActionButton(
                      label: 'Đã xong',
                      icon: Icons.check_rounded,
                      color: const Color(0xFF6C757D),
                      onPressed: () => onDismiss(task),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                _TaskActionButton(
                  label: 'Xem cây',
                  icon: Icons.open_in_new_rounded,
                  color: const Color(0xFF2D6A4F),
                  onPressed: onOpenPlant,
                  compact: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Task chỉ có lựa chọn (ngoài mùa) → không cần nút hành động riêng.
  bool get _hasChoiceOnly =>
      task.luaChon.isNotEmpty && !task.coTheDismiss;

  String get _actionLabel => switch (task.taskType) {
        'tuoi' => 'Tưới xong',
        'thu_hoach' => 'Thu hoạch',
        'cat_tia' => 'Đã cắt tỉa',
        'co_the_chet' => 'Kiểm tra',
        'chup_anh' => 'Chụp ảnh',
        'nay_mam' => 'Chụp ảnh',
        _ => 'Xử lý',
      };
}

class _TaskActionButton extends StatelessWidget {
  const _TaskActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: compact ? 12 : 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.32)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
