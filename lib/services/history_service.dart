import 'session_http_client.dart';
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
  HistoryService({http.Client? client, Future<String?> Function()? tokenReader})
    : _client = client ?? SessionHttpClient(),
      _tokenReader = tokenReader ?? SecureStorageService().readToken;

  final Future<String?> Function() _tokenReader;

  final http.Client _client;

  String get _baseUrl => AppConfig.historyUserUrl;

  /// JWT backend (HS256) từ SecureStorage.
  Future<String?> _backendJwt() async {
    try {
      return await _tokenReader();
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

    final images = <ImageResponse>[];
    var page = 1;
    while (true) {
      final uri = Uri.parse('$_baseUrl/api/v1/user-plants').replace(
        queryParameters: {
          'limit': limit.clamp(1, 100).toString(),
          'page': page.toString(),
        },
      );
      final response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401) {
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      }
      if (response.statusCode != 200) {
        throw Exception('Không tải được lịch sử (${response.statusCode}).');
      }
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      final dynamic entries = decoded is List
          ? decoded
          : decoded is Map
          ? decoded['items'] ?? decoded['data'] ?? decoded['plants']
          : null;
      if (entries is! List) {
        throw Exception('Phản hồi lịch sử không hợp lệ.');
      }
      images.addAll(
        entries
            .whereType<Map<String, dynamic>>()
            .map(ImageResponse.fromJson)
            .where((image) => image.imageUrl.isNotEmpty),
      );
      // API cũ không có phân trang; API hiện tại trả page/limit/total.
      if (decoded is! Map ||
          decoded['total'] is! num ||
          decoded['page'] is! num ||
          decoded['limit'] is! num ||
          entries.isEmpty ||
          (decoded['page'] as num) * (decoded['limit'] as num) >=
              (decoded['total'] as num)) {
        break;
      }
      if ((decoded['page'] as num).toInt() != page) {
        throw Exception('Phân trang lịch sử không hợp lệ.');
      }
      page++;
    }
    images.sort(
      (a, b) =>
          (b.savedAt ?? DateTime(1970)).compareTo(a.savedAt ?? DateTime(1970)),
    );
    return images;
  }

  Future<HistoryPage> getPage(int page) async {
    final token = await _backendJwt();
    if (token == null || token.isEmpty) throw Exception('Bạn cần đăng nhập.');
    final response = await _client
        .get(
          Uri.parse('$_baseUrl/api/v1/user-plants/history?page=$page&limit=6'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Không tải được lịch sử (${response.statusCode}).');
    }
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return HistoryPage(
      (data['items'] as List)
          .map((e) => ImageResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
      (data['total'] as num).toInt(),
    );
  }

  Future<int> deleteItems({Set<String>? ids}) async {
    if (ids != null && ids.isEmpty) return 0;
    final token = await _backendJwt();
    if (token == null || token.isEmpty) throw Exception('Bạn cần đăng nhập.');
    final response = await _client
        .post(
          Uri.parse(
            '$_baseUrl/api/v1/user-plants/${ids == null ? "delete-all" : "batch-delete"}',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: ids == null ? null : jsonEncode({'ids': ids.toList()}),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('Không xoá được lịch sử (${response.statusCode}).');
    }
    return (jsonDecode(utf8.decode(response.bodyBytes))['deleted_count'] as num)
        .toInt();
  }

  void dispose() => _client.close();
}

class HistoryPage {
  final List<ImageResponse> items;
  final int total;
  HistoryPage(this.items, this.total);
}
