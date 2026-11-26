# Cấu hình App cloud + admin local

## Luồng dữ liệu

| Chức năng | URL mặc định trong Flutter | Nguồn dữ liệu |
|---|---|---|
| GPS cây hệ thống, cây cá nhân, lịch sử cây, định tuyến | `http://222.255.184.116` | Cloud API |
| Xác thực, chat, vườn dược liệu và nhận diện trong vườn | `http://222.255.184.116` | Cloud API |
| Nhận diện chính, tra cứu cây và chi tiết cây | `http://10.0.2.2:8000` | Backend App local (`NCKH`) |
| Từ khóa không có kết quả, gửi ảnh cải thiện AI, rút đồng ý | `http://10.0.2.2:8000` | Backend App local ghi MongoDB dùng chung với admin |
| Giao diện và API quản trị | `localhost:5173`, `localhost:8080` trên máy tính | `admin_web` chạy độc lập |

App không gọi API quản trị. Backend App ghi inbox vào MongoDB `plant_vision_admin`; hai collector trong `admin_web/backend` đọc và cập nhật hàng đợi admin. Nội dung đã duyệt được công bố vào MySQL. Cloud hiện có API GPS nhưng **chưa có** `/api/v1/search-events/zero-result` và `/api/v1/prediction-feedback`, nên cần giữ backend App local cho các thao tác đó. Nhận diện chính cũng cần backend local để nhận `feedback_token` dùng khi gửi ảnh.

## Chạy trên Android Emulator

Từ `NCKH`:

```powershell
python -m uvicorn API.main_fastapi:app --host 127.0.0.1 --port 8000
```

Từ `admin_web/backend`, chạy hai cửa sổ terminal:

```powershell
python collect_search_events.py --watch
python collect_review_submissions.py --watch
```

Admin Flask và frontend chạy riêng theo `admin_web/README.md`. Từ `PlantVision`:

```powershell
flutter run --dart-define=MAP_MOCK=false
```

`10.0.2.2` là địa chỉ máy tính nhìn từ Android Emulator. URL cloud đã là mặc định, không cần nhập IP GPS khi chạy.

## Điện thoại thật

Cho điện thoại và máy tính dùng cùng mạng LAN. Chạy backend App với `--host 0.0.0.0`; cho phép TCP 8000 qua tường lửa Windows. Thay `<IP-LAN>` bằng IPv4 máy tính:

```powershell
flutter run --dart-define=LOCAL_BACKEND_URL=http://<IP-LAN>:8000
```

`LOCAL_BACKEND_URL` cấp mặc định cho cả `DETECT_URL` và `ADMIN_BRIDGE_URL`. Có thể đặt hai biến đó riêng khi cần. Không dùng `localhost` hoặc `10.0.2.2` trên điện thoại thật. Máy tính và điện thoại cần Internet để gọi cloud.

## Kiểm tra nhanh

- `http://127.0.0.1:8000/openapi.json`: backend App local trả 200.
- `http://127.0.0.1:8080/api/health`: admin local trả 200.
- Bản đồ hệ thống trên App lấy dữ liệu cloud; cây cá nhân cần đăng nhập.
- Tìm một từ khóa không có kết quả, chờ ít nhất 2 giây; collector chuyển sự kiện vào admin.
- Sau nhận diện, xác nhận gửi ảnh cải thiện AI; collector đưa ảnh vào hàng đợi admin. Rút đồng ý từ hồ sơ cá nhân sẽ xóa dữ liệu tương ứng ở hai bên.

Nếu backend App local hoặc collector dừng, các chức năng tương ứng sẽ không chạy; sự kiện đã ghi inbox vẫn chờ collector xử lý khi chạy lại.
