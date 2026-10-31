import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists and retrieves the JWT in the platform's secure enclave
/// (Android Keystore / iOS Keychain). All keys are namespaced under
/// [_keyJwt] so callers never touch raw storage strings.
class SecureStorageService {
  // ── Singleton ────────────────────────────────────────────────────────────
  static final SecureStorageService _instance = SecureStorageService._();
  factory SecureStorageService() => _instance;
  SecureStorageService._();

  // ── Storage & key ────────────────────────────────────────────────────────
  /// Android options: use EncryptedSharedPreferences backed by Keystore.
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: _androidOptions,
  );

  static const String _keyJwt = 'plant_vision_jwt';
  static const String _keyRefreshToken = 'plant_vision_refresh_token';

  // ── Public API ───────────────────────────────────────────────────────────

  /// Persist Access Token [token] in secure storage.
  Future<void> saveToken(String token) async {
    await _storage.write(key: _keyJwt, value: token);
  }

  /// Persist Refresh Token [token] in secure storage.
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  /// Return the stored JWT (Access Token), or `null` if none exists.
  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _keyJwt);
    } catch (_) {
      await deleteToken();
      return null;
    }
  }

  /// Return the stored Refresh Token, or `null` if none exists.
  Future<String?> readRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (_) {
      await _storage.delete(key: _keyRefreshToken);
      return null;
    }
  }

  /// Remove stored tokens (on logout or session invalidation).
  Future<void> deleteToken() async {
    await _storage.delete(key: _keyJwt);
    await _storage.delete(key: _keyRefreshToken);
  }

  /// Convenience check — avoids exposing null semantics to callers.
  Future<bool> hasToken() async => (await readToken()) != null;
}
