import mysql.connector

# Tao cau hinh ket noi database
def get_db_connection():
    try:
        connection = mysql.connector.connect(
            host = "localhost",
            user = "root",
            password = "minhtriet",
            database = "plant_project"
        )
        return connection
    except mysql.connector.Error as err:
        print (f"Connect Database Error {err}")
        return None

# Ham lay thong tin cay dua tren lable
def get_plant_info_by_label(predicted_class):
    con = get_db_connection()
    if con is None:
        return None

    cursor = con.cursor(dictionary=True)

    #Cau lenh truy van (Ten truy van phai khop)
    # Câu lệnh truy vấn mới (Chỉ lấy các cột cần thiết)
    sql = "SELECT ten_cay, ten_quocte, thong_tin, cong_dung, cach_dung, luu_y FROM plant_medical WHERE ten_lable = %s"

    cursor.execute(sql, (predicted_class,)) # Truyền label_name vào chỗ %s
    #execute() → gửi SQL sang MySQL
    # (label_name,) : la tuple phai co dau , de mysql truyen nhieu gia tri

    result = cursor.fetchone() # Lấy 1 kết quả tìm được 
    # fetchone() la lay dong dau tien 
    
    cursor.close()
    con.close()
    
    if result is not None:
        formatted_result = {
            "Tên cây": result.get("ten_cay"),
            "Tên quốc tế": result.get("ten_quocte"),
            "Thông tin": result.get("thong_tin"),
            "Công dụng": result.get("cong_dung"),
            "Cách dùng": result.get("cach_dung"),
            "Lưu ý": result.get("luu_y")
        }
        return formatted_result 
    
    return None
