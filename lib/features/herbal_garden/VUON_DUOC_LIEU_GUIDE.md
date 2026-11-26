# Vườn Dược Liệu — Hướng dẫn sử dụng & luồng API

> Chức năng "Vườn Dược Liệu" (Herbal Garden) của ứng dụng **Plant Vision**.
> Tài liệu này mô tả cách người dùng thao tác trên từng màn hình và ánh xạ
> từng thao tác đó tới API trên Cloud Server.

---

## 1. Tổng quan kiến trúc

### 1.1. Vị trí mã nguồn

Toàn bộ chức năng nằm gọn trong **1 thư mục riêng**:

```
lib/features/herbal_garden/
├── models/
│   └── garden_models.dart          # Model Dart cho toàn bộ 15 endpoint
├── services/
│   └── herbal_garden_api.dart      # HTTP client + xử lý lỗi + upload ảnh
├── state/
│   └── herbal_garden_state.dart    # ChangeNotifier dùng chung cho mọi màn hình
├── screens/
│   ├── garden_hub_screen.dart      # MÀN HÌNH 0 — Hub "Vườn Dược Liệu" (ô bánh)
│   ├── garden_screen.dart           # MÀN HÌNH 1 — Vườn của tôi
│   ├── garden_care_screen.dart     # MÀN HÌNH 1b — Việc hôm nay (tách riêng)
│   ├── garden_plant_detail_screen.dart  # MÀN HÌNH 2 — Chi tiết cây
│   ├── garden_add_plant_screen.dart     # MÀN HÌNH 3 — Thêm cây
│   └── garden_deleted_screen.dart       # MÀN HÌNH 4 — Cây đã xoá
└── widgets/
    ├── garden_style.dart            # Bảng màu, chip, banner, nút dùng chung
    ├── garden_cards.dart            # Card thời tiết / thẻ việc / thẻ cây
    └── garden_harvest_dialog.dart   # Dialog nhập khối lượng thu hoạch
```

Mã cũ của thành viên trước đã được **xoá hoàn toàn**
(`lib/screens/garden/`, `lib/models/herbal_garden.dart`,
`lib/services/herbal_garden_api.dart`, `lib/controllers/garden_notifier.dart`).

### 1.2. Cấu trúc ứng dụng

```
lib/
├── features/herbal_garden/     ← CHỨC NĂNG VƯỜN DƯỢC LIỆU (mới)
├── screens/                    ← các màn hình gốc (Home, Map, Search...)
├── widgets/                    ← widget dùng chung toàn app
├── services/                   ← service gốc
├── models/                     ← model gốc
├── theme/                      ← AppColors / AppTheme
└── app.dart                    ← MultiProvider (đăng ký HerbalGardenController)
```

### 1.3. Base URL & xác thực

| Mục | Giá trị |
|---|---|
| Cloud Server | `http://222.255.184.116` |
| Prefix API | `/api/v1/herbal-garden` |
| Nguồn URL | `AppConfig.detectUrl` (không hardcode trong feature) |

* Server đang chạy chế độ **demo** (`HERBAL_GARDEN_REQUIRE_AUTH=false`).
* FE luôn gửi `uid` trong query (mặc định `demo`, xem `AppConfig.gardenUid`).
* Nếu người dùng đã đăng nhập, FE gửi kèm header `Authorization: Bearer <token>`
  → server ưu tiên uid lấy từ JWT và **bỏ qua** `uid` trong query.
* Bật vườn riêng theo tài khoản: chạy với `--dart-define=GARDEN_PER_USER=true`.

---

## 2. Bản đồ màn hình (4 màn hình UI)

```
        ┌───────────────────────────────┐
        │  HomeScreen                   │
        │  [ActionCard "Vườn Dược Liệu"]│  ← thẻ 3
        └───────────────┬───────────────┘
                        │ push
                        ▼
        ┌───────────────────────────────┐
        │ ⓪ GardenHubScreen (HUB)      │
        │  "VƯỜN DƯỢC LIỆU"             │
        │  ├ Hero gradient + 3 pill số  │
        │  ├ Dải số liệu tổng quan      │
        │  ├ Ô bánh lớn "Vườn của tôi"  │
        │  ├ Ô bánh "Việc hôm nay"      │
        │  ├ Ô bánh "Thêm cây"           │
        │  ├ Ô bánh "Cây đã xoá"         │
        │  └ Widget thời tiết           │
        └─┬──────────┬──────────┬──────┘
          │          │          │
   tap ô  │   tap ô  │   tap ô  │ tap ô
          ▼          ▼          ▼          ▼
    ┌──────────┐ ┌─────────┐ ┌────────┐ ┌──────────────┐
    │① Vườn của│ │①b Việc  │ │③ Thêm │ │④ Cây đã xoá  │
    │   tôi    │ │  hôm nay│ │  cây   │ │  (thùng rác) │
    └────┬─────┘ └─────────┘ └────────┘ └──────────────┘
         │ tap cây
         ▼
    ┌──────────────┐
    │② Chi tiết cây│
    └──────────────┘
```

| # | Màn hình | File | Vai trò |
|---|---|---|---|
| 0 | **Hub Vườn Dược Liệu** | `screens/garden_hub_screen.dart` | Trang cửa vào: tóm tắt + bảng ô bánh dẫn tới 4 trang con |
| 1 | **Vườn của tôi** | `screens/garden_screen.dart` | Trung tâm: thời tiết, danh sách cây, lọc & tìm kiếm |
| 1b | **Việc hôm nay** | `screens/garden_care_screen.dart` | Toàn bộ việc chăm sóc trong ngày (tách riêng khỏi màn hình ①) |
| 2 | **Chi tiết cây** | `screens/garden_plant_detail_screen.dart` | Hồ sơ đầy đủ 1 cây + mọi thao tác ghi |
| 3 | **Thêm cây** | `screens/garden_add_plant_screen.dart` | Form 4 bước: chọn loài → thông tin → đất → vị trí |
| 4 | **Cây đã xoá** | `screens/garden_deleted_screen.dart` | Thùng rác + khôi phục |

> Không có màn hình nào "nhồi tất cả". Mỗi màn hình có **một nhiệm vụ rõ ràng**,
> điều hướng bằng `Navigator.push` + `MaterialPageRoute`.

---

## 3. Luồng người dùng chi tiết theo màn hình

### 3.0. MÀN HÌNH 0 — Hub "Vườn Dược Liệu" (trang cửa vào)

Người dùng bấm **thẻ 3 "Vườn Dược Liệu"** trên Dashboard → vào đây.

**Bố cục (từ trên xuống):**

1. **Hero gradient** (`#1B4332 → #2D6A4F`, bo góc dưới 30px)
   - Icon cây + tiêu đề "Vườn Dược Liệu" + ngày hôm nay.
   - Nút ⟳ làm mới.
   - 3 "pill" nhịp sống của vườn: **số cây** · **số việc** · **số cây đã xoá**.
2. **Dải số liệu** — số cây · số việc hôm nay · tổng kg đã thu.
3. **Bảng ô bánh (hub tiles)** — 4 ô, mỗi ô là 1 trang con:
   - Ô **lớn** (gradient xanh, chiếm 1/2 hàng): "Vườn của tôi" + badge số cây.
   - 3 ô **nhỏ** (ngang): "Việc hôm nay" (badge đỏ khi có việc) · "Thêm cây" ·
     "Cây đã xoá" (badge số cây đã ẩn).
4. **Widget thời tiết** — nhiệt độ, độ ẩm, lượng mưa, khuyến nghị tưới.

**Bảng điều khiển → API:**

| Thao tác | API |
|---|---|
| Mở màn hình / kéo xuống / nút ⟳ | `GET /api/v1/herbal-garden` · `GET /care-today` · `GET /weather` · `GET /deleted` |
| Bấm ô "Vườn của tôi" | → màn hình ① (không gọi API thêm) |
| Bấm ô "Việc hôm nay" | → màn hình ①b (không gọi API thêm) |
| Bấm ô "Thêm cây" | → màn hình ③ |
| Bấm ô "Cây đã xoá" | → màn hình ④ |

> Tất cả màn hình con dùng chung **1 `HerbalGardenController`** (đăng ký ở
> `lib/app.dart`) → quay lại màn hình cha là dữ liệu đã cập nhật, không tải lại.

### 3.1. MÀN HÌNH 1 — Vườn của tôi

**Bố cục (từ trên xuống):**

1. **Header gradient xanh** (`#1B4332`)
   - Tiêu đề "Vườn Dược Liệu" + ngày hôm nay (lấy từ `care.date`).
   - Nút 🗑 (thùng rác) → mở **Màn hình 4**, kèm badge số cây đã xoá.
   - Nút ⟳ → refresh toàn bộ.
   - Ô tìm kiếm: lọc theo tên thường / tên khoa học.
2. **Widget thời tiết** — nhiệt độ, độ ẩm, lượng mưa, khuyến nghị tưới
   (`can_tuoi` + `ly_do`), dự báo 3 ngày.
3. **Dải số liệu** — số cây trong vườn · số việc hôm nay · tổng kg đã thu.
4. **Section "Việc hôm nay"**
   - Chip tóm tắt: 💧 cần tưới · 🌾 thu hoạch · 📅 ngoài mùa · 📸 chụp ảnh.
   - Mỗi thẻ việc: icon + tiêu đề + mức độ ưu tiên + hướng dẫn + nút hành động.
5. **Section "Cây trong vườn"**
   - Thanh lọc: "Cần chăm sóc hôm nay" + 5 chip giai đoạn.
   - Grid 2 cột, mỗi thẻ cây: ảnh, badge giai đoạn, badge cần chăm sóc
     (viền đỏ), số ngày trồng, chip mùa vụ, số ảnh / số lần thu, tổng kg.

**Bảng điều khiển → API:**

| Thao tác | API |
|---|---|
| Mở màn hình (lần đầu) | `GET /api/v1/herbal-garden` · `GET /api/v1/herbal-garden/care-today` · `GET /api/v1/herbal-garden/weather` · `GET /api/v1/herbal-garden/deleted` |
| Kéo xuống / nút ⟳ | 3 API đầu (song song) |
| Tìm trong ô tìm kiếm | *Không gọi API* — lọc client-side |
| Chip lọc giai đoạn / cần chăm sóc | *Không gọi API* — lọc client-side |
| Bấm "Tưới xong" | `POST /api/v1/herbal-garden/{id}/water` |
| Bấm "Thu hoạch" | `POST /api/v1/herbal-garden/{id}/harvest` |
| Bấm 1 lựa chọn trong thẻ việc | `POST /api/v1/herbal-garden/{id}/task/dismiss` (kèm `choice_id`) |
| Bấm "Đã xong" | `POST /api/v1/herbal-garden/{id}/task/dismiss` |
| Bấm ⌄ trên thẻ việc / tên cây | Mở **Màn hình 2** |

> Sau **mọi** lệnh ghi, app tự gọi lại song song
> `GET /api/v1/herbal-garden` + `GET /api/v1/herbal-garden/care-today`
> để số liệu và thẻ việc luôn khớp với server (không cần kéo để refresh).

### 3.2. MÀN HÌNH 2 — Chi tiết cây

**Bố cục (cuộn dọc):**

1. **Hero** — ảnh cây (gradient phủ để dễ đọc chữ), nút quay lại, nút refresh,
   badge giai đoạn, badge số ngày trồng, tên thường + tên khoa học.
2. **Các banner cảnh báo** — `canh_bao` từ server (tự phân loại mức độ),
   cảnh báo loài độc (`toxic_lookalike`), cảnh báo đất (`soil_warning`).
3. **Đánh giá sinh trưởng** — `growth`: mức độ, nhận diện, gợi ý xử lý.
4. **Thông tin dược liệu** — mô tả, công dụng, cách dùng, lưu ý.
5. **Mùa vụ & chu kỳ** — chip đúng mùa / ngoài mùa, nhóm cây, chu kỳ thu hoạch,
   kỳ cắt tỉa, kỳ thu hoạch kế tiếp.
6. **Thống kê vườn** — số ảnh, số lần thu, tổng sản lượng, lần tưới gần nhất,
   tổng lần tưới, loại đất, ngày chụp ảnh gần nhất.
7. **Nhật ký tiến độ** — dải ngang ảnh + nút "Thêm ảnh vào nhật ký".
8. **Sổ thu hoạch** — từng lần thu với chip chất lượng ("Đúng mùa · hoạt chất
   100%" / "Ngoài mùa · hoạt chất 60%") + nút "Ghi vào sổ thu hoạch".
9. **Lịch sử sinh trưởng** — timeline dọc 5 mốc.
10. **Vị trí** — các địa điểm GPS đã ghi.
11. **Ghi chú** — ghi chú cá nhân.
12. **3 ô thao tác** — Đã tưới · Đổi mốc · Thu hoạch.
13. **Nút "Xoá cây khỏi vườn"** (xoá mềm, có hộp thoại xác nhận).

**Bảng điều khiển → API:**

| Thao tác | API |
|---|---|
| Mở màn hình | `GET /api/v1/herbal-garden/{plant_id}` |
| Nút ⟳ | `GET /api/v1/herbal-garden/{plant_id}` |
| "Đã tưới" | `POST /api/v1/herbal-garden/{plant_id}/water` |
| "Đổi mốc" → chọn giai đoạn → nhập ghi chú | `POST /api/v1/herbal-garden/{plant_id}/stage` |
| "Thêm ảnh vào nhật ký" → chọn nguồn ảnh → nhập ghi chú | `POST /api/v1/herbal-garden/{plant_id}/photo` (multipart `file`) |
| "Ghi vào sổ thu hoạch" | `POST /api/v1/herbal-garden/{plant_id}/harvest` |
| "Xoá cây khỏi vườn" | `DELETE /api/v1/herbal-garden/{plant_id}` (xoá mềm) |
| Bấm 1 ảnh trong nhật ký | *Không gọi API* — mở dialog xem ảnh |

### 3.3. MÀN HÌNH 3 — Thêm cây

Form 4 bước nằm trong **1 trang cuộn** (không phải wizard nhiều màn hình),
mỗi bước là 1 card có số thứ tự.

| Bước | Nội dung | API |
|---|---|---|
| **1. Chọn loài cây** | a) Chụp ảnh → nhận diện · b) Tìm theo tên trong danh mục | `POST /predict` (multipart) hoặc `GET /api/v1/plants/search?q=...` |
| **2. Thông tin trồng** | Ngày gieo (date picker) · giai đoạn hiện tại (5 chip) · ghi chú | — |
| **3. Đất & nơi trồng** | Gợi ý đất của hệ thống (nút "Dùng gợi ý này") · chẩn đoán bằng 2 triệu chứng · chọn loại đất & nơi trồng thủ công | `GET /api/v1/herbal-garden/soil-options` · `GET /api/v1/herbal-garden/soil-suggestion?ten_label=...` |
| **4. Vị trí trồng** | Nút "Lấy vị trí hiện tại" (GPS) — có thể bỏ qua | — |
| **Lưu** | Gửi toàn bộ form | `POST /api/v1/herbal-garden` |

**Ghi chú quan trọng:**

* Ảnh được **nén trước khi gửi** (`compressImageForUpload` — max cạnh 1024px,
  JPEG quality 80) để không vượt giới hạn dung lượng của server.
* Khi có GPS, app gửi kèm `latitude`/`longitude`/`address_name` để server tính
  thời tiết đúng chỗ trồng.
* Nếu loài cây **đã có trong vườn**, server trả `409 Conflict` với `id` ở
  **top-level**. App hiện dialog "Loài này đã có trong vườn" (không crash).

### 3.4. MÀN HÌNH 4 — Cây đã xoá

* Banner giải thích: xoá trong app chỉ **ẩn** cây, dữ liệu vẫn giữ.
* Danh sách cây đã xoá: ảnh, tên, ngày xoá, chip giai đoạn, số ảnh.
* Nút ⟳ (restore) → `POST /api/v1/herbal-garden/{plant_id}/restore`.
* Trạng thái rỗng có thông điệp thân thiện + hướng dẫn.

| Thao tác | API |
|---|---|
| Mở màn hình / kéo để refresh | `GET /api/v1/herbal-garden/deleted` |
| Bấm ⟳ (khôi phục) | `POST /api/v1/herbal-garden/{plant_id}/restore` |

---

## 4. Bảng tra cứu nhanh 15 endpoint

| # | Method | Path | Mục đích | Dùng ở màn hình |
|---|---|---|---|---|
| 1 | GET | `/api/v1/herbal-garden` | Danh sách cây trong vườn | ⓪① |
| 2 | GET | `/api/v1/herbal-garden/care-today` | Việc chăm sóc hôm nay | ⓪①b |
| 3 | GET | `/api/v1/herbal-garden/weather` | Thời tiết + khuyến nghị tưới | ① |
| 4 | GET | `/api/v1/herbal-garden/{plant_id}` | Chi tiết 1 cây | ② |
| 5 | GET | `/api/v1/herbal-garden/deleted` | Cây đã xoá | ④ |
| 6 | GET | `/api/v1/herbal-garden/soil-options` | Danh mục đất + câu hỏi chẩn đoán | ③ |
| 7 | GET | `/api/v1/herbal-garden/soil-suggestion` | Gợi ý đất cho 1 loài | ③ |
| 8 | POST | `/api/v1/herbal-garden` | Thêm cây | ③ |
| 9 | POST | `/api/v1/herbal-garden/{plant_id}/stage` | Đổi mốc giai đoạn | ② |
| 10 | POST | `/api/v1/herbal-garden/{plant_id}/water` | Ghi nhận đã tưới | ①② |
| 11 | POST | `/api/v1/herbal-garden/{plant_id}/photo` | Thêm ảnh nhật ký | ② |
| 12 | POST | `/api/v1/herbal-garden/{plant_id}/harvest` | Ghi sổ thu hoạch | ①② |
| 13 | POST | `/api/v1/herbal-garden/{plant_id}/task/dismiss` | Gỡ thẻ việc / ghi lựa chọn | ① |
| 14 | DELETE | `/api/v1/herbal-garden/{plant_id}` | Xoá cây (mềm) | ② |
| 15 | POST | `/api/v1/herbal-garden/{plant_id}/restore` | Khôi phục cây đã xoá | ④ |

Hỗ trợ thêm: `GET /api/v1/plants/search?q=...` (tìm loài) và
`POST /predict` (nhận diện ảnh) — dùng ở bước 1 của màn hình ③.

---

## 5. Quy tắc xử lý lỗi

| Mã HTTP | Nguyên nhân | FE xử lý |
|---|---|---|
| 200 / 201 | Thành công | Hiện SnackBar xanh + tải lại dữ liệu liên quan |
| 404 | Không tìm thấy cây / loài | Hiện banner đỏ kèm nút "Thử lại" (không crash) |
| 409 | Cây đã có trong vườn | Dialog thân thiện "Loài này đã có trong vườn" |
| 413 | Ảnh quá lớn | Hiện thông báo lỗi từ server (ảnh đã được nén sẵn) |
| 422 | Sai định dạng dữ liệu | Đọc `detail[0].loc` + `detail[0].msg` → hiện lỗi cụ thể |
| 5xx / timeout | Server lỗi hoặc mạng chậm | SnackBar đỏ + banner lỗi có nút "Thử lại" |

Nguyên tắc chung:

* **Không bao giờ crash.** Mọi lời gọi mạng đều bọc `try/catch` và quy đổi
  thành `GardenApiException` với thông báo tiếng Việt.
* **Không tự diễn giải lại nội dung server.** Mọi chuỗi tiếng Việt do backend
  viết sẵn (`title`, `description`, `huong_dan`, `ly_do`, `message`…) được hiển
  thị **nguyên văn** để app không nói khác với server.
* Mỗi vùng dữ liệu có **trạng thái riêng** (`loading` / `ready` / `error`) —
  lỗi thời tiết không làm hỏng danh sách cây và ngược lại.

---

## 6. Quy tắc hiển thị

| Khái niệm | Nguồn | Màu / kiểu hiển thị |
|---|---|---|
| Ưu tiên việc | `priority` | high → đỏ `#D64545` (viền đỏ trên thẻ) · normal → cam `#E8A33D` · low → xám |
| Giai đoạn | `stage` | gieo_trong → xanh lá · dang_lon → cam · ra_hoa → hồng · san_sang_thu_hoach → cam đậm · đã thu hoạch → xám |
| Mùa vụ | `season.in_season` | Đúng mùa → xanh `#52B788` · Ngoài mùa → cam `#E2703A` · Chưa có lịch → xám |
| Loại đất | `soil.soil_type` | Nhãn tiếng Việt do server cung cấp (`soil_label`) |
| Cần chăm sóc | `can_cham_soc_hom_nay` | Viền đỏ quanh thẻ cây + badge tròn góc trên |

---

## 7. Chạy thử

```bash
# Chạy với vườn mẫu dùng chung (mặc định)
flutter run

# Chạy với vườn riêng theo tài khoản đang đăng nhập
flutter run --dart-define=GARDEN_PER_USER=true

# Trỏ sang server khác
flutter run --dart-define=DETECT_URL=http://10.0.2.2:8000
```

> Android: `usesCleartextTraffic="true"` đã được bật trong `AndroidManifest.xml`
> nên giao tiếp HTTP với Cloud Server hoạt động bình thường.
> Cần cấp quyền vị trí (`ACCESS_FINE_LOCATION`) để tính thời tiết theo GPS;
> nếu từ chối, app vẫn chạy và dùng vùng mặc định của server.

### 7.1. Yêu cầu môi trường build Android (Flutter 3.50)

| Thành phần | Yêu cầu | Ghi chú |
|---|---|---|
| Flutter SDK | 3.50.0 | `D:\SDK_Flutter\flutter_windows_3.50.0-stable\flutter` |
| Gradle | **≥ 9.3.1** (project dùng 9.5.0) | Flutter 3.50 **từ chối** Gradle 8.x — đây là lý do build fail với `Gradle version (8.12.0) is lower than Flutter's minimum supported version of 9.3.1` |
| Android Gradle Plugin | 9.3.1 | Nâng từ 8.7.3 |
| Kotlin plugin | 2.4.20 | Nâng từ 2.3.0 |
| JDK | 17 hoặc 21 | **Không dùng JDK 25** — Gradle 8.x không hỗ trợ; Android Studio đi kèm JBR 25 nên cần chỉ định JDK |

> Nếu Android Studio báo lỗi `Java version 25.0.2 is incompatible with Gradle`:
> 1. `flutter config --jdk-dir="C:\Program Files\Java\jdk-21"` (đã đặt trên máy này), hoặc
> 2. Trong Android Studio: **Settings → Build, Execution, Deployment → Build Tools →
>    Gradle → Gradle JDK** → chọn JDK 21.

---

## 8. Ghi chú kỹ thuật

* **State:** một `ChangeNotifier` duy nhất (`HerbalGardenController`) được đăng ký
  trong `MultiProvider` ở `lib/app.dart` → mọi màn hình đọc chung 1 nguồn dữ
  liệu, không phải gọi API lặp lại.
* **Lọc & tìm kiếm** thực hiện **client-side** trên dữ liệu đã tải → không
  tạo tải lên server, phản hồi tức thì.
* **Ảnh:** luôn nén trước khi upload (`core/image_compress.dart`).
* **Xoá:** mặc định **xoá mềm** (server tự đánh dấu `deleted_at`); cây có thể
  khôi phục tại màn hình ④. Không dùng `?hard=true` trong UI.
* **Màu:** toàn bộ dùng `AppColors` (`primary #1B4332`, `accent #40916C`,
  `success #52B788`) để đồng bộ với Home / Account / Map.

---

## 9. Phụ lục QA — hợp đồng API đã kiểm thử

Các endpoint dưới đây đã được gọi trực tiếp lên Cloud Server
`http://222.255.184.116` (mode demo, `?uid=demo`) và **response khớp 100%**
với model Dart trong `models/garden_models.dart`:

| Endpoint | HTTP | Ghi chú response quan trọng |
|---|---|---|
| `GET /` | 200 | `items[]` + `total` |
| `GET /care-today` | 200 | `tasks[]`, `uu_tien[]`, `counters` |
| `GET /weather` | 200 | `can_tuoi`, `ly_do`, `forecast[]` |
| `GET /soil-options` | 200 | `loai_dat[]`, `cau_hoi[]`, `mo_ta[]` |
| `GET /soil-suggestion` | 200 | `de_xuat` + `ly_do` |
| `GET /{id}` | 200 | đầy đủ `growth`, `botanical`, `harvest_history`, `timeline`, `gps` |
| `POST /` | 200/201 | **409 Conflict** trả `id` ở top-level → app hiện dialog trùng loài |
| `POST /{id}/stage` | 200 | `stage_history[]` mới nhất nằm cuối mảng |
| `POST /{id}/water` | 200 | `last_watered_at`, `watering_count` |
| `POST /{id}/harvest` | 200 | cảnh báo `ngoai_mua` (ngoài mùa), `active_ratio` |
| `POST /{id}/task/dismiss` | 200 | `choice_label`, `van_con_hien_thi` |
| `DELETE /{id}` | 200 | `status: deleted` (xoá mềm) |
| `GET /deleted` | 200 | `items[]` cây đã xoá |
| `POST /{id}/restore` | 200 | `status: restored` |
| `POST /{id}/photo` | 200 | multipart `file`; nhật ký ảnh cập nhật |

### 9.1. Dọn dẹp dữ liệu test

Sau khi test, dữ liệu demo đã được đưa về trạng thái gần như seed gốc:

* Cây `Bạch hoa xà` (`6ae6018c2c14a854ada05bae`): đã **xoá mềm → khôi phục**
  → `GET /deleted` trả `total: 0`.
* Cây `Rau má` (`6ae6018c2c14a854ada05bab`): stage đã trả về `dang_lon`.
* Các file JSON tạm trong `%TEMP%` đã xoá.

> Ghi chú: lịch sử giai đoạn và sổ thu hoạch vẫn giữ các mốc đã ghi trong lúc
> test (server không có endpoint xoá lịch sử). Đây là dữ liệu demo nên không
> ảnh hưởng; nếu cần sạch tuyệt đối thì chạy lại `seed_demo.py --reset`
> trên Cloud Server.

### 9.2. Checklist trước khi bàn giao

- [x] Cú pháp Dart cân bằng ngoặc trên cả 12 file trong `features/herbal_garden/`
- [x] Không còn import tới code cũ (`lib/screens/garden/`, `lib/controllers/garden_notifier.dart`)
- [x] `lib/app.dart` đăng ký `HerbalGardenController`
- [x] `lib/screens/home_screen.dart` thẻ 3 trỏ tới `GardenHubScreen`
- [x] 15 endpoint đã kiểm thử contract trên Cloud Server
- [x] `flutter analyze` — 0 error, 0 warning (45 info deprecation `material.dart`)
- [x] `flutter test` — **64/64 test PASS** (28 API live + 26 widget UI + 10 unit)
- [x] `flutter build apk --debug` — **BUILD SUCCESSFUL** (sau khi sửa 2 lỗi Gradle bên dưới)
- [ ] Test upload ảnh thật (camera + thư viện) trên thiết bị
- [ ] Test trường hợp mất mạng / server timeout

### 9.3. Các lỗi Gradle đã phát hiện & sửa (Flutter 3.50 + AGP 9.3.1)

Bản build Android **trước đây không thành công** với 2 lỗi độc lập — cả hai đều
do plugin bên thứ ba dùng cấu hình Gradle cũ (AGP 7/8) trong khi project đã
nâng lên AGP 9.3.1 / Gradle 9.5. Đã sửa trong `android/build.gradle.kts`:

| # | Lỗi | Nguyên nhân | Cách sửa |
|---|---|---|---|
| 1 | `Inconsistent JVM Target Compatibility Between Java and Kotlin Tasks` (`compileDebugJavaWithJavac` 11 vs `compileDebugKotlin` 21) | `flutter_facebook_auth` không khai báo `kotlinOptions.jvmTarget` → Kotlin lấy mặc định 21 còn Java là 11 | `gradle.projectsEvaluated` → đọc `sourceCompatibility` của từng module và đặt `jvmTarget` Kotlin bằng đúng giá trị đó |
| 2 | `AAR metadata check failed ... requires compile against version 34 or later` (`:app_settings` compiled against android-33) | Plugin khai báo `compileSdk` cũ (33/34/35) trong khi androidx mới yêu cầu ≥ 34 | `afterEvaluate` → nâng `compileSdk` của mọi module lên tối thiểu 36 |

> ⚠️ `afterEvaluate` phải chạy **trước** khi AGP khoá DSL, còn `jvmTarget` phải
> đặt **sau** `projectsEvaluated` (vì chính plugin set trong `afterEvaluate` của
> nó → set sớm sẽ bị ghi đè). Sai thứ tự sẽ ra `AgpDslLockedException`.

### 9.4. Các lỗi đã phát hiện & sửa trong đợt kiểm thử giao diện

Bộ test giao diện chạy ở khung **393 × 851** (Pixel 5) thay vì khung mặc định
800 × 600 của `flutter_test` — nhờ vậy mới phát hiện được các lỗi tràn bố cục
("rối mắt") mà bản build thật trên điện thoại sẽ gặp:

| # | Vấn đề | Sửa |
|---|---|---|
| 1 | Chip nhãn dài (`"Đất ẩm, giữ nước lâu"`) tràn 111px sang phải trong ô Grid | `GardenChip` bọc nhãn trong `LayoutBuilder` + `Flexible` + `TextOverflow.ellipsis` |
| 2 | Nút chính (`"Chọn loài cây để tiếp tục"`) tràn 58px | `GardenPrimaryButton`/`GardenOutlineButton`: nhãn `maxLines: 1` + `ellipsis` |
| 3 | Thẻ cây tràn 49px theo chiều dọc trong ô Grid (cao 253px) | Grid dùng `mainAxisExtent: 300` thay cho `childAspectRatio` (mọi thẻ cùng cao, đều nhau); ảnh thu nhỏ 118 → 104 |
| 4 | Màn hình chi tiết cây crash: `A RenderSliverToBoxAdapter expected a child of type RenderBox` | `_buildHero()` trả về `Stack` thay vì `SliverToBoxAdapter` (bọc ở `_buildContent()`) |
| 5 | Tìm kiếm trong vườn không bỏ dấu → gõ `"bac"` không ra `"Bạc hà"` | `filteredPlants` dùng `VietnameseSearchHelper.normalize/tokenize` (đồng nhất với trang Danh mục) |
| 6 | Endpoint con (`/stage`, `/water`, `/harvest`, `/task/dismiss`, `/photo`) trả 404 khi dùng uid không phải `demo` | Thêm `uid` vào query string của các endpoint này |

> Ghi chú: trên thẻ cây, khoảng thời gian mùa vụ (`"Tháng 3 - Tháng 10"`) được
> đưa xuống **dòng riêng** bên dưới chip mùa vụ ngắn (`"Đúng mùa"`/`"Ngoài mùa"`)
> để chip không bị tràn và bố cục vẫn rõ ràng.

