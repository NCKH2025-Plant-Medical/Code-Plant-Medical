import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thunghiem1/services/api_service.dart';

class ReviewFeedbackService {
  static String _key(String userId) => 'review_feedback_revocations_v2_$userId';

  static Future<bool> askAndSubmit(
    BuildContext context, {
    required String imagePath,
    required Map<String, dynamic> prediction,
    required String source,
    required String userId,
  }) async {
    final token = prediction['feedback_token']?.toString();
    if (token == null || token.isEmpty) return false;
    final consent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gửi ảnh để cải thiện AI?'),
        content: const Text(
          'Nếu đồng ý, ảnh này sẽ được lưu tối đa 180 ngày để chuyên gia '
          'xem và gắn nhãn, sau đó có thể dùng để cải thiện mô hình. '
          'Ảnh được loại thông tin EXIF/GPS trong hệ thống admin. '
          'Bạn có thể rút lại đồng ý trong Hồ sơ cá nhân → Ảnh đã gửi để cải thiện AI.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không gửi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đồng ý và gửi'),
          ),
        ],
      ),
    );
    if (consent != true) return false;
    final response = await ApiService().submitPredictionFeedback(
      imagePath: imagePath,
      feedbackToken: token,
      source: source,
    );
    final prefs = await SharedPreferences.getInstance();
    final entries = await savedEntries(userId);
    final id = response['prediction_id'].toString();
    entries.removeWhere((entry) => entry['prediction_id'] == id);
    entries.add({
      'prediction_id': id,
      'revocation_token': response['revocation_token'].toString(),
      'submitted_at': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_key(userId), jsonEncode(entries));
    return true;
  }

  static Future<List<Map<String, dynamic>>> savedEntries(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> revoke(
    String userId,
    String predictionId,
    String token,
  ) async {
    await ApiService().revokePredictionFeedback(token);
    final prefs = await SharedPreferences.getInstance();
    final entries = await savedEntries(userId);
    entries.removeWhere((entry) => entry['prediction_id'] == predictionId);
    await prefs.setString(_key(userId), jsonEncode(entries));
  }
}
