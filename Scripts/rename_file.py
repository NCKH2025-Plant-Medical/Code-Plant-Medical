import os
import cv2
import shutil
import numpy as np
import unicodedata
import re # Thêm thư viện này để lọc ký tự đặc biệt
from tqdm import tqdm  # Thêm thanh tiến trình siêu xịn

# Vì có ảnh có tên tiếng việt nên hàm ni dùng để chuẩn hóa lại cái tên chứ tên tiếng việt nó không nhận
def rename_file(text):
    # Xử lý riêng chữ Đ/đ trước vì Unicode NFD không tách được ký tự này
    text = text.replace('đ', 'd').replace('Đ', 'D')
    
    # Ép về ASCII và loại bỏ dấu tiếng Việt
    text = unicodedata.normalize('NFD', text).encode('ascii', 'ignore').decode('utf-8')
    
    # Thay thế khoảng trắng và gạch ngang thành gạch dưới
    text = text.replace(" ", "_").replace("-", "_")
    
    # Xóa TẤT CẢ ký tự đặc biệt, chỉ giữ lại chữ, số và gạch dưới
    text = re.sub(r'[^a-zA-Z0-9_]', '', text)
    
    # Giới hạn 50 ký tự và xóa gạch dưới thừa ở cuối (nếu có)
    return text[:50].strip('_')