class AppConfig {
  // ── Nhận diện cây (AI Model) ─────────────────────────────────────────────
  /// Server AI production (remote)
  static const detectUrl = String.fromEnvironment(
    'DETECT_URL',
    defaultValue: 'http://222.255.184.116',
  );

  /// Server backend local (dev). Trên Android Emulator dùng 10.0.2.2 thay localhost.
  /// Trên thiết bị thật trong cùng mạng WiFi: dùng IP LAN máy tính (VD: 192.168.1.x:8000)
  ///
  /// Server `222.255.184.116` là bản "Inference-only" — chỉ có `/predict`,
  /// `/api/v1/chat/*` và `/api/v1/plants/search`. Các API còn lại (auth,
  /// system-plants/map, user-plants, images) chỉ có ở backend local.
  static const detectUrlLocal = String.fromEnvironment(
    'DETECT_URL_LOCAL',
    defaultValue: 'http://222.255.184.116',
  );

  static const historyUrl = String.fromEnvironment(
    'HISTORY_URL',
    defaultValue: 'http://222.255.184.116',
  );

  // ── Bản đồ ────────────────────────────────────────────────────────────────
  /// Base URL cho API cây trồng hệ thống (MySQL) — không cần auth.
  /// Mặc định dùng local server (dev). Production: dùng --dart-define=MAP_SYSTEM_URL=...
  static const mapSystemUrl = String.fromEnvironment(
    'MAP_SYSTEM_URL',
    defaultValue: 'http://222.255.184.116',
  );

  /// Base URL cho API cây trồng cá nhân (MongoDB) — cần Bearer JWT.
  static const mapUserUrl = String.fromEnvironment(
    'MAP_USER_URL',
    defaultValue: 'http://222.255.184.116',
  );

  /// Base URL cho API lịch sử ảnh người dùng.
  static const historyUserUrl = String.fromEnvironment(
    'HISTORY_USER_URL',
    defaultValue: 'http://222.255.184.116',
  );

  /// Base URL cho API ChatBox (hỏi đáp AI).
  /// Mặc định trùng host với các API khác.
  static const chatUrl = String.fromEnvironment(
    'CHAT_URL',
    defaultValue: 'http://222.255.184.116',
  );

  /// Base URL riêng cho API xác thực (`/api/auth/*`).
  ///
  /// Server hiện tại đã tách router auth ra khỏi app chính, nên biến này
  /// cho phép trỏ sang server auth riêng mà không phải sửa code.
  /// Ví dụ: `--dart-define=AUTH_URL=http://10.0.2.2:8000`
  static const authUrl = String.fromEnvironment(
    'AUTH_URL',
    defaultValue: 'http://222.255.184.116',
  );

  /// Danh sách host dự phòng cho API xác thực, cách nhau bằng dấu phẩy.
  ///
  /// App sẽ dò lần lượt các host này (kèm [authUrl]) và chọn host đầu tiên
  /// thực sự phục vụ router `/api/auth/*`.
  ///
  /// - `10.0.2.2:8000` → backend local khi chạy trên Android Emulator.
  /// - `192.168.1.14:8000` → backend local trong cùng mạng WiFi (máy thật).
  ///
  /// Có thể ghi đè: `--dart-define=AUTH_FALLBACK_URLS=http://a:8000,http://b:8000`
  static const authFallbackUrls = String.fromEnvironment(
    'AUTH_FALLBACK_URLS',
    defaultValue: 'http://10.0.2.2:8000,http://192.168.1.14:8000',
  );

  /// Bật mock data khi backend chưa sẵn sàng.
  /// Chạy: flutter run --dart-define=MAP_MOCK=true
  /// Mặc định = false (dùng API thật).
  static const mapMock = bool.fromEnvironment('MAP_MOCK', defaultValue: false);

  /// Danh sách host dự phòng cho API bản đồ, cách nhau bằng dấu phẩy.
  ///
  /// App sẽ dò lần lượt các host này (kèm [mapSystemUrl]) và chọn host đầu tiên
  /// thực sự phục vụ router `/api/v1/system-plants/map`.
  ///
  /// - `10.0.2.2:8000` → backend local khi chạy trên Android Emulator.
  /// - `192.168.1.14:8000` → backend local trong cùng mạng WiFi (máy thật).
  /// - `222.255.184.116` → server production.
  ///
  /// Có thể ghi đè: `--dart-define=MAP_FALLBACK_URLS=http://a:8000,http://b:8000`
  static const mapFallbackUrls = String.fromEnvironment(
    'MAP_FALLBACK_URLS',
    defaultValue:
        'http://10.0.2.2:8000,http://192.168.1.14:8000,http://222.255.184.116',
  );
}
