# Cấu hình đăng nhập Google & Facebook (Plant Vision)

Tài liệu này ghi lại trạng thái cấu hình hiện tại và các bước cần làm trên
Firebase Console / Meta for Developers để đăng nhập mạng xã hội hoạt động.

---

## 1. Thông tin đã xác định từ project

| Mục | Giá trị |
|---|---|
| Firebase project | `forest-medicinal-plant-vision` |
| Firebase App ID (Android) | `1:349896709555:android:5018f6757843bb89c967c6` |
| Package name | `com.example.thunghiem1` |
| Google Web client (`client_type: 3`) | `349896709555-c99ac729eksf3uorr7mc3nnbrfg7d58m.apps.googleusercontent.com` |
| Facebook App ID | `951298307574958` |
| Facebook Client Token | `c0140a7ed34bc153b6f2991e303edd48` |
| Facebook URL scheme | `fb951298307574958` |
| Debug keystore SHA-1 | `6C:49:2F:E0:7D:5D:8D:82:74:D6:8B:6C:64:CE:9B:71:70:19:C2:16` |
| Debug keystore SHA-256 | `6C:98:6F:69:B0:D9:C6:01:0C:E2:B1:14:BC:63:15:21:6F:C0:73:86:5D:26:8A:48:BD:1A:9F:2C:6C:77:92:3D` |
| Facebook key hash (debug) | `bEkv4H1djYJ01otsZM6bcXAZwhY=` |

> SHA-1 / key hash ở trên là của **debug keystore** tại
> `C:\Users\<user>\.android\debug.keystore` (mật khẩu: `android`).
> Khi build release bằng keystore riêng thì phải đăng ký lại fingerprint đó.

---

## 2. Những gì đã có sẵn trong code

- `android/app/google-services.json` — **đã cập nhật** (có `certificate_hash`
  cho debug keystore + web client `client_type: 3`).
  - `certificate_hash` #1: `9c51badb20f8b0831e4656aac215d91567bb4e29`
  - `certificate_hash` #2: `6c492fe07d5d8d8274d68b6c64ce9b717019c216` ← **debug keystore của máy này**
- `android/app/src/main/res/values/strings.xml` — đã có `facebook_app_id`,
  `fb_login_protocol_scheme`, `facebook_client_token`.
- `android/app/src/main/AndroidManifest.xml` — đã có đầy đủ meta-data Facebook
  (`com.facebook.sdk.ApplicationId`, `com.facebook.sdk.ClientToken`),
  `FacebookActivity`, `CustomTabActivity` và `<queries>` cho `com.facebook.katana`.
- `ios/Runner/Info.plist` — đã có `FacebookAppID`, `FacebookClientToken`,
  `CFBundleURLTypes` (`fb951298307574958` + REVERSED_CLIENT_ID của Google web client).
- `lib/config/social_auth_config.dart` — cấu hình ID cho Google/Facebook,
  có thể override bằng `--dart-define`.

---

## 3. Việc cần làm trên Firebase Console (bắt buộc)

### 3.1 Đăng ký SHA-1 của debug keystore — ✅ ĐÃ XONG

> **Trạng thái**: bạn đã tải lại `google-services.json` và file mới đã có
> `certificate_hash` cho debug keystore:
> `6c492fe07d5d8d8274d68b6c64ce9b717019c216` (tương ứng SHA-1
> `6C:49:2F:E0:7D:5D:8D:82:74:D6:8B:6C:64:CE:9B:71:70:19:C2:16`).
> File đã được copy vào `android/app/google-services.json`.
>
> Nếu sau này build release bằng keystore riêng → phải đăng ký lại
> fingerprint của keystore đó (xem mục 4.5).

Cách thực hiện (để tham khảo lần sau):

1. Mở [Firebase Console](https://console.firebase.google.com/) →
   Project `forest-medicinal-plant-vision`.
2. Vào ⚙️ **Project settings** → **Your apps** → chọn app Android
   (`com.example.thunghiem1`).
3. Tab **SHA certificate fingerprints** → **Add fingerprint**.
4. Dán SHA-1: `6C:49:2F:E0:7D:5D:8D:82:74:D6:8B:6C:64:CE:9B:71:70:19:C2:16`
5. (Khuyến nghị) Thêm cả SHA-256 ở trên.
6. **Download google-services.json** mới → thay thế
   `android/app/google-services.json`.

### 3.2 Bật Google Sign-In provider

1. **Authentication** → **Sign-in method** → Google → **Enable**.
2. Email hỗ trợ: chọn email của bạn.
3. Trong phần "Web client ID" phải là web client ở mục 1.

### 3.3 Bật Facebook provider (cho luồng dự phòng)

1. **Authentication** → **Sign-in method** → Facebook → **Enable**.
2. App ID: `951298307574958`
3. App secret: lấy trong Meta for Developers → Settings → Basic
   (bấm "Show" cạnh App Secret).
4. Authorized redirect URI: `https://www.facebook.com/connect/oauth_success/951298307574958/`

---

## 4. Việc cần làm trên Meta for Developers (Facebook)

Vào [developers.facebook.com](https://developers.facebook.com/) → chọn app
`Plant Vision` (App ID `951298307574958`).

### 4.1 Bật Client OAuth Login (bắt buộc)

Đây là công tắc bật/tắt toàn cục cho mọi luồng OAuth client. **Nếu tắt thì
Facebook Login SDK không xin được quyền (permission) và không lấy được
access token** → login luôn fail với lỗi *"Ứng dụng không hoạt động"*.

Đường dẫn (menu bên trái trong App Dashboard):

```
Products  →  Facebook Login  →  Settings
```

Tại đó bật các mục:

| Mục | Trạng thái nên để |
|---|---|
| **Client OAuth Login** | ✅ **Yes / Bật** |
| Web OAuth Login | ✅ Yes (cần cho luồng web fallback) |
| Embedded Browser OAuth Login | ✅ Yes (cần cho luồng dialog trong app) |
| Enforce HTTPS | ✅ Yes |

> Trên giao diện mới (2025+), mục này có thể nằm ở
> **Use cases → Facebook Login → Settings** (mục *"Settings"* mô tả:
> *"Facebook Login allows you to control oAuth settings"*).
> Đây là **cùng một chỗ**, chỉ khác vị trí đường dẫn điều hướng.

### 4.2 Thêm Key Hash Android (bắt buộc)

Đường dẫn:

```
App settings  →  Basic  →  + Platform  →  Android
```

Điền:

- Package name: `com.example.thunghiem1`
- Default Activity Class: `com.example.thunghiem1.MainActivity`
- Key Hashes: `bEkv4H1djYJ01otsZM6bcXAZwhY=`

> Nhấn **Save Changes** sau khi thêm — nếu quên, key hash sẽ không có hiệu lực.

### 4.3 Quyền truy cập (Permissions)

Đường dẫn: **Use cases → Facebook Login → Permissions**

- `public_profile` — **Required** (đã có sẵn, code đang dùng)
- `email` — Optional

Nếu app ở chế độ **Development**, chỉ tài khoản thuộc vai trò
**Admin / Developer / Tester** mới đăng nhập được. Muốn ai cũng đăng nhập
được thì phải chuyển app sang **Live** (cần Business Verification của Meta).

### 4.4 (Tùy chọn) Nếu dùng luồng Firebase OAuth dự phòng

Khi đó cần bật provider Facebook trong Firebase Console
(Authentication → Sign-in method → Facebook) với:
- App ID: `951298307574958`
- App Secret: Meta → App settings → Basic → App secret (bấm **Show**)
- Authorized redirect URI:
  `https://www.facebook.com/connect/oauth_success/951298307574958/`

### 4.5 Sinh lại key hash khi đổi keystore

```bash
keytool -exportcert -alias androiddebugkey \
  -keystore ~/.android/debug.keystore -storepass android -keypass android \
  -file cert.der
# Windows (PowerShell):
$bytes = [System.IO.File]::ReadAllBytes("cert.der")
[Convert]::ToBase64String([System.Security.Cryptography.SHA1]::Create().ComputeHash($bytes))
```

> Keystore release hiện **chưa có** trong project (build release vẫn dùng
> `signingConfig = debug`). Khi tạo keystore release riêng, phải đăng ký
> thêm key hash đó ở bước 4.2.

---

## 5. Chạy app

```bash
# Android (debug)
flutter run \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=349896709555-c99ac729eksf3uorr7mc3nnbrfg7d58m.apps.googleusercontent.com

# iOS (cần thêm client id của iOS nếu build cho iOS)
flutter run \
  --dart-define=GOOGLE_IOS_CLIENT_ID=<ios-client-id>.apps.googleusercontent.com
```

Nếu không truyền `--dart-define`, code sẽ tự dùng giá trị mặc định đã khai
báo trong `lib/config/social_auth_config.dart`.

---

## 6. Luồng dự phòng trong code

`AuthNotifier` xử lý 2 tầng cho mỗi nhà cung cấp:

| Nhà cung cấp | Luồng chính | Luồng dự phòng (tự động) |
|---|---|---|
| Google | `google_sign_in` (native, Credential Manager) | `FirebaseAuth.signInWithProvider(GoogleAuthProvider())` — mở trình duyệt, **không cần SHA-1** |
| Facebook | `flutter_facebook_auth` (native app / web fallback) | `FirebaseAuth.signInWithProvider(FacebookAuthProvider())` — nút "Facebook (khác)?" trong màn hình đăng nhập |

Google tự chuyển sang luồng dự phòng khi gặp
`clientConfigurationError` / `providerConfigurationError` / `unknownError`.

Ngoài ra `AuthApiService.socialLogin` đã tự gọi lại không kèm `name` /
`avatar_url` nếu backend trả `422` (schema chặt) — tránh lỗi đăng nhập
chỉ vì backend chưa hỗ trợ field profile.

---

## 7. Kiểm tra nhanh

| Triệu chứng | Nguyên nhân | Khắc phục |
|---|---|---|
| `GoogleSignInExceptionCode.clientConfigurationError` | Chưa đăng ký SHA-1 | Mục 3.1 |
| `serverClientId must be provided on Android` | `google-services.json` thiếu web client | Tải lại file (mục 3.1 bước 6) |
| "Ứng dụng không hoạt động" (Facebook) | App Facebook ở chế độ Development / sai key hash | Mục 4 |
| `422 Unprocessable Entity` khi login | Backend chưa có field `name`/`avatar_url` | Đã xử lý tự động; nếu vẫn lỗi thì cập nhật backend |
| `401` từ `/api/auth/social` | Backend chưa đăng ký provider_id tương ứng | Kiểm tra log backend |
