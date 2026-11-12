# admin_web — Web quản trị dữ liệu người dùng (Plant Vision)

Thư mục này HOÀN TOÀN ĐỘC LẬP với app Flutter:
- Không có file `.dart` → `flutter analyze` không đụng tới
- Không có file `.gradle` → `flutter build apk` không đụng tới
- Không đụng `pubspec.yaml`, `android/`, `lib/`

---

## 1. Kiến trúc

```
MongoDB  ──sync_mongo.py──▶  SQLite local  ──server.py──▶  Web UI
222.255.184.116:27017      data/plant_medical.db      http://localhost:8080
     (qua SSH tunnel)              ▲
                                  └── (tuỳ chọn) profile đầy đủ từ REST API
```

Đồng bộ 1 lần → web đọc SQLite nhanh, không phụ thuộc mạng.

---

## 2. Lấy MONGO_URI (3 cách, theo thứ tự khả năng)

### Cách A — Tự động quét server (khuyến nghị)

Cần tài khoản SSH của server `222.255.184.116` (Ubuntu 24.04).

```powershell
# Bằng mật khẩu
.\admin_web\tools\get_mongo_uri.ps1 -User root

# Bằng key
.\admin_web\tools\get_mongo_uri.ps1 -User ubuntu -KeyPath $env:USERPROFILE\.ssh\id_ed25519
```

Script quét 10 nơi: `.env` của app, `docker-compose.yml`, container đang chạy,
`systemd Environment=`, `/etc/mongod.conf`, tiến trình `mongod`, port đang listen,...

### Cách B — SSH vào server tự tìm

```powershell
ssh root@222.255.184.116
```

Trên server:
```bash
sudo grep -rInE 'mongodb(\+srv)?://' /opt /srv /var/www /home /root 2>/dev/null
sudo systemctl cat <tên-service> | grep -i mongo
sudo cat /etc/mongod.conf
sudo docker ps
sudo docker inspect <container-mongo> --format '{{range .Config.Env}}{{println .}}{{end}}'
```

### Cách C — MongoDB Atlas

Atlas UI → *Database Access* → *Add New Database User* → *Connect* → copy URI dạng
`mongodb+srv://user:pass@cluster.xxx.mongodb.net/?retryWrites=true&w=majority`

---

## 3. Kết nối (quan trọng: port 27017 bị đóng từ Internet)

Đã kiểm tra: `222.255.184.116:27017` **không** phản hồi từ ngoài. MongoDB
gần như chắc chắn chỉ bind `127.0.0.1` trên server → phải đào SSH tunnel.

```powershell
# Cửa sổ terminal riêng, để nguyên
python admin_web\tools\tunnel.py --user root
# hoặc thủ công:
ssh -N -L 27017:127.0.0.1:27017 root@222.255.184.116
```

Rồi trong `.env`:
```ini
MONGO_URI=mongodb://127.0.0.1:27017
```

> Nếu server bật `auth`, URI cần user/password:
> `mongodb://<user>:<pass>@127.0.0.1:27017/?authSource=admin`

---

## 4. Chạy

```powershell
pip install -r admin_web\requirements.txt
copy admin_web\.env.example admin_web\.env    # rồi điền MONGO_URI

# (tuỳ chọn) xem trước cấu trúc DB
python admin_web\tools\test_mongo.py

# đồng bộ MongoDB -> SQLite
python admin_web\sync_mongo.py

# mở web
python admin_web\server.py       # http://localhost:8080
```

---

## 5. Biến trong `.env`

| Biến | Ý nghĩa |
|---|---|
| `MONGO_URI` | Connection string MongoDB |
| `MONGO_DB` | Tên database (để trống = tự dò) |
| `API_BASE_URL` | Backend REST để lấy profile đầy đủ |
| `AUTH_CREDENTIALS` | `user:pass,user2:pass2` — dùng để lấy username/email/SĐT |
| `HOST` / `PORT` | Địa chỉ web server (mặc định `127.0.0.1:8080`) |

> `AUTH_CREDENTIALS` là **tuỳ chọn**. Không có nó, web vẫn chạy và hiện đầy đủ
> lịch sử nhận diện + GPS; chỉ thiếu tên/email/SĐT của user (dữ liệu đó nằm ở MySQL).

---

## 6. REST API

| Endpoint | Mô tả |
|---|---|
| `GET /api/stats` | Thống kê tổng quan + lần sync cuối |
| `GET /api/users` | Danh sách user (`?q=&page=&limit=&sort=&order=`) |
| `GET /api/users/<user_id>` | Chi tiết user + cây + chat |
| `GET /api/plants` | Lịch sử nhận diện (`?q=&user_id=&located=1`) |
| `GET /api/chats` | Lịch sử chat (`?user_id=&limit=`) |
| `GET /api/sync-log` | Nhật ký đồng bộ |
| `GET /api/health` | Kiểm tra sống |

---

## 7. File trong thư mục

```
admin_web/
├── .env / .env.example    cấu hình (KHÔNG commit .env thật)
├── config.py              đọc .env
├── db.py                  lớp truy cập SQLite (schema + upsert)
├── sync_mongo.py          MongoDB -> SQLite
├── server.py              Flask server + REST API
├── static/                index.html · app.js · style.css
├── data/plant_medical.db  database local (gitignore)
└── tools/
    ├── get_mongo_uri.ps1  quét server tìm URI
    ├── test_mongo.py      test URI + liệt kê cấu trúc DB
    └── tunnel.py          mở SSH tunnel
```
