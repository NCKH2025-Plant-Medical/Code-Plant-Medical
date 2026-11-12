// lib/screens/garden/deleted_plants_screen.dart
//
// MÀN HÌNH 5 — "CÂY ĐÃ XOÁ"
//
// Xoá cây là xoá mềm (soft-delete): cây bị ẩn khỏi vườn nhưng vẫn giữ nguyên
// ảnh nhật ký, sổ thu hoạch, lịch sử tưới. Có thể khôi phục lại.
//
//   GET  /api/v1/herbal-garden/deleted        → danh sách cây đã xoá
//   POST /api/v1/herbal-garden/{id}/restore   → khôi phục

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:thunghiem1/controllers/garden_notifier.dart';
import 'package:thunghiem1/models/herbal_garden.dart';
import 'package:thunghiem1/screens/garden/garden_constants.dart';
import 'package:thunghiem1/services/herbal_garden_api.dart';
import 'package:thunghiem1/theme/app_colors.dart';

class DeletedPlantsScreen extends StatefulWidget {
  const DeletedPlantsScreen({super.key});

  @override
  State<DeletedPlantsScreen> createState() => _DeletedPlantsScreenState();
}

class _DeletedPlantsScreenState extends State<DeletedPlantsScreen> {
  final HerbalGardenApi _api = HerbalGardenApi();

  List<DeletedPlantItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = context.read<GardenNotifier>().uid;
      final items = await _api.deletedPlants(uid: uid);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _restore(DeletedPlantItem item) async {
    try {
      final garden = context.read<GardenNotifier>();
      final msg = await garden.restorePlant(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cây đã xoá'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 42, color: Color(0xFF9AA5A1)),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6C757D)),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_sweep_rounded,
                                size: 48, color: Color(0xFF9AA5A1)),
                            SizedBox(height: 12),
                            Text(
                              'Bạn chưa xoá cây nào.',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Cây đã xoá vẫn giữ nguyên ảnh & sổ thu hoạch,\n'
                              'bạn có thể khôi phục bất cứ lúc nào.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF6C757D),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 11),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: item.imageUrl != null &&
                                          item.imageUrl!.isNotEmpty
                                      ? Image.network(
                                          item.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: const Color(0xFFEDF1EF),
                                            child: const Icon(
                                              Icons.eco_rounded,
                                              color: Color(0xFF9AA5A1),
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: const Color(0xFFEDF1EF),
                                          child: const Icon(
                                            Icons.eco_rounded,
                                            color: Color(0xFF9AA5A1),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.tenCay ?? item.tenLabel ?? '—',
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      [
                                        if (item.stageLabel != null)
                                          item.stageLabel!,
                                        if (item.soAnhTimeline > 0)
                                          '📸${item.soAnhTimeline}',
                                        if (item.soLanThuHoach > 0)
                                          '📖${item.soLanThuHoach}',
                                        if (item.deletedAt != null)
                                          'Xoá ${formatVnDate(item.deletedAt)}',
                                      ].join(' · '),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF6C757D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: () => _restore(item),
                                icon: const Icon(Icons.restore_rounded, size: 16),
                                label: const Text(
                                  'Khôi phục',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
