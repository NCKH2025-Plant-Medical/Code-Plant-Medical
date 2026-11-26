class AppConfig {
  /// Cloud cho nhận diện, xác thực, chat, tra cứu và vườn dược liệu.
  static const cloudUrl = 'http://222.255.184.116';

  /// Localhost máy tính nhìn từ Android Emulator.
  /// Web/desktop: --dart-define=LOCAL_BACKEND_URL=http://localhost:8000
  /// Điện thoại thật: dùng IP LAN của máy tính, cổng 8000.
  static const localBackendUrl = String.fromEnvironment(
    'LOCAL_BACKEND_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const detectUrl = String.fromEnvironment(
    'DETECT_URL',
    defaultValue: localBackendUrl,
  );

  /// API local ghi sự kiện tìm kiếm và ảnh cải thiện AI vào MongoDB dùng chung với admin.
  static const adminBridgeUrl = String.fromEnvironment(
    'ADMIN_BRIDGE_URL',
    defaultValue: localBackendUrl,
  );

  // Giữ tương thích với cấu hình cũ; các chức năng chung vẫn dùng cloud.
  static const detectUrlLocal = String.fromEnvironment(
    'DETECT_URL_LOCAL',
    defaultValue: cloudUrl,
  );

  /// GPS và cây cá nhân đã được triển khai trên cloud.
  static const mapSystemUrl = String.fromEnvironment(
    'MAP_SYSTEM_URL',
    defaultValue: cloudUrl,
  );
  static const mapUserUrl = String.fromEnvironment(
    'MAP_USER_URL',
    defaultValue: cloudUrl,
  );

  /// Lịch sử cây cá nhân dùng cùng backend cloud với mapUserUrl.
  static const historyUrl = String.fromEnvironment(
    'HISTORY_URL',
    defaultValue: mapUserUrl,
  );
  static const historyUserUrl = String.fromEnvironment(
    'HISTORY_USER_URL',
    defaultValue: historyUrl,
  );

  static const chatUrl = String.fromEnvironment(
    'CHAT_URL',
    defaultValue: cloudUrl,
  );

  /// Tách khỏi mapUserUrl để vườn không đi theo backend GPS.
  static const gardenUrl = String.fromEnvironment(
    'GARDEN_URL',
    defaultValue: cloudUrl,
  );

  /// Nhận diện trong vườn dùng cloud; nhận diện có gửi ảnh cho admin vẫn dùng detectUrl local.
  static const gardenDetectUrl = String.fromEnvironment(
    'GARDEN_DETECT_URL',
    defaultValue: cloudUrl,
  );

  /// UID dùng cho API Vườn Dược Liệu.
  ///
  /// Server hiện chạy ở **chế độ demo** (`HERBAL_GARDEN_REQUIRE_AUTH=false`):
  /// mọi người thấy chung một vườn mẫu 5 cây để demo đầy đủ mọi loại chip &
  /// badge. Vườn mẫu được seed dưới uid = `demo`.
  ///
  /// Có thể ghi đè:
  ///   • `--dart-define=GARDEN_UID=demo`      → vườn mẫu dùng chung (mặc định)
  ///   • `--dart-define=GARDEN_UID=account`   → mỗi tài khoản một vườn riêng
  ///   • `--dart-define=GARDEN_UID=<uid>`     → uid bất kỳ
  ///
  /// ⚠️ Khi backend bật `HERBAL_GARDEN_REQUIRE_AUTH=true`, `uid` trong query
  /// sẽ bị server **bỏ qua hoàn toàn** và lấy uid từ `Authorization: Bearer`.
  static const gardenUid = String.fromEnvironment(
    'GARDEN_UID',
    defaultValue: 'demo',
  );

  /// Bật vườn riêng cho từng tài khoản đăng nhập.
  ///
  /// `false` (mặc định) → mọi người dùng chung vườn mẫu `demo` (chế độ demo
  /// của backend). `true` → dùng `user_id` của account làm uid, mỗi người
  /// một vườn riêng (vườn mới sẽ trống cho tới khi họ thêm cây).
  static const gardenPerUser = bool.fromEnvironment(
    'GARDEN_PER_USER',
    defaultValue: false,
  );

  /// Base URL riêng cho API xác thực (`/api/auth/*`).
  ///
  /// Server hiện tại đã tách router auth ra khỏi app chính, nên biến này
  /// cho phép trỏ sang server auth riêng mà không phải sửa code.
  /// Ví dụ: `--dart-define=AUTH_URL=http://10.0.2.2:8000`
  static const authUrl = String.fromEnvironment(
    'AUTH_URL',
    defaultValue: cloudUrl,
  );

  /// Không tự chuyển xác thực sang local khi cloud không phản hồi.
  static const authFallbackUrls = String.fromEnvironment(
    'AUTH_FALLBACK_URLS',
    defaultValue: '',
  );

  /// Bật mock data khi backend chưa sẵn sàng.
  /// Chạy: flutter run --dart-define=MAP_MOCK=true
  /// Mặc định = false (dùng API thật).
  static const mapMock = bool.fromEnvironment('MAP_MOCK', defaultValue: false);

  /// Host dự phòng tùy chọn cho API GPS.
  static const mapFallbackUrls = String.fromEnvironment(
    'MAP_FALLBACK_URLS',
    defaultValue: '',
  );
}
