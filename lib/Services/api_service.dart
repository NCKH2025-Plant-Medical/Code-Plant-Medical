import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:thunghiem1/config/app_config.dart';
import 'package:thunghiem1/Services/auth_service.dart'; // Import AuthService để lấy Token

class ApiService {
  final String baseUrl = AppConfig.baseUrl;
  final AuthService _authService = AuthService(); // Khởi tạo AuthService

  // Hàm 1: Gửi ảnh lên dự đoán (Đã bổ sung đính kèm Token)
  Future<Map<String, dynamic>> predictImage(String imagePath) async {
    // 1. Lấy Token của user đang đăng nhập
    String? token = await _authService.getIdToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/predict'),
    );

    // 2. Gắn Token vào Header của request
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(await http.MultipartFile.fromPath('file', imagePath));

    final response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      return json.decode(respStr);
    } else {
      throw Exception('Failed to get prediction');
    }
  }

  // Hàm 2 (MỚI): Lấy danh sách hình ảnh của người dùng
  Future<List<dynamic>> getUserImages() async {
    // 1. Lấy Token từ Firebase
    String? token = await _authService.getIdToken();

    if (token == null) {
      throw Exception('Người dùng chưa đăng nhập');
    }

    // 2. Gọi API GET kèm Token trong Header
    // Lưu ý: Đổi '/api/my-images' thành đúng endpoint trên server Flask của bạn
    final response = await http.get(
      Uri.parse('$baseUrl/api/my-images'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    // 3. Trả về kết quả
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Lỗi tải danh sách ảnh: ${response.statusCode}');
    }
  }
}