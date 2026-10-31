// lib/services/history_service.dart
//
// Service lấy LỊCH SỬ ảnh người dùng.
//
// API contract (mới):
//   GET {MAP_USER_URL}/api/v1/user-plants
//   Headers: Authorization: Bearer <JWT>
//
// Response (200 OK) — ví dụ:
//   {
//     "id": "671bea1f2e987c001a1234S6",
//     "common_name": "Gỏi lá vú ở rừng",
//     "image_url": "https://res.cloudinary.com/.../img.jpg",
//     "thumbnail_url": "https://res.cloudinary.com/.../thumb.jpg",
//     "lat": 21.0285,
//     "lng": 105.8542,
//     "created_at": "2026-10-26T02:09:00Z"
//   }
//
// Ghi chú: backend có thể trả về list trực tiếp hoặc bọc trong { "data": [...] }.
// Ảnh trả về là URL tuyệt đối (Cloudinary) nên không cần nối base URL.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:thunghiem1/config/app_config.dart';
import 'package:thunghiem1/models/image_response.dart';
import 'package:thunghiem1/services/secure_storage_service.dart';

class HistoryService {
  HistoryService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _baseUrl => AppConfig.historyUserUrl;

  /// JWT backend (HS256) từ SecureStorage.
  Future<String?> _backendJwt() async {
    try {
      return await SecureStorageService().readToken();
    } catch (_) {
      return null;
    }
  }

  /// Lấy danh sách ảnh đã chụp (mới nhất trước).
  ///
  /// Ném [Exception] với message tiếng Việt khi lỗi mạng / server.
  /// Trả về list rỗng nếu chưa đăng nhập.
  Future<List<ImageResponse>> getHistory({int limit = 100}) async {
    final token = await _backendJwt();
    if (token == null || token.isEmpty) {
      throw Exception('Bạn cần đăng nhập để xem lịch sử.');
    }

    final uri = Uri.parse(
      '$_baseUrl/api/v1/user-plants',
    ).replace(queryParameters: {'limit': limit.toString()});

    final response = await _client
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Không tải được lịch sử (${response.statusCode}).');
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes));

    final List<dynamic> raw = switch (decoded) {
      List l => l,
      Map m when m.containsKey('data') => m['data'] as List? ?? [],
      Map m when m.containsKey('plants') => m['plants'] as List? ?? [],
      Map m when m.containsKey('items') => m['items'] as List? ?? [],
      _ => [],
    };

    final images = raw
        .whereType<Map<String, dynamic>>()
        .map(ImageResponse.fromJson)
        .where((i) => i.imageUrl.isNotEmpty)
        .toList();

    // Mới nhất trước.
    images.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return images;
  }

  void dispose() => _client.close();
}
