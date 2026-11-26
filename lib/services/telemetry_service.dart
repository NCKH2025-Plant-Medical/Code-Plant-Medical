import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:thunghiem1/config/app_config.dart';

/// Lightweight crash / exception telemetry service.
///
/// All methods are fire-and-forget – they catch every exception silently
/// so that telemetry never breaks the app.
class TelemetryService {
  static const String _appVersion = '1.0.0';

  /// Send an error report to the backend telemetry endpoint.
  ///
  /// [errorType]  – classifier (e.g. 'FlutterError', 'UnhandledError').
  /// [message]    – human-readable error message (truncated to 2 000 chars).
  /// [stackTrace] – full stack trace string (truncated to 10 000 chars).
  /// [screen]     – optional screen name where the error occurred.
  /// [userId]     – optional authenticated user ID.
  static Future<void> sendError(
    String errorType,
    String message,
    String stackTrace, {
    String? screen,
    String? userId,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.adminBridgeUrl}/api/v1/telemetry/errors',
      );

      final body = <String, dynamic>{
        'error_type': errorType,
        'message': message.length > 2000 ? message.substring(0, 2000) : message,
        'stack_trace': stackTrace.length > 10000
            ? stackTrace.substring(0, 10000)
            : stackTrace,
        'screen': screen,
        'device_model': 'unknown',
        'os_version': Platform.operatingSystem,
        'app_version': _appVersion,
        if (userId != null) 'user_id': userId,
      };

      await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Telemetry must never throw.
    }
  }
}
