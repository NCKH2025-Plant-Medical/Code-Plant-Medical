import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:thunghiem1/config/app_config.dart';

/// Service for sending user app feedback to backend.
class AppFeedbackService {
  /// Submit user feedback. Returns true on success, false on error.
  static Future<bool> sendFeedback({
    required int rating,
    required String feedbackType,
    required String content,
    String? userId,
    String? contactEmail,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.adminBridgeUrl}/api/v1/app-feedback',
      );

      final body = <String, dynamic>{
        'rating': rating,
        'feedback_type': feedbackType,
        'content': content.trim(),
        if (userId != null) 'user_id': userId,
        if (contactEmail != null) 'contact_email': contactEmail.trim(),
      };

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
