# 🔍 Thay Đổi Database Trên Cloud Server

So sánh schema **cũ** (mà bạn đang có trên local) với schema **hiện tại** trên cloud server (`222.255.184.116`).

---

## Tổng hợp nhanh

| Loại thay đổi | Chi tiết |
|---|---|
| Cột mới trong `plant_medical` | **1 cột**: `search_normalized` |
| Index mới trong `plant_medical` | **3 index**: 1 MUL trên `ten_cay`, 2 FULLTEXT |
| Bảng mới | **`search_keywords`** (20 rows seed data) |
| Migration scripts | 3 file trong `~/Source_Code/migrations/` |

---

## 1. Bảng `plant_medical` — Cột mới

### Cũ (local của bạn):
```
ID, ten_label, ten_cay, ten_quocte, thong_tin, cong_dung, cach_dung, luu_y, 
is_deleted, updated_at, anh_minh_hoa
```

### Mới (cloud server):
```diff
 ID, ten_label, ten_cay, ten_quocte, thong_tin, cong_dung, cach_dung, 
+search_normalized TEXT,       ← CỘT MỚI
 luu_y, is_deleted, updated_at, anh_minh_hoa
```

> **`search_normalized`** chứa nội dung `ten_cay + thong_tin + cong_dung + cach_dung` được chuyển thành **không dấu, viết thường**. Ví dụ cho cây Rau má:
> ```
> rau ma cay thao moc bo lan sat mat dat, re moc o cac mau than...
> ```
> Mục đích: cho phép tìm kiếm tiếng Việt không dấu bằng FULLTEXT search.

---

## 2. Bảng `plant_medical` — Index mới

| Index | Loại | Trên cột(s) | Mục đích |
|---|---|---|---|
| `idx_ft_search` | **FULLTEXT** | `ten_cay, thong_tin, cong_dung, cach_dung` | Tìm kiếm có dấu |
| `idx_ft_normalized` | **FULLTEXT** | `search_normalized` | Tìm kiếm không dấu |
| *(unnamed MUL)* | **INDEX** | `ten_cay` | Tra cứu nhanh theo tên cây |

---

## 3. Bảng mới: `search_keywords`

```sql
CREATE TABLE search_keywords (
    id                  INT           NOT NULL AUTO_INCREMENT,
    keyword             VARCHAR(120)  NOT NULL,  -- "hạ sốt" (có dấu)
    keyword_normalized  VARCHAR(120)  NOT NULL,  -- "ha sot" (không dấu)
    is_active           TINYINT(1)    DEFAULT 1, -- soft-hide
    created_at          TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY  uq_keyword (keyword),
    INDEX       idx_active_normalized (is_active, keyword_normalized)
);
```

### Data hiện có (20 cụm từ gợi ý):

| id | keyword | keyword_normalized |
|---|---|---|
| 1 | hạ sốt | ha sot |
| 2 | sốt cao | sot cao |
| 3 | sốt xuất huyết | sot xuat huyet |
| 4 | tiêu chảy | tieu chay |
| 5 | đau dạ dày | dau da day |
| 6 | viêm gan | viem gan |
| 7 | huyết áp cao | huyet ap cao |
| 8 | đái tháo đường | dai thao duong |
| 9 | ho khan | ho khan |
| 10 | ho có đờm | ho co dom |
| 11 | viêm họng | viem hong |
| 12 | mất ngủ | mat ngu |
| 13 | giải độc | giai doc |
| 14 | lợi tiểu | loi tieu |
| 15 | kháng khuẩn | khang khuan |
| 16 | chống viêm | chong viem |
| 17 | bổ gan | bo gan |
| 18 | điều hòa kinh nguyệt | dieu hoa kinh nguyet |
| 19 | tăng cường miễn dịch | tang cuong mien dich |
| 20 | chữa vết thương | chua vet thuong |

---

## 4. Ai thực hiện & Khi nào

Bạn của bạn đã viết **3 migration scripts** trong thư mục `~/Source_Code/migrations/`:

| File | Nội dung | Ngày tạo |
|---|---|---|
| `001_*.py` | Thêm cột `search_normalized`, tạo 2 FULLTEXT index, backfill data cho 30 cây | 29/09 |
| `002_*.py` | Thêm cột `is_deleted` + `updated_at` + index `idx_is_deleted` | 29/09 |
| `003_*.py` | Tạo bảng `search_keywords` + seed 20 cụm từ | 29/09 |

> [!NOTE]
> Tất cả thay đổi này phục vụ cho chức năng **Live Search** — cho phép user gõ triệu chứng/công dụng (có dấu hoặc không dấu) và nhận gợi ý + kết quả cây thuốc phù hợp.
