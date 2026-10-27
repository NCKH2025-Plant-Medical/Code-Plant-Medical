import sys
import os

# Đảm bảo import được API
sys.stdout.reconfigure(encoding='utf-8')
sys.path.append(r"c:\Users\LAPTOP\Visual_workspace\NCKH\API")
import database

def test_search_cases():
    print("==================================================")
    print("BẮT ĐẦU CHẠY UNIT TEST TÍNH NĂNG TÌM KIẾM CÂY THUỐC")
    print("==================================================")

    # 1. Test "bạc hà" -> Đúng 1 kết quả: Bạc hà
    res1 = database.search_plants("bạc hà")
    assert len(res1) == 1, f"Test 1 Thất bại: Mong muốn 1 kết quả, nhận được {len(res1)}"
    assert res1[0]["ten_cay"] == "Bạc hà" or res1[0]["ten_label"] == "Bac_ha", f"Sai cây: {res1[0]}"
    print("✅ TEST 1: 'bạc hà' -> 1 kết quả chính xác: Bạc hà (PASS)")

    # 2. Test "bac ha" -> Đúng 1 kết quả: Bạc hà
    res2 = database.search_plants("bac ha")
    assert len(res2) == 1, f"Test 2 Thất bại: Mong muốn 1 kết quả, nhận được {len(res2)}"
    assert res2[0]["ten_cay"] == "Bạc hà" or res2[0]["ten_label"] == "Bac_ha", f"Sai cây: {res2[0]}"
    print("✅ TEST 2: 'bac ha' -> 1 kết quả chính xác: Bạc hà (PASS)")

    # 3. Test "BAC HA" -> Đúng 1 kết quả: Bạc hà
    res3 = database.search_plants("BAC HA")
    assert len(res3) == 1, f"Test 3 Thất bại: Mong muốn 1 kết quả, nhận được {len(res3)}"
    assert res3[0]["ten_cay"] == "Bạc hà" or res3[0]["ten_label"] == "Bac_ha", f"Sai cây: {res3[0]}"
    print("✅ TEST 3: 'BAC HA' -> 1 kết quả chính xác: Bạc hà (PASS)")

    # 4. Test "  Bạc Hà  " -> Đúng 1 kết quả: Bạc hà
    res4 = database.search_plants("  Bạc Hà  ")
    assert len(res4) == 1, f"Test 4 Thất bại: Mong muốn 1 kết quả, nhận được {len(res4)}"
    assert res4[0]["ten_cay"] == "Bạc hà" or res4[0]["ten_label"] == "Bac_ha", f"Sai cây: {res4[0]}"
    print("✅ TEST 4: '  Bạc Hà  ' (khoảng trắng thừa) -> 1 kết quả chính xác: Bạc hà (PASS)")

    # 5. Test "bac" -> Danh sách gợi ý tối đa 5 kết quả, trong đó có Bạc hà (ưu tiên cao nhất)
    res5 = database.search_plants("bac")
    assert 1 <= len(res5) <= 5, f"Test 5 Thất bại: Số kết quả phải từ 1 đến 5, nhận được {len(res5)}"
    plant_names = [r["ten_cay"] for r in res5]
    plant_labels = [r["ten_label"] for r in res5]
    assert "Bạc hà" in plant_names or "Bac_ha" in plant_labels, f"Không tìm thấy Bạc hà trong gợi ý: {plant_names}"
    assert res5[0]["ten_label"] == "Bac_ha", f"Bạc hà phải đứng đầu gợi ý khớp tiền tố: {plant_names}"
    print(f"✅ TEST 5: 'bac' (gõ thiếu) -> {len(res5)} gợi ý, Bạc hà đứng đầu (PASS): {plant_names}")

    # 6. Test Alias: "diệp hạ châu" / "dia ha chau" -> Chó đẻ răng cưa
    res6 = database.search_plants("diệp hạ châu")
    assert len(res6) == 1 and res6[0]["ten_label"] == "Cho_de_rang_cua"
    print("✅ TEST 6: 'diệp hạ châu' (alias) -> 1 kết quả: Chó đẻ răng cưa (PASS)")

    # 7. Test Alias: "hoa cúc" -> Cúc hoa
    res7 = database.search_plants("hoa cúc")
    assert len(res7) == 1 and res7[0]["ten_label"] == "Hoa_cuc"
    print("✅ TEST 7: 'hoa cúc' (alias) -> 1 kết quả: Cúc hoa (PASS)")

    print("==================================================")
    print("TẤT CẢ UNIT TESTS ĐỀU ĐẠT CHUẨN 100%!")
    print("==================================================")

if __name__ == "__main__":
    test_search_cases()
