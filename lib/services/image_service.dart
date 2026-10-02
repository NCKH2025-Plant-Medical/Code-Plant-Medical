import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:thunghiem1/models/image_response.dart';

class ImageService {
  final String baseUrl;

  ImageService({required this.baseUrl});

  /// Lấy Bearer token nếu user đã đăng nhập; null nếu chưa.
  Future<String?> _getIdToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      return await user.getIdToken();
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _authHeaders(String? token) {
    if (token == null) return {};
    return {'Authorization': 'Bearer $token'};
  }

  Future<ImagesListResponse> getAllImages({
    int limit = 100,
    String orderBy = 'uploaded_at',
  }) async {
    final uri = Uri.parse('$baseUrl/api/images').replace(
      queryParameters: {
        'limit': limit.toString(),
        'order_by': orderBy,
      },
    );

    final token = await _getIdToken();
    final response = await http
        .get(uri, headers: _authHeaders(token))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final jsonData = json.decode(utf8.decode(response.bodyBytes));
      if (jsonData is! Map<String, dynamic>) {
        throw Exception('Dữ liệu lịch sử không hợp lệ.');
      }
      return ImagesListResponse.fromJson(jsonData);
    } else {
      throw Exception('Không tải được lịch sử ảnh (${response.statusCode}).');
    }
  }

  Future<UploadImageResponse> uploadImage({
    required String imagePath,
    String? capturedAt,
  }) async {
    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw Exception('Không tìm thấy file ảnh tại đường dẫn: $imagePath');
    }

    final uri = Uri.parse('$baseUrl/api/upload-image');
    final request = http.MultipartRequest('POST', uri);

    final token = await _getIdToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(
      await http.MultipartFile.fromPath('image', imagePath),
    );

    if (capturedAt != null && capturedAt.isNotEmpty) {
      request.fields['captured_at'] = capturedAt;
    }

    final streamedResponse = await request
        .send()
        .timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final jsonData = json.decode(utf8.decode(response.bodyBytes));
      if (jsonData is! Map<String, dynamic>) {
        throw Exception('Phản hồi upload không hợp lệ.');
      }
      return UploadImageResponse.fromJson(jsonData);
    } else {
      throw Exception('Upload thất bại (${response.statusCode}).');
    }
  }
}
