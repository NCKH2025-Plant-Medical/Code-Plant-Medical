# HỢP ĐỒNG API BẢN ĐỒ (Plant Map)

Tài liệu này mô tả chính xác các endpoint mà frontend (`lib/services/map_api_service.dart`)
đang gọi. Backend chỉ cần trả về đúng format bên dưới là app chạy được, **không cần**
sửa code Flutter.

---

## 1. Cấu hình base URL

Frontend đọc base URL từ `--dart-define` (xem `lib/config/app_config.dart`):

| Biến | Mặc định | Ý nghĩa |
|---|---|---|
| `MAP_SYSTEM_URL` | `http://222.255.184.116` | Server chứa **cây hệ thống** (MySQL) |
| `MAP_USER_URL` | `http://10.0.2.2:8000` | Server chứa **cây cá nhân** (MongoDB, cần JWT) |
| `MAP_MOCK` | `false` | `true` → dùng dữ liệu giả lập (khi backend chưa xong) |

Run ứng dụng:

```bash
flutter run --dart-define=MAP_SYSTEM_URL=http://10.0.2.2:8000 \
            --dart-define=MAP_USER_URL=http://10.0.2.2:8000 \
            --dart-define=MAP_MOCK=false
```

---

## 2. GET `/api/v1/system-plants/map`

Lấy các cây trồng **hệ thống** nằm trong khung nhìn của bản đồ.

### Query params

| Param | Kiểu | Bắt buộc | Mô tả |
|---|---|---|---|
| `min_lat` | float | ✔ | Vĩ độ nhỏ nhất (south-west) |
| `max_lat` | float | ✔ | Vĩ độ lớn nhất (north-east) |
| `min_lng` | float | ✔ | Kinh độ nhỏ nhất (south-west) |
| `max_lng` | float | ✔ | Kinh độ lớn nhất (north-east) |

### Response mẫu — 200 OK

```json
{
  "data": [
    {
      "id": 12,
      "name": "Bồ công anh",
      "scientific_name": "Taraxacum mongolicum",
      "description": "Cây thuốc thanh nhiệt, tiêu hóa.",
      "image_url": "https://cdn.example.com/plants/12.jpg",
      "latitude": 21.028500,
      "longitude": 105.854200
    }
  ]
}
```

Frontend **cũng chấp nhận** mảng trực tiếp (không bọc `data`):

```json
[
  { "id": 12, "name": "...", "latitude": 21.03, "longitude": 105.85 }
]
```

### Field bắt buộc / tùy chọn

| Field | Bắt buộc | Ghi chú |
|---|---|---|
| `id` | ✔ | Dùng làm `plantId` để gọi API chi tiết cây |
| `latitude` | ✔ | Có thể dùng `lat` thay thế |
| `longitude` | ✔ | Có thể dùng `lng` thay thế |
| `name` | ✖ | Fallback: `"Cây hệ thống"` |
| `scientific_name` | ✖ | |
| `description` | ✖ | |
| `image_url` | ✖ | Fallback `thumbnail_url`, `image` |

### Quy ước phân biệt nguồn

- Endpoint `system-plants` → marker màu **xanh dương** (`#1565C0`) — chú thích "Cây hệ thống".
- Endpoint `user-plants` → marker màu **cam** (`#E65100`) — chú thích "Cây cá nhân".

Frontend tự gán màu theo endpoint, backend **không cần** trả field nguồn.

---

## 3. GET `/api/v1/user-plants/map`

Lấy các cây trồng **cá nhân** (cây user tự lưu) trong khung nhìn.

- Giống hệt endpoint trên về query params và format response.
- **Bắt buộc** header xác thực:

```http
Authorization: Bearer <JWT>
```

### JWT

- Lưu ở `flutter_secure_storage` với key `plant_vision_jwt`.
- Backend verify bằng `SECRET_KEY` **HS256** riêng (KHÔNG phải Firebase public key).
- Nếu token hết hạn / không hợp lệ → trả `401`.
  Frontend sẽ bỏ qua endpoint này, chỉ hiển thị cây hệ thống, **không crash app**.

---

## 4. Xử lý lỗi (Partial Failure)

Hai API được gọi **đồng thời** bằng `Future.wait`, mỗi API có error handler riêng.

| Tình huống | Hành vi UI |
|---|---|
| 1 API lỗi, 1 API OK | Hiển thị marker của API OK + **Toast cam**: *"Không thể tải toàn bộ dữ liệu lúc này"* |
| Cả 2 API lỗi | **Toast cam**: *"Không thể tải dữ liệu bản đồ lúc này"* |
| Mất mạng (không có connectivity) | Load **cache offline** (SharedPreferences) + **Snackbar đỏ** |

> Không bao giờ `throw` ra UI. Màn hình map luôn render được.

### Offline cache

Frontend lưu JSON vào `SharedPreferences` sau mỗi lần tải thành công:

```
key: plant_map_cache_v1
value: [ { "id": "sys_12", "plantId": "12", "name": "...", "source": "system",
           "latitude": 21.03, "longitude": 105.85, "imageUrl": null, ... } ]
```

Khi offline, app đọc cache này để vẽ lại marker đã xem lần trước.

---

## 5. Endpoint phụ trợ (đã có sẵn trong app)

| Endpoint | Nguồn | Mô tả |
|---|---|---|
| `GET /api/v1/plants/{id}` | `ApiService` | Chi tiết cây — dùng khi bấm "Xem thông tin chi tiết" trong bottom sheet của map |
| `GET /api/v1/plants/search?q=&limit=` | `ApiService` | Tìm kiếm cây (dùng ở màn hình Search) |

---

## 6. Checklist cho backend

- [ ] `GET /api/v1/system-plants/map` trả `200` với `{ "data": [...] }` hoặc mảng trực tiếp.
- [ ] Mỗi item có `id`, `latitude`, `longitude` (hoặc `lat`/`lng`).
- [ ] `GET /api/v1/user-plants/map` yêu cầu `Authorization: Bearer <JWT>`, trả `401` khi token sai/hết hạn.
- [ ] Lọc theo bounding box đúng thứ tự `min_lat ≤ latitude ≤ max_lat`, tương tự cho `lng`.
- [ ] Trả `Content-Type: application/json` (frontend đọc `utf8.decode(response.bodyBytes)`).
- [ ] Nếu chưa sẵn sàng → chạy app với `--dart-define=MAP_MOCK=true` để demo UI.
