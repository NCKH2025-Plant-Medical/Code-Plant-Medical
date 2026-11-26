import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:thunghiem1/controllers/auth_notifier.dart';
import 'package:thunghiem1/services/review_feedback_service.dart';

class ReviewFeedbackScreen extends StatefulWidget {
  final String userId;

  const ReviewFeedbackScreen({super.key, required this.userId});

  @override
  State<ReviewFeedbackScreen> createState() => _ReviewFeedbackScreenState();
}

class _ReviewFeedbackScreenState extends State<ReviewFeedbackScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await ReviewFeedbackService.savedEntries(widget.userId);
    if (mounted) setState(() => _entries = entries);
  }

  Future<void> _revoke(Map<String, dynamic> entry) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ReviewFeedbackService.revoke(
        widget.userId,
        entry['prediction_id'].toString(),
        entry['revocation_token'].toString(),
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã rút lại đồng ý và xóa ảnh khỏi hệ thống.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa thể rút lại đồng ý. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ảnh đã gửi để cải thiện AI')),
    body: context.watch<AuthNotifier>().userId != widget.userId
        ? const Center(child: Text('Vui lòng đăng nhập để xem ảnh đã gửi.'))
        : _entries.isEmpty
        ? const Center(
            child: Text('Chưa có ảnh nào được gửi trên thiết bị này.'),
          )
        : ListView.builder(
            itemCount: _entries.length,
            itemBuilder: (context, index) {
              final entry = _entries[index];
              return ListTile(
                title: const Text('Ảnh đã gửi cho chuyên gia'),
                subtitle: Text(entry['submitted_at']?.toString() ?? ''),
                trailing: TextButton(
                  onPressed: _busy ? null : () => _revoke(entry),
                  child: const Text('Rút lại đồng ý'),
                ),
              );
            },
          ),
  );
}
