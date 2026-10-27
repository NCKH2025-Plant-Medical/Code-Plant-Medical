# API/user_plants/cloudinary_utils.py
#
# Tích hợp Cloudinary để lưu trữ ảnh cây người dùng chụp.
#
# Thiết kế:
#   • Upload ảnh vào folder "plant_vision/user_plants/" trên Cloudinary.
#   • Tự động tạo thumbnail 300x300 bằng Cloudinary URL transformation
#     (không cần upload riêng — tiết kiệm quota).
#   • Trả về dict { image_url, thumbnail_url, public_id }.
#   • Tất cả lỗi đều raise Exception với thông điệp tiếng Việt rõ ràng.
#
# Biến môi trường bắt buộc (trong .env):
#   CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET

import os
import logging
from typing import Optional
import cloudinary
import cloudinary.uploader

logger = logging.getLogger(__name__)

# ── Cấu hình Cloudinary từ biến môi trường ───────────────────────────────────
cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
    secure=True,  # Luôn dùng HTTPS
)

# Folder lưu ảnh cây người dùng trên Cloudinary
_UPLOAD_FOLDER = "plant_vision/user_plants"

# Giới hạn kích thước file: 10 MB (bảo vệ khỏi ảnh quá lớn)
_MAX_FILE_SIZE_MB = 10


def build_thumbnail_url(secure_url: str, width: int = 300, height: int = 300) -> str:
    """
    Tạo URL thumbnail từ secure_url gốc bằng Cloudinary URL transformation.

    Cloudinary hỗ trợ resize ảnh tự động qua URL — không cần upload riêng.
    Ví dụ: .../upload/v123/path.jpg → .../upload/c_fill,w_300,h_300/v123/path.jpg

    Args:
        secure_url: URL HTTPS gốc từ Cloudinary upload.
        width:      Chiều rộng thumbnail (px).
        height:     Chiều cao thumbnail (px).

    Returns:
        URL thumbnail đã chèn transformation.
    """
    # Chèn transformation vào sau "/upload/"
    transform = f"c_fill,w_{width},h_{height},g_auto,q_auto,f_auto"
    return secure_url.replace("/upload/", f"/upload/{transform}/", 1)


def upload_plant_image(
    file_bytes: bytes,
    user_id: str,
    filename: Optional[str] = None,
) -> dict:
    """
    Upload ảnh cây lên Cloudinary (chạy đồng bộ trong ThreadPoolExecutor).

    Args:
        file_bytes: Nội dung file ảnh dạng bytes (từ UploadFile.read()).
        user_id:    ID người dùng — dùng để đặt tên file duy nhất.
        filename:   Tên file gốc (tùy chọn, chỉ dùng để log).

    Returns:
        dict với các key:
            - image_url (str):     URL ảnh gốc chất lượng cao (HTTPS).
            - thumbnail_url (str): URL ảnh thu nhỏ 300x300 (HTTPS).
            - public_id (str):     Khóa quản lý ảnh trên Cloudinary (dùng để xóa sau này).

    Raises:
        Exception: Khi Cloudinary từ chối upload hoặc cấu hình thiếu.
    """
    # Kiểm tra cấu hình trước khi upload
    if not os.getenv("CLOUDINARY_CLOUD_NAME"):
        raise Exception(
            "Chưa cấu hình Cloudinary. Kiểm tra biến CLOUDINARY_CLOUD_NAME trong .env."
        )

    # Kiểm tra kích thước file
    file_size_mb = len(file_bytes) / (1024 * 1024)
    if file_size_mb > _MAX_FILE_SIZE_MB:
        raise Exception(
            f"Ảnh quá lớn ({file_size_mb:.1f} MB). Giới hạn tối đa {_MAX_FILE_SIZE_MB} MB."
        )

    log_name = filename or "unknown"
    logger.info(
        "[Cloudinary] Đang upload ảnh '%s' (%.2f MB) cho user %s...",
        log_name, file_size_mb, user_id,
    )

    try:
        result = cloudinary.uploader.upload(
            file_bytes,
            folder=_UPLOAD_FOLDER,
            # Đặt public_id theo pattern user_id/timestamp để tránh trùng lặp
            # Cloudinary sẽ tự gán nếu không set (an toàn hơn)
            resource_type="image",
            # Tự động tối ưu chất lượng ảnh khi lưu
            quality="auto",
            fetch_format="auto",
            # Tag để quản lý hàng loạt sau này
            tags=[f"user_{user_id}", "plant_vision"],
        )
    except Exception as exc:
        logger.error(
            "[Cloudinary] Upload thất bại cho user %s: %s", user_id, exc
        )
        raise Exception(f"Không thể upload ảnh lên Cloudinary: {exc}") from exc

    secure_url: str = result["secure_url"]
    public_id: str = result["public_id"]

    thumbnail_url = build_thumbnail_url(secure_url, width=300, height=300)

    logger.info(
        "[Cloudinary] Upload thành công: public_id='%s'", public_id
    )

    return {
        "image_url": secure_url,
        "thumbnail_url": thumbnail_url,
        "public_id": public_id,
    }


def delete_plant_image(public_id: str) -> bool:
    """
    Xóa ảnh khỏi Cloudinary theo public_id.

    Dùng khi người dùng xóa bản ghi lịch sử nhận diện.

    Args:
        public_id: Định danh ảnh trên Cloudinary (lưu trong MongoDB khi upload).

    Returns:
        True nếu xóa thành công, False nếu ảnh không tồn tại hoặc lỗi.
    """
    try:
        result = cloudinary.uploader.destroy(public_id)
        success = result.get("result") == "ok"
        if success:
            logger.info("[Cloudinary] Đã xóa ảnh: public_id='%s'", public_id)
        else:
            logger.warning(
                "[Cloudinary] Xóa ảnh '%s' trả về: %s", public_id, result
            )
        return success
    except Exception as exc:
        logger.error("[Cloudinary] Lỗi xóa ảnh '%s': %s", public_id, exc)
        return False
