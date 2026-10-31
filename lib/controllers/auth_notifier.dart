import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thunghiem1/config/app_config.dart';
import 'package:thunghiem1/config/social_auth_config.dart';
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
  final FirebaseAuth? _firebaseAuth;

  FirebaseAuth get _auth => _firebaseAuth ?? FirebaseAuth.instance;

  // ── Constructor ───────────────────────────────────────────────────────────
  AuthNotifier({
    AuthApiService? api,
    SecureStorageService? storage,
    FirebaseAuth? firebaseAuth,
  }) : _api = api ?? AuthApiService(),
       _storage = storage ?? SecureStorageService(),
       _firebaseAuth = firebaseAuth;

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

  /// ID ổn định của tài khoản hiện tại — dùng làm khoá phân tách dữ liệu
  /// (ví dụ lịch sử chat) cho từng account riêng lẻ.
  ///
  /// Lấy từ claim `sub` của JWT (giải mã cục bộ, không cần gọi mạng).
  /// Nếu JWT không có `sub` thì fallback về `username` / `id` trong profile.
  /// Trả về `null` khi chưa đăng nhập.
  String? get userId {
    if (!_isAuthenticated || _jwt == null) return null;

    final claim = _decodeJwtSubject(_jwt!);
    if (claim != null && claim.isNotEmpty) return claim;

    final profile = _userProfile;
    final fallback =
        profile?['username']?.toString() ??
        profile?['id']?.toString() ??
        profile?['user_id']?.toString();
    if (fallback != null && fallback.trim().isNotEmpty) return fallback.trim();

    // Cuối cùng: dùng hash ổn định của token làm khoá phân tách. Token là
    // duy nhất theo từng phiên đăng nhập nên vẫn đảm bảo không lẫn sang
    // account khác, và tốt hơn việc rơi về id ẩn danh dùng chung cho mọi khách.
    return 'jwt_${_stableHash(_jwt!)}';
  }

  /// Hash FNV-1a 64-bit — cho kết quả ổn định giữa các lần chạy app.
  ///
  /// Dùng để tạo khoá phân tách cục bộ; KHÔNG phải cơ chế bảo mật.
  static String _stableHash(String input) {
    var hash = 0xcbf29ce484222325;
    for (final byte in input.codeUnits) {
      hash ^= byte & 0xff;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  /// Giải mã payload JWT (phần giữa) để lấy claim `sub`.
  ///
  /// Trả về `null` nếu token không hợp lệ hoặc không có claim `sub`.
  /// Đây là thao tác đọc-only, không xác thực chữ ký — chỉ dùng để gắn
  /// dữ liệu cục bộ theo account, server vẫn là nơi xác thực thật sự.
  static String? _decodeJwtSubject(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;

      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      // Padding base64Url.
      switch (payload.length % 4) {
        case 2:
          payload += '==';
        case 3:
          payload += '=';
        case 1:
          return null;
      }

      final decoded = utf8.decode(base64.decode(payload));
      final data = json.decode(decoded);
      if (data is Map) {
        final sub = data['sub'];
        if (sub != null && sub.toString().trim().isNotEmpty) {
          return sub.toString().trim();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Tên hiển thị người dùng đã tuỳ chỉnh (lưu cục bộ).
  /// Ưu tiên hơn `username` trả về từ backend.
  String? _customDisplayName;
  String? get customDisplayName => _customDisplayName;

  static const String _keyDisplayName = 'plant_vision_display_name';

  /// Tên hiển thị cuối cùng dùng cho UI.
  /// Thứ tự ưu tiên: tên tuỳ chỉnh → tên từ Google/Facebook → username → SĐT.
  String get displayName {
    final custom = _customDisplayName;
    if (custom != null && custom.trim().isNotEmpty) return custom.trim();

    final socialName = _userProfile?['display_name']?.toString();
    if (socialName != null && socialName.trim().isNotEmpty) {
      return socialName.trim();
    }

    final profileName = _userProfile?['username']?.toString();
    if (profileName != null && profileName.trim().isNotEmpty) {
      return profileName.trim();
    }

    final phone = _userProfile?['phone_number']?.toString();
    if (phone != null && phone.trim().isNotEmpty) return phone.trim();

    return 'Người dùng';
  }

  /// Ảnh đại diện (nếu có) từ backend hoặc Google/Facebook.
  String? get avatarUrl {
    final url = _userProfile?['avatar_url']?.toString();
    if (url != null && url.trim().isNotEmpty) return url;
    return null;
  }

  /// Đổi tên hiển thị người dùng.
  ///
  /// Lưu cục bộ ngay (để UI cập nhật tức thì) và cố gắng đồng bộ lên
  /// backend. Nếu backend không hỗ trợ thì tên vẫn được giữ trên thiết bị.
  Future<bool> updateDisplayName(String newName) async {
    final name = newName.trim();
    if (name.isEmpty) {
      _setError('Tên người dùng không được để trống.');
      return false;
    }
    if (name.length > 50) {
      _setError('Tên người dùng không được vượt quá 50 ký tự.');
      return false;
    }

    _customDisplayName = name;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDisplayName, name);
    } catch (_) {}

    // Đồng bộ backend (best-effort — không chặn UI nếu thất bại).
    if (_jwt != null) {
      try {
        final updated = await _api.updateMe(_jwt!, name: name);
        if (updated.isNotEmpty) {
          _userProfile = {...?_userProfile, ...updated};
        }
      } catch (_) {}
    }

    _status = AuthStatus.idle;
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  // ── Firebase phone-auth state (used across OTP screens) ──────────────────

  /// The verification ID returned by [sendOtp]; passed to [verifyOtp].
  String? _verificationId;

  /// `true` once [init] has finished reading secure storage.
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  final Completer<void> _readyCompleter = Completer<void>();

  /// Future hoàn tất khi [init] chạy xong — dùng để tránh đọc
  /// [isAuthenticated] quá sớm.
  Future<void> get ready => _readyCompleter.future;

  // ── Initialization ────────────────────────────────────────────────────────

  /// Called once from [MultiProvider] / app startup.
  ///
  /// Reads secure storage; if a token exists we consider the user
  /// authenticated without making a network call (offline-first).
  Future<void> init() async {
    _jwt = await _storage.readToken();
    _isAuthenticated = _jwt != null;

    // Khởi tạo Google Sign-In với serverClientId (web client).
    // Trên Android, nếu không truyền serverClientId, plugin sẽ tự đọc
    // google-services.json — nhưng chỉ hoạt động khi file có oauth_client
    // client_type=3 VÀ app đã được đăng ký đúng SHA-1.
    try {
      await GoogleSignIn.instance.initialize(
        clientId: SocialAuthConfig.googleIosClientId.isEmpty
            ? null
            : SocialAuthConfig.googleIosClientId,
        serverClientId: SocialAuthConfig.hasGoogleServerClientId
            ? SocialAuthConfig.googleServerClientId
            : null,
      );
    } catch (e) {
      debugPrint('[GoogleSignIn] initialize failed: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _customDisplayName = prefs.getString(_keyDisplayName);
    } catch (_) {}
    if (_isAuthenticated && _jwt != null) {
      try {
        _userProfile = await _api.getMe(_jwt!);
      } catch (_) {}
    }
    _isInitialized = true;
    if (!_readyCompleter.isCompleted) _readyCompleter.complete();
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
  ///
  /// [fallbackName] / [fallbackAvatar] là tên và ảnh lấy từ Google/Facebook,
  /// dùng khi backend không trả về `username` / `avatar_url`.
  Future<void> _persistToken(
    String token, {
    String? fallbackName,
    String? fallbackAvatar,
  }) async {
    await _storage.saveToken(token);
    _jwt = token;
    _isAuthenticated = true;
    try {
      _userProfile = await _api.getMe(token);
    } catch (_) {}

    // Bổ sung tên/ảnh từ nhà cung cấp mạng xã hội nếu backend thiếu.
    final profile = _userProfile ?? <String, dynamic>{};
    final hasName =
        (profile['username']?.toString().trim().isNotEmpty) ?? false;
    final hasDisplayName =
        (profile['display_name']?.toString().trim().isNotEmpty) ?? false;
    final hasAvatar =
        (profile['avatar_url']?.toString().trim().isNotEmpty) ?? false;
    if ((!hasName && fallbackName != null) ||
        (!hasDisplayName && fallbackName != null) ||
        (!hasAvatar && fallbackAvatar != null)) {
      _userProfile = {
        ...profile,
        if (!hasName && fallbackName != null) 'username': fallbackName,
        // Lưu riêng tên hiển thị lấy từ Google/Facebook
        if (!hasDisplayName && fallbackName != null)
          'display_name': fallbackName,
        if (!hasAvatar && fallbackAvatar != null) 'avatar_url': fallbackAvatar,
      };
    }
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
    } catch (e) {
      debugPrint('[Auth] login network error: $e');
      _setError(
        'Không thể kết nối máy chủ. Vui lòng thử lại.\n'
        '(${AppConfig.authUrl})',
      );
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
      await _auth.setSettings(appVerificationDisabledForTesting: true);
    }

    // ⚠️  Do NOT await verifyPhoneNumber — it always returns void immediately.
    _auth.verifyPhoneNumber(
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
        _setError(
          'Hệ thống bị treo (thường gặp trên máy ảo). Vui lòng thử trên máy thật hoặc kiểm tra cấu hình Firebase SHA-1.',
        );
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
      final result = await _auth.signInWithCredential(credential);
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
  /// Thứ tự thử:
  /// 1. Google Sign-In native (nhanh, không cần trình duyệt).
  /// 2. Nếu lỗi cấu hình (thiếu SHA-1 / serverClientId) → fallback sang
  ///    Firebase OAuth qua trình duyệt, không phụ thuộc SHA-1.
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
        name: googleUser.displayName,
        avatarUrl: googleUser.photoUrl,
      );
      await _persistToken(
        token,
        fallbackName: googleUser.displayName,
        fallbackAvatar: googleUser.photoUrl,
      );
      _setStatus(AuthStatus.success);
      return true;
    } on GoogleSignInException catch (e) {
      debugPrint('[GoogleSignIn] code=${e.code} description=${e.description}');
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted ||
          e.code == GoogleSignInExceptionCode.uiUnavailable) {
        // Người dùng đóng hộp thoại → không hiện lỗi.
        _setStatus(AuthStatus.idle);
        return false;
      }
      // Lỗi cấu hình → thử luồng OAuth qua trình duyệt của Firebase.
      if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError ||
          e.code == GoogleSignInExceptionCode.unknownError) {
        debugPrint('[GoogleSignIn] falling back to Firebase OAuth web flow');
        return _signInWithGoogleViaFirebase();
      }
      _setError(_mapGoogleSignInError(e));
      return false;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      debugPrint('[GoogleSignIn] unexpected error: $e');
      return _signInWithGoogleViaFirebase();
    }
  }

  /// Luồng dự phòng: đăng nhập Google qua Firebase `signInWithProvider`
  /// (mở trình duyệt / Custom Tab). Không cần SHA-1 của keystore.
  Future<bool> _signInWithGoogleViaFirebase() async {
    try {
      final credential = await _auth.signInWithProvider(GoogleAuthProvider());
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        _setError('Không lấy được thông tin tài khoản Google.');
        return false;
      }

      final providerId = firebaseUser.providerData.isNotEmpty
          ? (firebaseUser.providerData.first.uid ?? firebaseUser.uid)
          : firebaseUser.uid;

      final token = await _api.socialLogin(
        provider: 'google',
        providerId: providerId,
        name: firebaseUser.displayName,
        avatarUrl: firebaseUser.photoURL,
      );
      await _persistToken(
        token,
        fallbackName: firebaseUser.displayName,
        fallbackAvatar: firebaseUser.photoURL,
      );
      _setStatus(AuthStatus.success);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('[GoogleOAuth] code=${e.code} message=${e.message}');
      if (e.code == 'web-context-canceled' ||
          e.code == 'cancelled' ||
          e.code == 'canceled') {
        _setStatus(AuthStatus.idle);
        return false;
      }
      _setError(
        'Đăng nhập Google thất bại (${e.code}).\n'
        '${e.message ?? 'Vui lòng thử lại.'}',
      );
      return false;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      debugPrint('[GoogleOAuth] unexpected error: $e');
      _setError(
        'Không thể đăng nhập Google. Vui lòng kiểm tra kết nối mạng '
        'hoặc dùng email/mật khẩu.',
      );
      return false;
    }
  }

  /// Chuyển [GoogleSignInException] thành thông báo tiếng Việt dễ hiểu.
  String _mapGoogleSignInError(GoogleSignInException e) {
    final desc = e.description ?? '';
    final detail = desc.isEmpty ? '' : '\n($desc)';
    if (desc.contains('serverClientId')) {
      return 'Thiếu cấu hình Google (serverClientId). '
          'Kiểm tra google-services.json có oauth_client client_type=3.$detail';
    }
    switch (e.code) {
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'Cấu hình Google chưa đúng: chưa thêm SHA-1 của keystore vào '
            'Firebase Console, hoặc package name không khớp.$detail';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google Sign-In chưa được bật cho app này trên Firebase.$detail';
      case GoogleSignInExceptionCode.unknownError:
        return 'Lỗi xác thực Google (${e.code.name}).$detail';
      default:
        return 'Đăng nhập Google thất bại (${e.code.name}).$detail';
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
        // NATIVE_WITH_FALLBACK: ưu tiên app Facebook, nếu không có thì
        // tự chuyển sang hộp thoại web.
        loginBehavior: LoginBehavior.nativeWithFallback,
      );

      // User cancelled
      if (loginResult.status == LoginStatus.cancelled) {
        _setStatus(AuthStatus.idle);
        return false;
      }

      if (loginResult.status != LoginStatus.success) {
        final msg = loginResult.message ?? '';
        debugPrint('[FacebookAuth] status=${loginResult.status} msg=$msg');
        if (msg.contains('not available') ||
            msg.contains('not installed') ||
            msg.contains('not supported')) {
          _setError(
            'Không mở được Facebook trên thiết bị này. '
            'Vui lòng thử đăng nhập bằng Google hoặc tài khoản thường.',
          );
        } else {
          _setError(
            'Đăng nhập Facebook thất bại: $msg\n'
            'Kiểm tra Facebook App đã ở chế độ Live và tài khoản của bạn '
            'có quyền truy cập app chưa.',
          );
        }
        return false;
      }
      // Lấy id + tên + ảnh đại diện của người dùng Facebook
      final userData = await FacebookAuth.instance.getUserData(
        fields: 'id,name,picture',
      );
      final providerId = userData['id'] as String?;
      if (providerId == null) {
        throw Exception('Không lấy được Facebook user ID.');
      }

      final fbName = userData['name'] as String?;
      final picture = userData['picture'];
      String? fbAvatar;
      if (picture is Map) {
        final data = picture['data'];
        if (data is Map) fbAvatar = data['url'] as String?;
      }

      final token = await _api.socialLogin(
        provider: 'facebook',
        providerId: providerId,
        name: fbName,
        avatarUrl: fbAvatar,
      );
      await _persistToken(
        token,
        fallbackName: fbName,
        fallbackAvatar: fbAvatar,
      );
      _setStatus(AuthStatus.success);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      debugPrint('[FacebookAuth] unexpected error: $e');
      _setError('Đăng nhập Facebook thất bại. Vui lòng thử lại.');
      return false;
    }
  }

  /// Luồng dự phòng cho Facebook: dùng Firebase `signInWithProvider`
  /// (FacebookAuthProvider) — hữu ích khi SDK Facebook native lỗi.
  ///
  /// Yêu cầu: bật provider Facebook trong Firebase Console với App ID /
  /// App Secret trùng app Facebook đang dùng.
  Future<bool> signInWithFacebookViaFirebase() async {
    _setStatus(AuthStatus.loading);
    try {
      final credential = await _auth.signInWithProvider(FacebookAuthProvider());
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        _setError('Không lấy được thông tin tài khoản Facebook.');
        return false;
      }

      final providerId = firebaseUser.providerData.isNotEmpty
          ? (firebaseUser.providerData.first.uid ?? firebaseUser.uid)
          : firebaseUser.uid;

      final token = await _api.socialLogin(
        provider: 'facebook',
        providerId: providerId,
        name: firebaseUser.displayName,
        avatarUrl: firebaseUser.photoURL,
      );
      await _persistToken(
        token,
        fallbackName: firebaseUser.displayName,
        fallbackAvatar: firebaseUser.photoURL,
      );
      _setStatus(AuthStatus.success);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('[FacebookOAuth] code=${e.code} message=${e.message}');
      if (e.code == 'web-context-canceled' ||
          e.code == 'cancelled' ||
          e.code == 'canceled') {
        _setStatus(AuthStatus.idle);
        return false;
      }
      _setError(
        'Đăng nhập Facebook thất bại (${e.code}).\n'
        '${e.message ?? 'Vui lòng thử lại.'}',
      );
      return false;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      debugPrint('[FacebookOAuth] unexpected error: $e');
      _setError('Không thể đăng nhập Facebook. Vui lòng thử lại sau.');
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
    try {
      await _auth.signOut();
    } catch (_) {}

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
    _userProfile = null;
    _customDisplayName = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyDisplayName);
    } catch (_) {}

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
