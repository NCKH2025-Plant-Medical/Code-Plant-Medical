# Khắc phục lỗi đăng nhập — `222.255.184.116` mất router `/api/auth/*`

## Nguyên nhân gốc

Server `http://222.255.184.116` đã được deploy lại bản **"Forest Medicinal Plant Vision API (Inference-only)"**.
Kiểm chứng bằng `http://222.255.184.116/openapi.json`, server hiện chỉ phục vụ:

| Route | Method | Trạng thái |
|---|---|---|
| `/predict` | POST | ✅ hoạt động (422 khi thiếu body) |
| `/api/v1/chat` | POST | ✅ hoạt động |
| `/api/v1/chat/history` | GET | ✅ có |
| `/api/v1/chat/session/{id}` | DELETE | ✅ có |
| `/api/v1/chat/session/new` | POST | ✅ có |
| `/api/v1/chat/conversations` | GET | ✅ có |
| `/api/v1/chat/image` | POST | ✅ có |
| `/api/v1/plants/search` | GET | ✅ có (422 khi thiếu query) |
| `/api/v1/plants/search-suggestions` | GET | ✅ có |
| `/api/v1/plants/{plant_id}` | GET | ✅ có |

**Các route đã bị gỡ khỏi server** (đều trả `404 {"detail":"Not Found"}`):

- `/api/auth/*` — login, register, social, me, check-username, check-phone, refresh, logout, reset-password
- `/api/v1/system-plants/map`
- `/api/v1/user-plants/map`
- `/api/v1/user-plants`
- `/api/images`, `/api/upload-image`

> Trước đây code gốc trỏ auth về `detectUrlLocal` (mặc định `http://10.0.2.2:8000` — backend local),
> nên bạn vẫn đăng nhập được. Khi các URL local bị đổi hết sang `222.255.184.116`,
> app không còn host nào có router auth → đăng nhập thất bại.

## Đã sửa gì trong frontend

### 1. `lib/config/app_config.dart`

- Khôi phục default gốc cho các API chỉ có ở backend local:
  `detectUrlLocal`, `historyUrl`, `mapSystemUrl`, `mapUserUrl`, `historyUserUrl` → `http://10.0.2.2:8000`
- Thêm `authFallbackUrls` (danh sách host dự phòng, phân tách bằng dấu phẩy):
  ```
  http://10.0.2.2:8000,http://192.168.1.14:8000
  ```

### 2. `lib/services/auth_api_service.dart`

- Thêm **auto-discovery**: app tự dò lần lượt các host, kiểm tra host nào thực sự có router
  `/api/auth/*` (POST body rỗng → `401`/`422` = có router, `404` = không có), rồi dùng host đó.
- Kết quả được cache sau lần dò thành công; nếu không host nào có thì **không cache** để lần sau thử lại.
- Log rõ ràng: `[AuthAPI] Dung server auth: <host>` / `[AuthAPI] <host> khong co router /api/auth/* (404)`
- Thông báo lỗi 404 nay nói rõ *"Máy chủ phục vụ không có API đăng nhập"* thay vì báo chung chung.

### 3. `lib/controllers/auth_notifier.dart`

- Log chi tiết lỗi mạng + hiển thị host đang dùng trong thông báo.

## Cách chạy

### Bước 1 — Bật backend local (khuyến nghị)

Nếu bạn có sẵn FastAPI backend đầy đủ (có `/api/auth/*`), chạy nó ở cổng `8000`:

```powershell
cd <thu-muc-backend>
uvicorn main:app --host 0.0.0.0 --port 8000
```

### Bước 2 — Nếu chưa có backend, dùng mock server kèm theo

Repo đã có `tool/mock_auth_server.py` (chỉ dùng Python stdlib, không cần `pip install`):

```powershell
python tool/mock_auth_server.py --port 8000
```

Tài khoản sẵn có: `admin` / `123456`, `user1` / `123456`, `user2` / `123456`
(user mới đăng nhập sẽ được tự động đăng ký).

> **Lưu ý:** mock server dùng secret key riêng, nên JWT của nó **không** dùng được với
> backend thật. Khi backend thật sẵn sàng, chỉ cần tắt mock và chạy backend thật — app tự dò thấy.

### Bước 3 — Chạy app

```powershell
flutter run
```

Trên **Android Emulator**: `10.0.2.2:8000` tự trỏ về máy host → hoạt động ngay.
Trên **máy thật**: dùng IP LAN của máy tính (`192.168.1.14` hiện tại) — đã có sẵn trong
`authFallbackUrls`. Nếu IP đổi, override:

```powershell
flutter run --dart-define=AUTH_FALLBACK_URLS=http://192.168.1.X:8000
```

### Bước 4 — Trỏ thẳng vào server auth khác

```powershell
flutter run --dart-define=AUTH_URL=http://ten-may-chu:8000
```

## Đưa server về trạng thái đầy đủ (việc phía backend)

Nhờ người quản trị server mount lại router auth trong FastAPI:

```python
from fastapi import FastAPI
from routers import auth_router, chat_router, plant_router, user_plant_router

app = FastAPI(title="Forest Medicinal Plant Vision API")

app.include_router(auth_router.router, prefix="/api/auth", tags=["auth"])
app.include_router(chat_router.router, prefix="/api/v1/chat", tags=["chat"])
app.include_router(plant_router.router, prefix="/api/v1/plants", tags=["plants"])
app.include_router(user_plant_router.router, prefix="/api/v1/user-plants", tags=["user-plants"])
```

Router auth cần đủ các endpoint:

| Method | Path | Request | Response |
|---|---|---|---|
| POST | `/api/auth/login` | `username`, `password` | `{access_token, refresh_token?}` |
| POST | `/api/auth/register` | `username`, `phone_number`, `password`, `firebase_id_token` | `{access_token}` |
| POST | `/api/auth/social` | `provider` (`google`\|`facebook`), `provider_id`, `name?`, `avatar_url?` | `{access_token}` |
| GET | `/api/auth/check-username?username=` | — | `{available}` |
| POST | `/api/auth/check-phone` | `phone_number` | `{exists}` |
| GET | `/api/auth/me` | Bearer JWT | profile |
| PATCH | `/api/auth/me` | Bearer JWT, `username` | profile |
| POST | `/api/auth/refresh` | `refresh_token` | `{access_token, refresh_token?}` |
| POST | `/api/auth/logout` | Bearer JWT | `{success}` |
| POST | `/api/auth/reset-password` | `phone_number`, `firebase_id_token`, `new_password` | `{success}` |

## Kiểm tra nhanh từ PowerShell

```powershell
# Server này co router auth khong? (404 = khong co)
Invoke-WebRequest http://222.255.184.116/api/auth/login -Method POST `
  -ContentType 'application/json' -Body '{}' -UseBasicParsing
```
