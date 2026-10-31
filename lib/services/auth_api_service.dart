import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:thunghiem1/config/app_config.dart';
import 'package:thunghiem1/services/secure_storage_service.dart';

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
  /// Dùng [AppConfig.authUrl] để có thể trỏ sang server auth riêng bằng
  /// `--dart-define=AUTH_URL=...` mà không phải sửa code.
  static String get _base => _resolvedBase ?? AppConfig.authUrl;

  // ── Auto-discovery ───────────────────────────────────────────────────────
  /// Host đã được xác thực là có router `/api/auth/*` (cache sau lần dò đầu).
  static String? _resolvedBase;

  /// Danh sách host ứng viên, theo thứ tự ưu tiên:
  /// 1. [AppConfig.authUrl] (override được bằng `--dart-define=AUTH_URL=...`).
  /// 2. Các host dự phòng trong [AppConfig.authFallbackUrls] (backend local).
  static List<String> get _candidateBases {
    final list = <String>[];
    void add(String? url) {
      final trimmed = url?.trim() ?? '';
      if (trimmed.isEmpty) return;
      final normalized = trimmed.endsWith('/')
          ? trimmed.substring(0, trimmed.length - 1)
          : trimmed;
      if (!list.contains(normalized)) list.add(normalized);
    }

    add(AppConfig.authUrl);
    for (final url in AppConfig.authFallbackUrls.split(',')) {
      add(url);
    }
    return list;
  }

  /// Dò xem host nao thuc su phuc vu router `/api/auth/*`.
  ///
  /// Server inference-only (`222.255.184.116`) da go router auth va tra
  /// `404 {"detail":"Not Found"}` cho moi path `/api/auth/*`. Khi do app
  /// tu chuyen sang backend local dang chay o may dev neu co.
  static Future<String> resolveBase() async {
    final cached = _resolvedBase;
    if (cached != null) return cached;

    for (final candidate in _candidateBases) {
      if (await _hasAuthRouter(candidate)) {
        debugPrint('[AuthAPI] Dung server auth: $candidate');
        _resolvedBase = candidate;
        return candidate;
      }
      debugPrint('[AuthAPI] $candidate khong co router /api/auth/* (404)');
    }

    // Khong host nao phuc vu auth -> KHONG cache, de lan sau thu lai
    // (backend local co the vua duoc bat them).
    debugPrint(
      '[AuthAPI] Khong tim thay server auth. '
      'Hay bat backend local hoac truyen --dart-define=AUTH_URL=...',
    );
    return AppConfig.authUrl;
  }

  /// Kiem tra nhanh mot host co router `/api/auth/*` hay khong.
  ///
  /// Dung `POST /api/auth/login` voi body rong: neu router ton tai, server
  /// tra `401`/`422` (thieu field); neu khong ton tai -> `404 Not Found`.
  static Future<bool> _hasAuthRouter(String base) async {
    try {
      final response = await http
          .post(
            Uri.parse('$base/api/auth/login'),
            headers: _jsonHeaders,
            body: '{}',
          )
          .timeout(const Duration(seconds: 3));
      return response.statusCode != 404;
    } catch (_) {
      return false;
    }
  }

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
      final refreshToken = data['refresh_token'] as String?;
      if (refreshToken != null && refreshToken.isNotEmpty) {
        SecureStorageService().saveRefreshToken(refreshToken);
      }
      return token;
    }

    // â”€â”€ Error branch â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // FastAPI validation errors: `{ "detail": "..." }` or
    // `{ "detail": [{ "msg": "..." }] }`.
    String message;
    final detail = data['detail'];
    if (response.statusCode == 404) {
      // Server khong co router `/api/auth/*` (ban "Inference-only").
      message =
          'May chu phuc vu khong co API dang nhap (/api/auth/*).\n'
          'Vui long kiem tra lai backend dang chay.';
    } else if (detail is String) {
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
      await resolveBase();
      final url = Uri.parse(
        '$_base/api/auth/check-username?username=$username',
      );
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
    await resolveBase();
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
    await resolveBase();
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
    await resolveBase();
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

  /// `POST /api/auth/social` - provider name + provider_id -> JWT.
  ///
  /// [provider] must be either `"google"` or `"facebook"`.
  ///
  /// Nếu backend chưa hỗ trợ các field `name` / `avatar_url` (trả 422) thì
  /// tự động gọi lại chỉ với `provider` + `provider_id`.
  Future<String> socialLogin({
    required String provider,
    required String providerId,
    String? name,
    String? avatarUrl,
  }) async {
    await resolveBase();
    Future<http.Response> send({required bool withProfile}) {
      return http
          .post(
            Uri.parse('$_base/api/auth/social'),
            headers: _jsonHeaders,
            body: json.encode({
              'provider': provider,
              'provider_id': providerId,
              if (withProfile) 'name': name,
              if (withProfile) 'avatar_url': avatarUrl,
            }),
          )
          .timeout(_timeout);
    }

    var response = await send(withProfile: true);
    if (response.statusCode == 422) {
      // Backend dùng schema chặt (Pydantic) → thử lại không kèm profile.
      response = await send(withProfile: false);
    }
    return _handleResponse(response);
  }

  /// `GET /api/auth/me` â€” Fetches current user profile
  Future<Map<String, dynamic>> getMe(String jwt) async {
    await resolveBase();
    final response = await http
        .get(
          Uri.parse('$_base/api/auth/me'),
          headers: {..._jsonHeaders, 'Authorization': 'Bearer $jwt'},
        )
        .timeout(_timeout);

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
  /// `PATCH /api/auth/me` - Cập nhật thông tin người dùng (hiện tại: tên).
  ///
  /// Trả về dữ liệu profile mới nếu backend hỗ trợ; trả về map rỗng nếu
  /// endpoint chưa tồn tại (khi đó tên vẫn được lưu cục bộ trên thiết bị).
  Future<Map<String, dynamic>> updateMe(String jwt, {String? name}) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$_base/api/auth/me'),
            headers: {..._jsonHeaders, 'Authorization': 'Bearer $jwt'},
            body: json.encode({if (name != null) 'username': name}),
          )
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) return decoded;
        return <String, dynamic>{};
      }
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> logout(String jwt) async {
    try {
      await http
          .post(
            Uri.parse('$_base/api/auth/logout'),
            headers: {..._jsonHeaders, 'Authorization': 'Bearer $jwt'},
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
    await resolveBase();
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

  /// `POST /api/auth/refresh` — Làm mới Access Token bằng Refresh Token.
  Future<String?> refreshToken() async {
    try {
      final refresh = await SecureStorageService().readRefreshToken();
      if (refresh == null) return null;

      await resolveBase();
      final response = await http
          .post(
            Uri.parse('$_base/api/auth/refresh'),
            headers: _jsonHeaders,
            body: json.encode({'refresh_token': refresh}),
          )
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final newAccess = data['access_token'] as String?;
        final newRefresh = data['refresh_token'] as String?;
        if (newAccess != null) {
          await SecureStorageService().saveToken(newAccess);
        }
        if (newRefresh != null) {
          await SecureStorageService().saveRefreshToken(newRefresh);
        }
        return newAccess;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
