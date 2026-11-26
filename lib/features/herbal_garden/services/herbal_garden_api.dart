// lib/features/herbal_garden/services/herbal_garden_api.dart
//
// Lớp gọi API "Vườn Dược Liệu" trên Cloud Server.
//
// Base URL lấy từ [AppConfig.gardenUrl] để cấu hình riêng cho vườn.
//
// Về xác thực: server đang chạy chế độ demo (`HERBAL_GARDEN_REQUIRE_AUTH`
// = false) nên `uid` trong query vẫn hoạt động. Tuy nhiên nếu người dùng đã
// đăng nhập, ta gửi kèm `Authorization: Bearer <token>`; server sẽ ưu tiên
// uid lấy từ token và BỎ QUA uid trong query.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:thunghiem1/config/app_config.dart';
import 'package:thunghiem1/features/herbal_garden/models/garden_models.dart';
import 'package:thunghiem1/services/secure_storage_service.dart';

/// Lỗi nghiệp vụ từ server — mang theo HTTP status để UI xử lý 401 riêng.
class GardenApiException implements Exception {
  final int statusCode;
  final String message;

  const GardenApiException(this.statusCode, this.message);

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Kết quả thêm cây — phân biệt "đã tồn tại" (409) với "lưu mới" (201).
class AddPlantResult {
  final String? id;
  final String message;
  final bool isDuplicate;
  final String? tenLabel;

  const AddPlantResult({
    this.id,
    required this.message,
    required this.isDuplicate,
    this.tenLabel,
  });
}

class HerbalGardenApi {
  HerbalGardenApi({
    http.Client? client,
    Duration? timeout,
    Duration? uploadTimeout,
  }) : _client = client ?? http.Client(),
       _timeout = timeout ?? _defaultTimeout,
       _uploadTimeout = uploadTimeout ?? _defaultUploadTimeout;

  final http.Client _client;
  final SecureStorageService _storage = SecureStorageService();

  /// Timeout cho request JSON (GET/POST thường).
  static const Duration _defaultTimeout = Duration(seconds: 20);

  /// Timeout cho request multipart (upload ảnh) — ảnh nén vẫn có thể lớn.
  static const Duration _defaultUploadTimeout = Duration(seconds: 40);

  /// Timeout áp dụng cho request JSON.
  final Duration _timeout;

  /// Timeout áp dụng cho upload ảnh.
  final Duration _uploadTimeout;

  // ── URL ──────────────────────────────────────────────────────────────────

  static String get baseUrl => AppConfig.gardenUrl;
  static String get _root => '$baseUrl/api/v1/herbal-garden';

  /// uid dùng cho chế độ demo (server chưa bắt buộc auth).
  static const String demoUid = 'demo';

  // ── Headers ─────────────────────────────────────────────────────────────

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await _readToken();
    return <String, String>{
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (json) 'Content-Type': 'application/json',
    };
  }

  Future<String?> _readToken() async {
    try {
      return await _storage.readToken();
    } catch (_) {
      return null;
    }
  }

  // ── Decode & error handling ─────────────────────────────────────────────

  /// Trích thông báo lỗi từ response.
  ///
  /// Server trả 2 dạng:
  /// - Lỗi nghiệp vụ → `detail` là **string**.
  /// - Lỗi validate FastAPI (422) → `detail` là **list of object**.
  static String extractError(dynamic detail) {
    if (detail is String && detail.trim().isNotEmpty) return detail;
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] != null) {
        final loc = first['loc'];
        final field = loc is List ? loc.join('.') : '';
        final msg = first['msg'].toString();
        return field.isEmpty ? msg : '$field: $msg';
      }
    }
    return 'Đã có lỗi xảy ra, vui lòng thử lại';
  }

  Map<String, dynamic> _decodeBody(http.Response res) {
    Map<String, dynamic> body = <String, dynamic>{};
    if (res.bodyBytes.isNotEmpty) {
      try {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {
        // Body không phải JSON → để xử lý theo status code.
      }
    }
    return body;
  }

  Map<String, dynamic> _decode(http.Response res) {
    final body = _decodeBody(res);
    if (res.statusCode >= 400) {
      throw GardenApiException(res.statusCode, extractError(body['detail']));
    }
    return body;
  }

  Never _throwNetwork() {
    throw const GardenApiException(
      0,
      'Không có kết nối tới máy chủ. Vui lòng kiểm tra mạng và thử lại.',
    );
  }

  // ── GET /api/v1/herbal-garden — danh sách cây ───────────────────────────

  Future<List<GardenPlantItem>> listGarden({String? uid}) async {
    final res = await _client
        .get(_uri('', uid), headers: await _headers())
        .timeout(_timeout)
        .catchError((_) => _throwNetwork());
    final j = _decode(res);
    return (j['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(GardenPlantItem.fromJson)
        .toList();
  }

  // ── GET /api/v1/herbal-garden/care-today ────────────────────────────────

  Future<CareToday> careToday({String? uid}) async {
    final res = await _client
        .get(_uri('/care-today', uid), headers: await _headers())
        .timeout(_timeout)
        .catchError((_) => _throwNetwork());
    return CareToday.fromJson(_decode(res));
  }

  // ── GET /api/v1/herbal-garden/weather ───────────────────────────────────

  Future<GardenWeather> weather({
    String? plantId,
    double? latitude,
    double? longitude,
    String? uid,
  }) async {
    final params = <String, String>{};
    if (plantId != null && plantId.isNotEmpty) {
      params['plant_id'] = plantId;
    }
    if (latitude != null && longitude != null) {
      params['latitude'] = latitude.toString();
      params['longitude'] = longitude.toString();
    }
    if (uid != null) params['uid'] = uid;

    final res = await _client
        .get(
          Uri.parse('$_root/weather').replace(queryParameters: params),
          headers: await _headers(),
        )
        .timeout(_timeout)
        .catchError((_) => _throwNetwork());
    return GardenWeather.fromJson(_decode(res));
  }

  // ── GET /api/v1/herbal-garden/{plant_id} — chi tiết 1 cây ───────────────

  Future<GardenPlantDetail> plantDetail(String plantId, {String? uid}) async {
    final res = await _client
        .get(_uri('/$plantId', uid), headers: await _headers())
        .timeout(_timeout)
        .catchError((_) => _throwNetwork());
    return GardenPlantDetail.fromJson(_decode(res));
  }

  // ── GET /api/v1/herbal-garden/deleted — cây đã xoá ───────────────────────

  Future<List<DeletedGardenPlant>> deletedPlants({String? uid}) async {
    final res = await _client
        .get(_uri('/deleted', uid), headers: await _headers())
        .timeout(_timeout)
        .catchError((_) => _throwNetwork());
    final j = _decode(res);
    return (j['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DeletedGardenPlant.fromJson)
        .toList();
  }

  // ── GET /api/v1/herbal-garden/soil-options ──────────────────────────────

  Future<SoilOptions> soilOptions() async {
    final res = await _client
        .get(Uri.parse('$_root/soil-options'), headers: await _headers())
        .timeout(_timeout)
        .catchError((_) => _throwNetwork());
    return SoilOptions.fromJson(_decode(res));
  }

  // ── GET /api/v1/herbal-garden/soil-suggestion ───────────────────────────

  /// Gợi ý loại đất cho 1 loài. Trả `null` nếu server không có gợi ý
  /// (404 = loài không tồn tại trong danh mục).
  Future<SoilSuggestion?> soilSuggestion(String tenLabel) async {
    final res = await _client
        .get(
          Uri.parse(
            '$_root/soil-suggestion',
          ).replace(queryParameters: <String, String>{'ten_label': tenLabel}),
          headers: await _headers(),
        )
        .timeout(_timeout)
        .catchError((_) => _throwNetwork());
    if (res.statusCode == 404) return null;
    return SoilSuggestion.fromJson(_decode(res));
  }

  // ── POST /api/v1/herbal-garden — thêm cây ───────────────────────────────

  Future<AddPlantResult> addPlant({
    required String tenLabel,
    DateTime? plantedAt,
    String? stage,
    String? notes,
    String? imageUrl,
    double? latitude,
    double? longitude,
    String? addressName,
    String? soilType,
    String? plantingMedium,
    String? doAm,
    String? mauDat,
    bool allowDuplicate = false,
    String? uid,
  }) async {
    final res = await _client
        .post(
          Uri.parse(_root),
          headers: await _headers(),
          body: jsonEncode(<String, dynamic>{
            'ten_label': tenLabel,
            if (uid != null) 'uid': uid,
            'allow_duplicate': allowDuplicate,
            if (plantedAt != null)
              'planted_at': plantedAt.toUtc().toIso8601String(),
            if (stage != null) 'stage': stage,
            if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
            if (imageUrl != null) 'image_url': imageUrl,
            if (latitude != null) 'latitude': latitude,
            if (longitude != null) 'longitude': longitude,
            if (addressName != null && addressName.trim().isNotEmpty)
              'address_name': addressName.trim(),
            if (soilType != null) 'soil_type': soilType,
            if (plantingMedium != null) 'planting_medium': plantingMedium,
            if (doAm != null) 'do_am': doAm,
            if (mauDat != null) 'mau_dat': mauDat,
          }),
        )
        .timeout(_timeout)
        .catchError((_) => _throwNetwork());

    // 409 — cây đã có trong vườn: `id` nằm ở TOP-LEVEL (không trong detail).
    if (res.statusCode == 409) {
      final j = _decodeBody(res);
      return AddPlantResult(
        id: j['id']?.toString(),
        message: j['message']?.toString() ?? 'Loài cây này đã có trong vườn.',
        isDuplicate: true,
        tenLabel: j['ten_label']?.toString(),
      );
    }

    final j = _decode(res);
    return AddPlantResult(
      id: j['id']?.toString(),
      message: j['message']?.toString() ?? 'Đã lưu cây vào vườn.',
      isDuplicate: false,
      tenLabel: j['ten_label']?.toString(),
    );
  }

  // ── POST /api/v1/herbal-garden/{plant_id}/stage — đổi mốc ──────────────

  Future<String> updateStage(
    String plantId, {
    required String stage,
    String? note,
    DateTime? at,
    String? uid,
  }) async {
    final res = await _client
        .post(
          _uri('/$plantId/stage', uid),
          headers: await _headers(),
          body: jsonEncode(<String, dynamic>{
            'stage': stage,
            if (at != null) 'at': at.toUtc().toIso8601String(),
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          }),
        )
        .timeout(_timeout)
        .catchError((_) => _throwNetwork());
    final j = _decode(res);
    return j['message']?.toString() ?? 'Đã cập nhật giai đoạn.';
  }

  // ── POST /api/v1/herbal-garden/{plant_id}/water — ghi nhận tưới ─────────

  Future<String> waterPlant(String plantId, {String? note, String? uid}) async {
    final res = await _client
        .post(
          _uri('/$plantId/water', uid),
          headers: await _headers(),
          body: jsonEncode(<String, dynamic>{
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          }),
        )
        .timeout(_timeout)
        .catchError((_) => _throwNetwork());
    final j = _decode(res);
    return j['message']?.toString() ?? 'Đã ghi nhận tưới nước.';
  }

  // ── POST /api/v1/herbal-garden/{plant_id}/photo — ảnh nhật ký ────────────

  /// Trả về danh sách timeline **đầy đủ** sau khi thêm (server đã gửi kèm).
  Future<List<TimelineImage>> addPhoto(
    String plantId, {
    required String filePath,
    String? note,
    double? latitude,
    double? longitude,
    String? addressName,
    String? uid,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const GardenApiException(0, 'Không tìm thấy ảnh để tải lên.');
    }

    final ext = filePath.toLowerCase().split('.').last;
    final MediaType mediaType = switch (ext) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };

    final request = http.MultipartRequest('POST', _uri('/$plantId/photo', uid));
    final token = await _readToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: mediaType,
      ),
    );
    if (note != null && note.trim().isNotEmpty) {
      request.fields['note'] = note.trim();
    }
    // GPS tại thời điểm chụp — server dùng để tính thời tiết đúng chỗ trồng.
    if (latitude != null) request.fields['latitude'] = latitude.toString();
    if (longitude != null) request.fields['longitude'] = longitude.toString();
    if (addressName != null && addressName.trim().isNotEmpty) {
      request.fields['address_name'] = addressName.trim();
    }

    final streamed = await _client
        .send(request)
        .timeout(_uploadTimeout)
        .catchError((_) => _throwNetwork());
    final res = await http.Response.fromStream(streamed);
    final j = _decode(res);
    return (j['timeline_images'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TimelineImage.fromJson)
        .toList();
  }

  // ── POST /api/v1/herbal-garden/{plant_id}/harvest — ghi sổ thu hoạch ────
  /// Trả về (message, warning, record).
  Future<({String message, String? warning, HarvestRecord? record})> harvest(
    String plantId, {
    DateTime? harvestedAt,
    double? weightKg,
    String? note,
    String? uid,
  }) async {
    final res = await _client
        .post(
          _uri('/$plantId/harvest', uid),
          headers: await _headers(),
          body: jsonEncode(<String, dynamic>{
            if (harvestedAt != null)
              'harvested_at': harvestedAt.toUtc().toIso8601String(),
            if (weightKg != null) 'weight_kg': weightKg,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          }),
        )
        .timeout(_timeout)
        .catchError((_) => _throwNetwork());
    final j = _decode(res);
    final raw = j['record'];
    return (
      message: j['message']?.toString() ?? 'Đã ghi vào sổ thu hoạch.',
      warning: j['warning']?.toString(),
      record: raw is Map<String, dynamic> ? HarvestRecord.fromJson(raw) : null,
    );
  }

  // ── POST /api/v1/herbal-garden/{plant_id}/task/dismiss — gỡ thẻ việc ────

  Future<String> dismissTask(
    String plantId, {
    required String taskType,
    String? choiceId,
    String? note,
    String? uid,
  }) async {
    final res = await _client
        .post(
          _uri('/$plantId/task/dismiss', uid),
          headers: await _headers(),
          body: jsonEncode(<String, dynamic>{
            'task_type': taskType,
            if (choiceId != null) 'choice_id': choiceId,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          }),
        )
        .timeout(_timeout)
        .catchError((_) => _throwNetwork());
    final j = _decode(res);
    return j['message']?.toString() ?? 'Đã ghi nhận lựa chọn của bạn.';
  }

  // ── DELETE /api/v1/herbal-garden/{plant_id} — xoá cây ───────────────────

  /// Mặc định xoá MỀM (server tự đánh dấu `deleted_at`) → có thể khôi phục.
  Future<String> deletePlant(String plantId, {String? uid}) async {
    final res = await _client
        .delete(_uri('/$plantId', uid), headers: await _headers())
        .timeout(_timeout)
        .catchError((_) => _throwNetwork());
    final j = _decode(res);
    return j['message']?.toString() ?? 'Đã xoá cây khỏi vườn.';
  }

  // ── POST /api/v1/herbal-garden/{plant_id}/restore — khôi phục ───────────

  Future<String> restorePlant(String plantId, {String? uid}) async {
    final res = await _client
        .post(
          _uri('/$plantId/restore', uid),
          headers: await _headers(),
          body: jsonEncode(<String, dynamic>{}),
        )
        .timeout(_timeout)
        .catchError((_) => _throwNetwork());
    final j = _decode(res);
    return j['message']?.toString() ?? 'Đã khôi phục cây vào vườn.';
  }

  // ── API phụ trợ: tìm trong danh mục & nhận diện ảnh ───────────────────

  /// Tìm loài cây trong danh mục. ⚠️ Tham số là `q` (KHÔNG phải `query`).
  Future<List<CatalogPlant>> searchCatalog(String query) async {
    final res = await _client
        .get(
          Uri.parse(
            '$baseUrl/api/v1/plants/search',
          ).replace(queryParameters: <String, String>{'q': query}),
          headers: await _headers(),
        )
        .timeout(_timeout)
        .catchError((_) => _throwNetwork());
    final j = _decode(res);
    return (j['results'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CatalogPlant.fromJson)
        .toList();
  }

  /// Nhận diện ảnh — `POST {baseUrl}/predict`.
  Future<PredictResult> predict(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const GardenApiException(0, 'Không tìm thấy ảnh để nhận diện.');
    }

    final ext = filePath.toLowerCase().split('.').last;
    final MediaType mediaType = switch (ext) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/predict'),
    );
    final token = await _readToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: mediaType,
      ),
    );

    final streamed = await _client
        .send(request)
        .timeout(_uploadTimeout)
        .catchError((_) => _throwNetwork());
    final res = await http.Response.fromStream(streamed);
    return PredictResult.fromJson(_decode(res));
  }

  // ── Helper ──────────────────────────────────────────────────────────────

  /// Tạo URI kèm query `uid` (nếu có).
  ///
  /// Dùng [Uri.replace] để escape đúng chuẩn — tránh lỗi khi uid chứa ký tự
  /// đặc biệt.
  Uri _uri(String path, String? uid) {
    if (uid == null || uid.isEmpty) {
      return Uri.parse('$_root$path');
    }
    return Uri.parse(
      '$_root$path',
    ).replace(queryParameters: <String, String>{'uid': uid});
  }

  void dispose() => _client.close();
}
