// lib/services/user_plant_api_service.dart
//
// Service gọi API cây cá nhân (MongoDB):
//   POST {MAP_USER_URL}/api/v1/user-plants   → lưu cây mới (multipart)
//   GET  {MAP_USER_URL}/api/v1/user-plants   → danh sách cây của user
//
// Hợp đồng POST (FormData):
//   image          : file ảnh (đường dẫn thiết bị)
//   plant_id       : ID cây trong hệ thống (nếu có)
//   common_name    : tên cây
//   scientific_name: tên khoa học
//   confidence     : độ tin cậy nhận diện (0..100)
//   latitude       : vĩ độ lúc chụp
//   longitude      : kinh độ lúc chụp
//   notes          : ghi chú (tuỳ chọn)
//
// Mọi lỗi đều được ném ra dưới dạng Exception có message tiếng Việt để UI
// hiển thị được trực tiếp.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:thunghiem1/config/app_config.dart';
import 'package:thunghiem1/models/user_plant.dart';
import 'package:thunghiem1/services/secure_storage_service.dart';

class UserPlantApiService {
  UserPlantApiService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  String get _baseUrl => AppConfig.mapUserUrl;

  static const _timeout = Duration(seconds: 30);

  /// JWT backend (HS256) từ SecureStorage.
  Future<String?> _backendJwt() async {
    try {
      return await SecureStorageService().readToken();
    } catch (_) {
      return null;
    }
  }

  // ── POST: lưu cây mới ────────────────────────────────────────────────────

  /// Lưu cây của user kèm tọa độ GPS lúc chụp.
  ///
  /// Trả về [UserPlant] đã lưu (id từ backend).
  /// Ném [Exception] với message tiếng Việt khi thất bại.
  Future<UserPlant> saveUserPlant({
    required String imagePath,
    required String name,
    String? plantId,
    String? scientificName,
    double? confidence,
    double? latitude,
    double? longitude,
    String? notes,
  }) async {
    final token = await _backendJwt();
    if (token == null || token.isEmpty) {
      throw Exception('Bạn cần đăng nhập để lưu cây vào bản đồ.');
    }

    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('Không tìm thấy ảnh để lưu.');
    }

    final uri = Uri.parse('$_baseUrl/api/v1/user-plants');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    // Ảnh — content-type suy ra từ extension.
    final ext = imagePath.toLowerCase().split('.').last;
    final MediaType mediaType = switch (ext) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        imagePath,
        contentType: mediaType,
      ),
    );

    // Các field text.
    void addField(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        request.fields[key] = value.trim();
      }
    }

    addField('plant_id', plantId);
    addField('common_name', name);
    addField('name', name);
    addField('scientific_name', scientificName);
    addField('confidence', confidence?.toStringAsFixed(2));
    addField('latitude', latitude?.toStringAsFixed(6));
    addField('longitude', longitude?.toStringAsFixed(6));
    addField('notes', notes);

    final streamed = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 201 || response.statusCode == 200) {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return UserPlant.fromJson(data);
        }
        return UserPlant.fromJson(decoded);
      }
      throw Exception('Phản hồi lưu cây không hợp lệ.');
    }

    if (response.statusCode == 401) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }

    throw Exception(
      'Lưu cây thất bại (${response.statusCode}). Vui lòng thử lại.',
    );
  }

  // ── GET: danh sách cây của user ─────────────────────────────────────────

  /// Lấy danh sách cây cá nhân (dùng cho màn hình chi tiết cây của user).
  Future<List<UserPlant>> listUserPlants() async {
    final token = await _backendJwt();
    if (token == null || token.isEmpty) return [];

    final uri = Uri.parse('$_baseUrl/api/v1/user-plants');
    final response = await _client
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) return [];

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    final List<dynamic> raw = switch (decoded) {
      List l => l,
      Map m when m.containsKey('data') => m['data'] as List? ?? [],
      Map m when m.containsKey('plants') => m['plants'] as List? ?? [],
      _ => [],
    };

    return raw
        .whereType<Map<String, dynamic>>()
        .map(UserPlant.fromJson)
        .where((p) => p.id.isNotEmpty)
        .toList();
  }

  void dispose() => _client.close();
}
