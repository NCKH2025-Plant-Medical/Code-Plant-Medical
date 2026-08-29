import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart'; // Import thư viện Facebook Auth

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  Future<UserCredential> signUp(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // --- HÀM MỚI BỔ SUNG: Đăng nhập Facebook ---
  Future<UserCredential?> signInWithFacebook() async {
    try {
      // 1. Kích hoạt quy trình đăng nhập Facebook
      final LoginResult result = await FacebookAuth.instance.login();

      if (result.status == LoginStatus.success) {
        // 2. Lấy Access Token từ Facebook
        final OAuthCredential credential = FacebookAuthProvider.credential(result.accessToken!.tokenString);

        // 3. Đăng nhập vào Firebase bằng Token đó
        return await _auth.signInWithCredential(credential);
      } else {
        print('Lỗi đăng nhập Facebook: ${result.message}');
        return null;
      }
    } catch (e) {
      print('Lỗi ngoại lệ Facebook: $e');
      return null;
    }
  }
  // ------------------------------------------

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Lấy Firebase ID Token để đính kèm vào Header khi gọi API server Flask
  Future<String?> getIdToken() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        return await user.getIdToken(false);
      }
      return null;
    } catch (e) {
      print('Lỗi khi lấy token: $e');
      return null;
    }
  }

  String _handleAuthError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'Không tìm thấy tài khoản với email này.';
        case 'wrong-password':
          return 'Mật khẩu không chính xác.';
        case 'email-already-in-use':
          return 'Email này đã được đăng ký.';
        case 'weak-password':
          return 'Mật khẩu quá yếu, vui lòng chọn mật khẩu từ 6 ký tự trở lên.';
        case 'invalid-email':
          return 'Định dạng email không hợp lệ.';
        case 'invalid-credential':
          return 'Thông tin đăng nhập không chính xác.';
        default:
          return 'Lỗi xác thực: ${e.message}';
      }
    }
    return 'Đã có lỗi xảy ra, vui lòng thử lại.';
  }
}