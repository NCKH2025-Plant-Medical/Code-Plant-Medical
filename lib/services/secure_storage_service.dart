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

  // ── Public API ───────────────────────────────────────────────────────────

  /// Persist [token] in secure storage.
  Future<void> saveToken(String token) async {
    await _storage.write(key: _keyJwt, value: token);
  }

  /// Return the stored JWT, or `null` if none exists.
  ///
  /// On a corrupted/unreadable entry the storage is cleared and `null`
  /// is returned so the user can simply log in again.
  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _keyJwt);
    } catch (_) {
      // Defensive: wipe storage to avoid permanent lock-out.
      await deleteToken();
      return null;
    }
  }

  /// Remove the stored JWT (on logout or token invalidation).
  Future<void> deleteToken() async {
    await _storage.delete(key: _keyJwt);
  }

  /// Convenience check — avoids exposing null semantics to callers.
  Future<bool> hasToken() async => (await readToken()) != null;
}
