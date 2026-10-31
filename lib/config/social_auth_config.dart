/// Cấu hình định danh cho đăng nhập mạng xã hội (Google / Facebook).
///
/// Có thể override khi build mà không cần sửa code:
/// ```bash
/// flutter run \
///   --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com \
///   --dart-define=GOOGLE_IOS_CLIENT_ID=<ios-client-id>.apps.googleusercontent.com
/// ```
class SocialAuthConfig {
  SocialAuthConfig._();

  /// OAuth client loại **Web** (client_type: 3) trong `google-services.json`.
  ///
  /// Bắt buộc phải truyền làm `serverClientId` thì Google Sign-In trên Android
  /// mới trả về idToken/profile. Đây cũng là client phải khớp với backend.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '349896709555-c99ac729eksf3uorr7mc3nnbrfg7d58m.apps.googleusercontent.com',
  );

  /// OAuth client của iOS (dùng khi build cho iOS).
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  /// Facebook App ID — phải trùng với `facebook_app_id` trong
  /// `android/app/src/main/res/values/strings.xml` và `Info.plist` (iOS).
  static const String facebookAppId = String.fromEnvironment(
    'FACEBOOK_APP_ID',
    defaultValue: '951298307574958',
  );

  /// Có cấu hình Google hợp lệ hay chưa.
  static bool get hasGoogleServerClientId =>
      googleServerClientId.trim().isNotEmpty;
}
