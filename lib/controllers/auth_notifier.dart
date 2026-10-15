import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:thunghiem1/services/auth_api_service.dart';
import 'package:thunghiem1/services/secure_storage_service.dart';

// ── Auth status enum ──────────────────────────────────────────────────────────

/// Represents the granular state of an in-progress auth operation.
/// The UI uses this to show a spinner, an error, or navigate away.
enum AuthStatus {
  /// No operation running; app is in its stable resting state.
  idle,

  /// An async operation (login, register, OTP send, etc.) is in progress.
  loading,

  /// The last operation succeeded.
  success,

  /// The last operation failed — see [AuthNotifier.errorMessage].
  error,
}

// ── AuthNotifier ──────────────────────────────────────────────────────────────

/// Central auth state manager (ChangeNotifier).
///
/// Responsibilities:
/// 1. On startup: checks [SecureStorageService] for an existing JWT and sets
///    [isAuthenticated] accordingly — **no redirect, no forced login**.
/// 2. Exposes methods wrapping every [AuthApiService] endpoint.
/// 3. Orchestrates Firebase Phone Auth OTP flow.
/// 4. Orchestrates Google & Facebook social sign-in SDKs.
///
/// All mutations go through [_setStatus] / [_setError] so rebuilds are
/// batched and traceable.
class AuthNotifier extends ChangeNotifier {
  // ── Dependencies ──────────────────────────────────────────────────────────
  final AuthApiService _api;
  final SecureStorageService _storage;
  final FirebaseAuth _firebaseAuth;

  // ── Constructor ───────────────────────────────────────────────────────────
  AuthNotifier({
    AuthApiService? api,
    SecureStorageService? storage,
    FirebaseAuth? firebaseAuth,
  })  : _api = api ?? AuthApiService(),
        _storage = storage ?? SecureStorageService(),
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  // ── State ─────────────────────────────────────────────────────────────────

  /// `true` when a valid JWT exists in secure storage.
  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  /// The JWT currently held by the app.  Null when logged out.
  String? _jwt;
  String? get jwt => _jwt;

  /// Current operation status — drive loading indicators and SnackBars.
  AuthStatus _status = AuthStatus.idle;
  AuthStatus get status => _status;

  /// Human-readable error message from the last failed operation.
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Profile data from `/api/auth/me`.
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? get userProfile => _userProfile;

  // ── Firebase phone-auth state (used across OTP screens) ──────────────────

  /// The verification ID returned by [sendOtp]; passed to [verifyOtp].
  String? _verificationId;

  // ── Initialization ────────────────────────────────────────────────────────

  /// Called once from [MultiProvider] / app startup.
  ///
  /// Reads secure storage; if a token exists we consider the user
  /// authenticated without making a network call (offline-first).
  Future<void> init() async {
    _jwt = await _storage.readToken();
    _isAuthenticated = _jwt != null;
    try {
      await GoogleSignIn.instance.initialize();
    } catch (_) {}
    if (_isAuthenticated && _jwt != null) {
      try {
        _userProfile = await _api.getMe(_jwt!);
      } catch (_) {}
    }
    notifyListeners();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _setStatus(AuthStatus status) {
    _status = status;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = AuthStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  /// Persists [token] and flips the authenticated flag.
  Future<void> _persistToken(String token) async {
    await _storage.saveToken(token);
    _jwt = token;
    _isAuthenticated = true;
    try {
      _userProfile = await _api.getMe(token);
    } catch (_) {}
  }

  // ── Public Auth Methods ───────────────────────────────────────────────────

  // ── 1. Login ──────────────────────────────────────────────────────────────

  Future<bool> checkUsername(String username) async {
    return await _api.checkUsername(username);
  }

  /// Authenticates with [username] + [password] against the FastAPI backend.
  ///
  /// Returns `true` on success so the UI can trigger navigation.
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _setStatus(AuthStatus.loading);
    try {
      final token = await _api.login(username: username, password: password);
      await _persistToken(token);
      _setStatus(AuthStatus.success);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Không thể kết nối máy chủ. Vui lòng thử lại.');
      return false;
    }
  }

  // ── 2. Register (with OTP) ────────────────────────────────────────────────

  /// The phone number currently awaiting OTP verification.
  /// Displayed on the OTP screen so the user knows where the SMS was sent.
  String? _pendingPhone;
  String? get pendingPhone => _pendingPhone;

  /// Resend token returned by Firebase — allows re-triggering SMS without
  /// consuming a new slot (rate-limit friendly).
  int? _resendToken;

  /// Step 1 of registration / password-reset: sends an OTP via Firebase.
  ///
  /// **Design note:** [FirebaseAuth.verifyPhoneNumber] fires callbacks
  /// asynchronously — it does NOT return a Future. We bridge it to one
  /// using [_OtpCompleter]: the completer's future is awaited *after*
  /// [verifyPhoneNumber] returns so the callbacks can resolve it.
  ///
  /// Returns `true` if the SMS was dispatched (i.e., [codeSent] fired).
  bool _isRegistering = true;

  Future<bool> sendOtp(String phoneNumber, {bool isRegister = true}) async {
    _setStatus(AuthStatus.loading);
    _isRegistering = isRegister;

    try {
      final exists = await _api.checkPhone(phoneNumber);
      if (isRegister && exists) {
        _setError('Số điện thoại này đã được đăng ký.');
        return false;
      } else if (!isRegister && !exists) {
        _setError('Số điện thoại này chưa được đăng ký.');
        return false;
      }
    } catch (e) {
      // Bỏ qua nếu lỗi mạng để Firebase lo phần gửi OTP.
    }

    _pendingPhone = phoneNumber;
    final completer = _OtpCompleter();

    if (kDebugMode) {
      await _firebaseAuth.setSettings(appVerificationDisabledForTesting: true);
    }

    // ⚠️  Do NOT await verifyPhoneNumber — it always returns void immediately.
    _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: _resendToken, // null on first call
      timeout: const Duration(seconds: 60),

      // ── Android auto-read ───────────────────────────────────────────────
      // Fires when the device auto-reads the SMS and authenticates without
      // user input. We still complete the completer so sendOtp() returns.
      verificationCompleted: (PhoneAuthCredential credential) {
        debugPrint('[PhoneAuth] Auto-verified — credential ready.');
        completer.complete();
      },

      // ── Delivery failure ────────────────────────────────────────────────
      verificationFailed: (FirebaseAuthException e) {
        final msg = _mapPhoneAuthError(e);
        completer.completeError(msg);
      },

      // ── SMS dispatched ──────────────────────────────────────────────────
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken; // cache for resend
        completer.complete();
      },

      codeAutoRetrievalTimeout: (_) {
        // Timeout is handled gracefully; the user can still type the code.
      },
    );

    // Now await — the callbacks above will resolve or reject this.
    try {
      await completer.future.timeout(const Duration(seconds: 15));
      _setStatus(AuthStatus.idle);
      return true;
    } catch (e) {
      if (e is TimeoutException) {
         _setError('Hệ thống bị treo (thường gặp trên máy ảo). Vui lòng thử trên máy thật hoặc kiểm tra cấu hình Firebase SHA-1.');
      } else {
         _setError(e.toString());
      }
      _setStatus(AuthStatus.idle);
      return false;
    }
  }

  /// Resend OTP to [pendingPhone] using the cached resend token.
  /// Callers should check [pendingPhone] != null before calling.
  Future<bool> resendOtp() async {
    if (_pendingPhone == null) return false;
    _resendToken = null; // clear to force fresh send if needed
    return sendOtp(_pendingPhone!, isRegister: _isRegistering);
  }

  /// Maps [FirebaseAuthException] error codes to user-facing Vietnamese messages.
  String _mapPhoneAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Số điện thoại không hợp lệ.';
      case 'too-many-requests':
        return 'Quá nhiều yêu cầu. Vui lòng thử lại sau.';
      case 'quota-exceeded':
        return 'Hạn mức SMS đã hết. Vui lòng liên hệ hỗ trợ.';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng. Vui lòng kiểm tra internet.';
      default:
        return e.message ?? 'Gửi OTP thất bại. Vui lòng thử lại.';
    }
  }

  /// Step 2 of registration: verifies the [otpCode] with Firebase and
  /// retrieves the `firebase_id_token` needed by the backend.
  ///
  /// Returns the id-token string on success, or `null` on failure.
  Future<String?> verifyOtp(String otpCode) async {
    if (_verificationId == null) {
      _setError('OTP session expired. Please request a new code.');
      return null;
    }
    _setStatus(AuthStatus.loading);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otpCode,
      );
      final result = await _firebaseAuth.signInWithCredential(credential);
      final idToken = await result.user?.getIdToken();
      if (idToken == null) throw Exception('Could not retrieve id token.');
      _setStatus(AuthStatus.idle);
      return idToken;
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'Invalid OTP code.');
      return null;
    } catch (e) {
      _setError('OTP verification failed. Please try again.');
      return null;
    }
  }

  /// Step 3 of registration: calls the backend register endpoint with
  /// the [firebaseIdToken] obtained from [verifyOtp].
  ///
  /// Returns `true` on success.
  Future<bool> register({
    required String username,
    required String phoneNumber,
    required String password,
    required String firebaseIdToken,
  }) async {
    _setStatus(AuthStatus.loading);
    try {
      final token = await _api.register(
        username: username,
        phoneNumber: phoneNumber,
        password: password,
        firebaseIdToken: firebaseIdToken,
      );
      await _persistToken(token);
      _setStatus(AuthStatus.success);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Registration failed. Please try again.');
      return false;
    }
  }

  /// Initiates the Google Sign-In flow and forwards the provider_id to
  /// the backend.
  ///
  /// Returns `true` on success.
  Future<bool> signInWithGoogle() async {
    _setStatus(AuthStatus.loading);
    try {
      // Trigger the sign-in flow (google_sign_in v7 singleton)
      final googleUser = await GoogleSignIn.instance.authenticate();

      final token = await _api.socialLogin(
        provider: 'google',
        providerId: googleUser.id,
      );
      await _persistToken(token);
      _setStatus(AuthStatus.success);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      // User closed the dialog or network error — don't crash
      final msg = e.toString();
      if (msg.contains('sign_in_canceled') || msg.contains('cancelled')) {
        _setStatus(AuthStatus.idle);
        return false;
      }
      _setError('Đăng nhập Google thất bại. Vui lòng thử lại.');
      return false;
    }
  }

  /// Initiates the Facebook Login flow and forwards the provider_id.
  ///
  /// Returns `true` on success.
  Future<bool> signInWithFacebook() async {
    _setStatus(AuthStatus.loading);
    try {
      final loginResult = await FacebookAuth.instance.login(
        permissions: ['public_profile'],
      );

      // User cancelled
      if (loginResult.status == LoginStatus.cancelled) {
        _setStatus(AuthStatus.idle);
        return false;
      }

      if (loginResult.status != LoginStatus.success) {
        _setError('Đăng nhập Facebook thất bại: ${loginResult.message}');
        return false;
      }

      final userData = await FacebookAuth.instance.getUserData(fields: 'id');
      final providerId = userData['id'] as String?;
      if (providerId == null) throw Exception('Không lấy được Facebook user ID.');

      final token = await _api.socialLogin(
        provider: 'facebook',
        providerId: providerId,
      );
      await _persistToken(token);
      _setStatus(AuthStatus.success);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Đăng nhập Facebook thất bại. Vui lòng thử lại.');
      return false;
    }
  }

  // ── 4. Logout ─────────────────────────────────────────────────────────────

  /// Notifies backend, clears secure storage, and resets local state.
  Future<void> logout() async {
    _setStatus(AuthStatus.loading);

    // Best-effort backend call — does not block local logout.
    if (_jwt != null) await _api.logout(_jwt!);

    // Firebase sign out (clears any Firebase session).
    await _firebaseAuth.signOut();

    // Sign out from social providers (clears their cached sessions).
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}

    // Clear local state.
    await _storage.deleteToken();
    _jwt = null;
    _isAuthenticated = false;
    _verificationId = null;
    _pendingPhone = null;
    _resendToken = null;

    _setStatus(AuthStatus.idle);
  }

  // ── 5. Forgot Password ────────────────────────────────────────────────────

  /// Convenience wrapper that reuses [sendOtp] for the forgot-password flow.
  /// Semantics are identical; the OTP is used by [resetPassword] instead.
  Future<bool> sendResetOtp(String phoneNumber) {
    _isRegistering = false; // track for resend
    return sendOtp(phoneNumber, isRegister: false);
  }

  /// Resets the password on the backend using the provided [firebaseIdToken].
  ///
  /// Returns `true` on success.
  Future<bool> resetPassword({
    required String firebaseIdToken,
    required String phoneNumber,
    required String newPassword,
  }) async {
    _setStatus(AuthStatus.loading);
    try {
      await _api.resetPassword(
        phoneNumber: phoneNumber,
        firebaseIdToken: firebaseIdToken,
        newPassword: newPassword,
      );
      _setStatus(AuthStatus.success);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Password reset failed. Please try again.');
      return false;
    }
  }

  /// Clears any stale error so the next UI rebuild shows a clean state.
  void clearError() {
    if (_status == AuthStatus.error) {
      _status = AuthStatus.idle;
      _errorMessage = null;
      notifyListeners();
    }
  }
}

// ── Internal helper ────────────────────────────────────────────────────────────

/// Bridges Firebase's callback-based [FirebaseAuth.verifyPhoneNumber] API
/// to a Future so [sendOtp] can `await` the result cleanly.
class _OtpCompleter {
  final Completer<void> _completer = Completer<void>();
  Future<void> get future => _completer.future;

  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }

  void completeError(Object error) {
    if (!_completer.isCompleted) _completer.completeError(error);
  }
}

