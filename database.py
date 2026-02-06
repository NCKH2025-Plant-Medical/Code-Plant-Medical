import mysql.connector

def get_db_connection():
    try:
        connection = mysql.connector.connect(
            host="localhost",
            user="root",
            password="vinhhau", # Nên chuyển cái này vào biến môi trường nếu làm sản phẩm thật
            database="plant_project"
        )
        return connection
    except mysql.connector.Error as err:
        print(f"Lỗi kết nối: {err}")
        return None

def get_plant_info_by_label(predicted_class):
    con = get_db_connection()
    if con is None:
        return None
    
    result = None
    cursor = None
    try:
        # dictionary=True giúp kết quả trả về dạng Dict, dễ truy cập (ví dụ: result['cong_dung'])
        cursor = con.cursor(dictionary=True)
        
        sql = "SELECT * FROM plant_medical WHERE ten_lable = %s"
        cursor.execute(sql, (predicted_class,))
        
        result = cursor.fetchone()
    except mysql.connector.Error as err:
        print(f"Lỗi truy vấn: {err}")
    finally:
        # Luôn đóng kết nối dù có lỗi hay không
        if cursor:
            cursor.close()
        if con.is_connected():
            con.close()
            
    return result