import 'package:shared_preferences/shared_preferences.dart';

/// Quản lý việc hiển thị "Lưu ý quan trọng" (disclaimer).
///
/// Quy tắc nghiệp vụ:
/// - Người dùng **chưa đăng nhập**: hiển thị lại mỗi lần mở app.
/// - Người dùng **đã đăng nhập**: chỉ hiển thị duy nhất 1 lần, sau đó
///   không bao giờ hiển thị lại nữa (được lưu bền trong SharedPreferences).
class DisclaimerService {
  DisclaimerService._();

  static final DisclaimerService instance = DisclaimerService._();

  /// Cờ đánh dấu đã xác nhận lưu ý ở trạng thái đã đăng nhập.
  static const String _keyAcceptedLoggedIn = 'disclaimer_accepted_logged_in';

  /// Trả về `true` nếu cần hiển thị hộp thoại lưu ý.
  Future<bool> shouldShow({required bool isAuthenticated}) async {
    if (!isAuthenticated) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_keyAcceptedLoggedIn) ?? false);
    } catch (_) {
      return true;
    }
  }

  /// Đánh dấu người dùng đã đồng ý lưu ý (chỉ lưu khi đã đăng nhập).
  Future<void> markAccepted({required bool isAuthenticated}) async {
    if (!isAuthenticated) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAcceptedLoggedIn, true);
    } catch (_) {
      // Bỏ qua nếu không ghi được storage.
    }
  }
}
