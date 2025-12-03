import os 
import cv2

folder = "AI model/dataset_processed"

for class_name in os.listdir(folder):
    class_path = os.path.join (folder,class_name)

    if os.path.isdir(class_path):

        count = 0

        for filename in os.listdir(class_path):
            
            if filename.endswith(".png") or filename.endswith(".jpg"):
                img_path = os.path.join(class_path,filename)

                img = cv2.imread(img_path,cv2.IMREAD_UNCHANGED)

                if img is None:
                    print("Khong mo duoc anh: ", img_path)
                    continue

             
                if img.shape[0] != 128 or img.shape[1] != 128:
                    print ("Anh sai kich thuoc: ", img_path, "->", img.shape)
                    continue

                print(f"Ảnh hợp lệ: {filename} ({class_name}) → {img.shape}")
                count += 1

        print(f"Tổng ảnh hợp lệ trong '{class_name}': {count}")