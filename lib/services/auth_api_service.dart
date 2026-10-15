import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:thunghiem1/config/app_config.dart';

// â”€â”€ Custom exception â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Carries the HTTP [statusCode] alongside a human-readable [message]
/// so the UI can display the right feedback and the controller can
/// branch on specific codes (e.g., 401 vs 400).
class AuthException implements Exception {
  const AuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

// â”€â”€ Service â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Pure HTTP client for the Plant Vision `/api/auth/` endpoints.
///
/// This class has *no* state â€” it only makes requests and returns data.
/// Storing tokens and managing auth state is the responsibility of
/// [SecureStorageService] and [AuthNotifier] respectively.
class AuthApiService {
  // â”€â”€ Singleton â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static final AuthApiService _instance = AuthApiService._();
  factory AuthApiService() => _instance;
  AuthApiService._();

  // â”€â”€ Base URL â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  /// Falls back to the same host already used by [ApiService] for plant data.
  static String get _base => AppConfig.detectUrlLocal;

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Shared request timeout â€” keeps the UX responsive even when the
  /// backend is slow.
  static const _timeout = Duration(seconds: 20);

  /// Central JSON headers shared by all endpoints.
  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Parses the response; throws [AuthException] for non-2xx status codes
  /// with a developer-friendly + user-friendly message.
  String _handleResponse(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    final data = json.decode(body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Convention: backend always returns `{ "access_token": "..." }`.
      final token = data['access_token'] as String?;
      if (token == null || token.isEmpty) {
        throw const AuthException('Server returned an empty token.');
      }
      return token;
    }

    // â”€â”€ Error branch â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // FastAPI validation errors: `{ "detail": "..." }` or
    // `{ "detail": [{ "msg": "..." }] }`.
    String message;
    final detail = data['detail'];
    if (detail is String) {
      message = detail;
    } else if (detail is List && detail.isNotEmpty) {
      message = (detail.first as Map)['msg']?.toString() ?? 'Unknown error';
    } else {
      message = 'Request failed (${response.statusCode}).';
    }

    throw AuthException(message, statusCode: response.statusCode);
  }

  /// GET /api/auth/check-username
  Future<bool> checkUsername(String username) async {
    try {
      final url = Uri.parse('${_base}/api/auth/check-username?username=$username');
      final response = await http.get(url).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['available'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // â”€â”€ Public endpoints â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// `POST /api/auth/login` â€” username + password â†’ JWT.
  ///
  /// Throws [AuthException] on invalid credentials (HTTP 401) or bad request.
  Future<String> login({
    required String username,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_base/api/auth/login'),
          headers: _jsonHeaders,
          body: json.encode({'username': username, 'password': password}),
        )
        .timeout(_timeout);

    return _handleResponse(response);
  }

  /// `POST /api/auth/register` â€” username, phone, password, firebaseIdToken â†’ JWT.
  ///
  /// [firebaseIdToken] is the token obtained after verifying the OTP with
  /// Firebase Phone Auth.
  /// `POST /api/auth/check-phone`
  Future<bool> checkPhone(String phoneNumber) async {
    final response = await http
        .post(
          Uri.parse('$_base/api/auth/check-phone'),
          headers: _jsonHeaders,
          body: json.encode({'phone_number': phoneNumber}),
        )
        .timeout(_timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      return data['exists'] == true;
    }
    return false;
  }

  Future<String> register({
    required String username,
    required String phoneNumber,
    required String password,
    required String firebaseIdToken,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_base/api/auth/register'),
          headers: _jsonHeaders,
          body: json.encode({
            'username': username,
            'phone_number': phoneNumber,
            'password': password,
            'firebase_id_token': firebaseIdToken,
          }),
        )
        .timeout(_timeout);

    return _handleResponse(response);
  }

  /// `POST /api/auth/social` â€” provider name + provider_id â†’ JWT.
  ///
  /// [provider] must be either `"google"` or `"facebook"`.
  Future<String> socialLogin({
    required String provider,
    required String providerId,
    String? name,
    String? avatarUrl,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_base/api/auth/social'),
          headers: _jsonHeaders,
          body: json.encode({
            'provider': provider,
            'provider_id': providerId,
            'name': name,
            'avatar_url': avatarUrl,
          }),
        )
        .timeout(_timeout);

    return _handleResponse(response);
  }

  /// `GET /api/auth/me` â€” Fetches current user profile
  Future<Map<String, dynamic>> getMe(String jwt) async {
    final response = await http.get(
      Uri.parse('$_base/api/auth/me'),
      headers: {
        ..._jsonHeaders,
        'Authorization': 'Bearer $jwt',
      },
    ).timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('KhÃ´ng thá»ƒ láº¥y thÃ´ng tin ngÆ°á»i dÃ¹ng');
    }
  }

  /// `POST /api/auth/logout` â€” tells the backend to invalidate the session.
  ///
  /// A network failure here is non-fatal; the caller should still clear
  /// local storage regardless.
  Future<void> logout(String jwt) async {
    try {
      await http
          .post(
            Uri.parse('$_base/api/auth/logout'),
            headers: {
              ..._jsonHeaders,
              'Authorization': 'Bearer $jwt',
            },
          )
          .timeout(_timeout);
    } catch (_) {
      // Best-effort: if the network call fails, local logout still proceeds.
    }
  }

  /// `POST /api/auth/reset-password` â€” phone, firebaseIdToken, newPassword.
  ///
  /// Throws [AuthException] on failure.
  Future<void> resetPassword({
    required String phoneNumber,
    required String firebaseIdToken,
    required String newPassword,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_base/api/auth/reset-password'),
          headers: _jsonHeaders,
          body: json.encode({
            'phone_number': phoneNumber,
            'firebase_id_token': firebaseIdToken,
            'new_password': newPassword,
          }),
        )
        .timeout(_timeout);

    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = json.decode(body);
      final detail = data['detail'];
      final msg = detail is String
          ? detail
          : 'Password reset failed (${response.statusCode}).';
      throw AuthException(msg, statusCode: response.statusCode);
    }
  }
}

