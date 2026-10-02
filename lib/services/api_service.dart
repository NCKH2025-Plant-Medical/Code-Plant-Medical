import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:thunghiem1/config/app_config.dart';

class ApiService {
  final String baseUrl = AppConfig.detectUrl;
  final Map<String, Future<Map<String, dynamic>>> _detailCache = {};

  Future<String?> _getIdToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      return await user.getIdToken();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> predictImage(String imagePath) async {
    // Kiểm tra file tồn tại trước khi upload
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('Không tìm thấy file ảnh. Vui lòng thử lại.');
    }

    final uri = Uri.parse('$baseUrl/predict');
    final request = http.MultipartRequest('POST', uri);

    // Xác định content-type từ extension thực tế
    final ext = imagePath.toLowerCase().split('.').last;
    final MediaType mediaType;
    switch (ext) {
      case 'png':
        mediaType = MediaType('image', 'png');
        break;
      case 'webp':
        mediaType = MediaType('image', 'webp');
        break;
      default:
        // jpeg hoặc không rõ → octet-stream an toàn hơn gán sai
        mediaType = MediaType('image', 'jpeg');
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imagePath,
        contentType: mediaType,
      ),
    );

    // Gắn Authorization nếu đã login; nếu chưa vẫn gọi bình thường
    final token = await _getIdToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final streamedResponse = await request
        .send()
        .timeout(const Duration(seconds: 30));

    final bodyBytes = await streamedResponse.stream.toBytes();
    final responseBody = utf8.decode(bodyBytes);

    if (streamedResponse.statusCode == 200) {
      final decoded = json.decode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Máy chủ trả về định dạng không hợp lệ. Vui lòng thử lại.');
      }
      return decoded;
    } else {
      throw Exception(
        'Nhận diện thất bại (${streamedResponse.statusCode}). Vui lòng thử lại.',
      );
    }
  }

  Future<Map<String, dynamic>> getPlantDetail(String plantId) {
    if (_detailCache.containsKey(plantId)) {
      return _detailCache[plantId]!;
    }

    final future = _fetchPlantDetail(plantId);
    _detailCache[plantId] = future;

    future.catchError((_) {
      _detailCache.remove(plantId);
      return <String, dynamic>{};
    });

    return future;
  }

  Future<Map<String, dynamic>> _fetchPlantDetail(String plantId) async {
    final uri = Uri.parse('$baseUrl/api/v1/plants/$plantId');

    final token = await _getIdToken();
    final headers = <String, String>{};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Không tải được thông tin cây (${response.statusCode}).');
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Dữ liệu cây không hợp lệ. Vui lòng thử lại.');
    }
    return decoded;
  }
  /// Live search cây thuốc: GET /api/v1/plants/search?q=...&limit=...
  /// Trả về: { "query": str, "total": int, "results": [ {...}, ... ] }
  Future<Map<String, dynamic>> searchPlants(String query, {int limit = 10}) async {
    final uri = Uri.parse('$baseUrl/api/v1/plants/search').replace(
      queryParameters: {'q': query, 'limit': limit.toString()},
    );

    final token = await _getIdToken();
    final headers = <String, String>{};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Tìm kiếm thất bại (${response.statusCode}).');
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Dữ liệu tìm kiếm không hợp lệ.');
    }
    return decoded;
  }

  /// Lấy danh sách gợi ý ngẫu nhiên bằng cách tìm kiếm các chữ cái ngắn.
  Future<List<Map<String, dynamic>>> getRandomSuggestions({int limit = 8}) async {
    // Chọn một chữ cái ngẫu nhiên để lấy gợi ý đa dạng
    final seeds = ['a', 'b', 'c', 't', 'n', 'h', 'l', 'm'];
    seeds.shuffle();
    final seed = seeds.first;

    final result = await searchPlants(seed, limit: limit);
    final raw = result['results'];
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }
}