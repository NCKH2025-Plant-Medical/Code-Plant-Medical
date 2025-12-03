import os

folder = "AI model/dataset_processed"

print("Đang đếm số lượng ảnh trong mỗi lớp...")

for class_name in os.listdir(folder):
    class_path = os.path.join(folder, class_name)

   
    if os.path.isdir(class_path):
    
        image_count = 0
        
       
        for filename in os.listdir(class_path):
           
            if filename.lower().endswith((".png", ".jpg", ".jpeg")):
                image_count += 1
        
       
        print(f"Lớp '{class_name}' có: {image_count} ảnh")