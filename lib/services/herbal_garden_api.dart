// lib/services/herbal_garden_api.dart
//
// Service gọi API Vườn Dược Liệu (Herbal Garden).
//
// Hợp đồng: xem BAN_GIAO_FRONTEND_VUON_DUOC_LIEU.md — Mục 3 (danh mục API)
// và Mục 4 (hợp đồng request → response thật).
//
// Base: /api/v1/herbal-garden
//
// Xác thực: server chạy chế độ demo (HERBAL_GARDEN_REQUIRE_AUTH=false) nên
// `uid` trong query vẫn hoạt động. Nhưng ta LUÔN gửi `Authorization: Bearer`
// khi có token — token hợp lệ thì server bỏ qua `uid` hoàn toàn.
//
// Lỗi: server trả 2 dạng `detail`:
//   • nghiệp vụ  → string
//   • validate 422 → list of object {loc, msg, type}
// → helper [extractError] xử lý cả hai.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:thunghiem1/config/app_config.dart';
import 'package:thunghiem1/models/herbal_garden.dart';

/// Lỗi API kèm mã HTTP — UI dùng để phân nhánh (vd: 409 = trùng cây).
class HerbalGardenException implements Exception {
  const HerbalGardenException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

/// Trích thông báo lỗi từ response — xử lý CẢ string và list.
String extractError(dynamic detail) {
  if (detail is String) return detail;
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

/// Kết quả thêm cây — phân biệt thêm mới / đã tồn tại (409).
class AddPlantResult {
  const AddPlantResult({
    required this.id,
    required this.duplicate,
    required this.message,
  });

  final String? id;
  final bool duplicate;
  final String message;
}

class HerbalGardenApi {
  HerbalGardenApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _baseUrl => AppConfig.mapUserUrl;

  String get _root => '$_baseUrl/api/v1/herbal-garden';

  static const _timeout = Duration(seconds: 20);

  // ── Headers ──────────────────────────────────────────────────────────────

  /// Headers cho các request Vườn Dược Liệu.
  ///
  /// ⚠️ Cố ý **không** gửi `Authorization: Bearer` từ JWT của app.
  ///
  /// Lý do: backend Vườn Dược Liệu xác thực bằng **Firebase ID token**
  /// (`herbal_garden/auth.py`), còn app đang dùng **JWT HS256** do
  /// `/api/auth` cấp. Gửi nhầm loại token sẽ khiến server trả 401 ngay khi
  /// bật `HERBAL_GARDEN_REQUIRE_AUTH=true`.
  ///
  /// Ở chế độ demo (hiện tại) server bỏ qua `uid` khi token hợp lệ, và bỏ qua
  /// token khi không hợp lệ → vẫn chạy bình thường. Vì vậy ta dùng `uid`
  /// trong query cho tới khi backend bật xác thực bắt buộc; khi đó chỉ cần
  /// thêm Firebase ID token vào đây (và `uid` sẽ bị server bỏ qua).
  Future<Map<String, String>> _headers({bool json = true}) async {
    return <String, String>{
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
    };
  }

  /// Giải mã response + ném lỗi có message tiếng Việt.
  Future<dynamic> _decode(http.Response res) async {
    dynamic body;
    try {
      body = res.body.isEmpty ? <String, dynamic>{} : json.decode(utf8.decode(res.bodyBytes));
    } catch (_) {
      body = <String, dynamic>{};
    }

    if (res.statusCode >= 400) {
      final detail = body is Map ? body['detail'] : null;
      final message = detail != null
          ? extractError(detail)
          : 'Yêu cầu thất bại (${res.statusCode}). Vui lòng thử lại.';
      throw HerbalGardenException(res.statusCode, message);
    }
    return body;
  }

  Map<String, String> _uidQuery(String? uid) {
    if (uid == null || uid.isEmpty) return const {};
    return {'uid': uid};
  }

  // ── A1 — Danh sách cây ──────────────────────────────────────────────────

  Future<List<GardenPlantItem>> listGarden({String? uid}) async {
    final uri = Uri.parse(_root).replace(queryParameters: _uidQuery(uid));
    final res = await _client.get(uri, headers: await _headers()).timeout(_timeout);
    final body = await _decode(res) as Map<String, dynamic>;
    return ((body['items'] ?? []) as List)
        .whereType<Map<String, dynamic>>()
        .map(GardenPlantItem.fromJson)
        .toList();
  }

  // ── A2 — Việc hôm nay ───────────────────────────────────────────────────

  Future<CareToday> careToday({String? uid}) async {
    final uri = Uri.parse('$_root/care-today').replace(queryParameters: _uidQuery(uid));
    final res = await _client.get(uri, headers: await _headers()).timeout(_timeout);
    return CareToday.fromJson(await _decode(res) as Map<String, dynamic>);
  }

  // ── A3 — Thời tiết & gợi ý tưới ────────────────────────────────────────

  /// Ưu tiên theo tài liệu:
  ///  1. GPS hiện tại của user  → `toa_do_nguoi_dung`
  ///  2. GPS của ảnh chụp gần nhất / vị trí cây → `gps_anh_chup` / `gps_cua_cay`
  ///  3. Không có gì → `vung_mac_dịnh` (Miền Bắc)
  Future<GardenWeather> weather({
    String? plantId,
    double? latitude,
    double? longitude,
  }) async {
    final params = <String, String>{};
    if (plantId != null && plantId.isNotEmpty) {
      params['plant_id'] = plantId;
    }
    if (latitude != null && longitude != null) {
      params['latitude'] = latitude.toString();
      params['longitude'] = longitude.toString();
    }
    final uri = Uri.parse('$_root/weather').replace(queryParameters: params);
    final res = await _client.get(uri, headers: await _headers()).timeout(_timeout);
    return GardenWeather.fromJson(await _decode(res) as Map<String, dynamic>);
  }

  // ── A4 — Chi tiết cây ───────────────────────────────────────────────────

  Future<GardenPlantDetail> plantDetail(String plantId, {String? uid}) async {
    final uri = Uri.parse('$_root/$plantId').replace(queryParameters: _uidQuery(uid));
    final res = await _client.get(uri, headers: await _headers()).timeout(_timeout);
    return GardenPlantDetail.fromJson(await _decode(res) as Map<String, dynamic>);
  }

  // ── A5 — Thêm cây ───────────────────────────────────────────────────────

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
    String? uid,
  }) async {
    final res = await _client
        .post(
          Uri.parse(_root),
          headers: await _headers(),
          body: jsonEncode({
            'ten_label': tenLabel,
            if (uid != null) 'uid': uid,
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
        .timeout(_timeout);

    // 409 = đã có cây này trong vườn → trả về id để điều hướng.
    if (res.statusCode == 409) {
      final body = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return AddPlantResult(
        id: body['id']?.toString(),
        duplicate: true,
        message: body['message']?.toString() ?? 'Loài cây này đã có trong vườn.',
      );
    }

    final body = await _decode(res) as Map<String, dynamic>;
    return AddPlantResult(
      id: body['id']?.toString(),
      duplicate: false,
      message: body['message']?.toString() ?? 'Đã lưu vào vườn.',
    );
  }

  // ── A6 — Đổi mốc giai đoạn ─────────────────────────────────────────────

  Future<String> updateStage(
    String plantId,
    String stage, {
    String? note,
    DateTime? at,
    String? uid,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$_root/$plantId/stage').replace(queryParameters: _uidQuery(uid)),
          headers: await _headers(),
          body: jsonEncode({
            'stage': stage,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
            if (at != null) 'at': at.toUtc().toIso8601String(),
          }),
        )
        .timeout(_timeout);
    final body = await _decode(res) as Map<String, dynamic>;
    return body['message']?.toString() ?? 'Đã cập nhật giai đoạn.';
  }

  // ── A7 — Chụp ảnh nhật ký ───────────────────────────────────────────────

  /// Upload ảnh + GPS tại thời điểm chụp (nếu có).
  ///
  /// Gửi kèm GPS rất quan trọng: nó cho biết người dùng đang trồng cây ở đâu,
  /// backend dùng đúng toạ độ đó để tính thời tiết & gợi ý tưới.
  Future<List<TimelineImage>> addPhoto(
    String plantId,
    File file, {
    String? note,
    double? latitude,
    double? longitude,
    String? addressName,
    String? uid,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_root/$plantId/photo').replace(queryParameters: _uidQuery(uid)),
    );
    request.headers.addAll(await _headers(json: false));

    final ext = file.path.toLowerCase().split('.').last;
    final mediaType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType.parse(mediaType),      ),
    );

    if (note != null && note.trim().isNotEmpty) {
      request.fields['note'] = note.trim();
    }
    if (latitude != null) request.fields['latitude'] = latitude.toString();
    if (longitude != null) request.fields['longitude'] = longitude.toString();
    if (addressName != null && addressName.trim().isNotEmpty) {
      request.fields['address_name'] = addressName.trim();
    }

    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final res = await http.Response.fromStream(streamed);
    final body = await _decode(res) as Map<String, dynamic>;
    return ((body['timeline_images'] ?? []) as List)
        .whereType<Map<String, dynamic>>()
        .map(TimelineImage.fromJson)
        .toList();
  }

  // ── A8 — Ghi sổ thu hoạch ───────────────────────────────────────────────

  Future<HarvestRecord> harvest(
    String plantId, {
    DateTime? harvestedAt,
    double? weightKg,
    String? note,
    String? uid,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$_root/$plantId/harvest').replace(queryParameters: _uidQuery(uid)),
          headers: await _headers(),
          body: jsonEncode({
            if (harvestedAt != null)
              'harvested_at': harvestedAt.toUtc().toIso8601String(),
            if (weightKg != null) 'weight_kg': weightKg,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          }),
        )
        .timeout(_timeout);
    final body = await _decode(res) as Map<String, dynamic>;
    final record = body['record'];
    if (record is Map<String, dynamic>) {
      return HarvestRecord.fromJson(record);
    }
    return HarvestRecord(
      id: plantId,
      harvestedAt: harvestedAt,
      weightKg: weightKg,
      inSeason: body['in_season'] == true,
      seasonLabel: body['season_label']?.toString(),
      warning: body['warning']?.toString(),
      note: note,
      activeRatio: (body['active_ratio'] as num?)?.toDouble(),
    );
  }

  // ── A9 — Xoá cây (xoá mềm) ─────────────────────────────────────────────

  Future<String> deletePlant(String plantId, {String? uid}) async {
    final res = await _client
        .delete(
          Uri.parse('$_root/$plantId').replace(queryParameters: _uidQuery(uid)),
          headers: await _headers(),
        )
        .timeout(_timeout);
    final body = await _decode(res) as Map<String, dynamic>;
    return body['message']?.toString() ?? 'Đã xoá cây khỏi vườn.';
  }

  // ── A10 — Bộ lựa chọn loại đất & nơi trồng ─────────────────────────────

  Future<SoilOptions> soilOptions() async {
    final res = await _client
        .get(Uri.parse('$_root/soil-options'), headers: await _headers())
        .timeout(_timeout);
    return SoilOptions.fromJson(await _decode(res) as Map<String, dynamic>);
  }

  // ── A11 — Gợi ý loại đất cho loài cây ─────────────────────────────────

  Future<SoilSuggestion?> soilSuggestion(String tenLabel) async {
    final uri = Uri.parse('$_root/soil-suggestion')
        .replace(queryParameters: {'ten_label': tenLabel});
    final res = await _client.get(uri, headers: await _headers()).timeout(_timeout);
    if (res.statusCode != 200) return null;
    final body = await _decode(res) as Map<String, dynamic>;
    return SoilSuggestion.fromJson(body);
  }

  // ── A12 — Ghi nhận đã tưới ──────────────────────────────────────────────

  Future<String> waterPlant(String plantId, {String? note, String? uid}) async {
    final res = await _client
        .post(
          Uri.parse('$_root/$plantId/water').replace(queryParameters: _uidQuery(uid)),
          headers: await _headers(),
          body: jsonEncode({if (note != null && note.trim().isNotEmpty) 'note': note.trim()}),
        )
        .timeout(_timeout);
    final body = await _decode(res) as Map<String, dynamic>;
    return body['message']?.toString() ?? 'Đã ghi nhận tưới nước.';
  }

  // ── A13 — Bỏ qua / gỡ thẻ việc ────────────────────────────────────────

  Future<String> dismissTask(
    String plantId, {
    required String taskType,
    String? choice,
    String? uid,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$_root/$plantId/task/dismiss')
              .replace(queryParameters: _uidQuery(uid)),
          headers: await _headers(),
          body: jsonEncode({
            'task_type': taskType,
            if (choice != null) 'choice': choice,
          }),
        )
        .timeout(_timeout);
    final body = await _decode(res) as Map<String, dynamic>;
    return body['message']?.toString() ?? 'Đã ghi nhận lựa chọn của bạn.';
  }

  // ── A14 — Cây đã xoá ────────────────────────────────────────────────────

  Future<List<DeletedPlantItem>> deletedPlants({String? uid}) async {
    final uri = Uri.parse('$_root/deleted').replace(queryParameters: _uidQuery(uid));
    final res = await _client.get(uri, headers: await _headers()).timeout(_timeout);
    final body = await _decode(res) as Map<String, dynamic>;
    return ((body['items'] ?? []) as List)
        .whereType<Map<String, dynamic>>()
        .map(DeletedPlantItem.fromJson)
        .toList();
  }

  // ── A15 — Khôi phục cây đã xoá ──────────────────────────────────────────

  Future<String> restorePlant(String plantId, {String? uid}) async {
    final res = await _client
        .post(
          Uri.parse('$_root/$plantId/restore').replace(queryParameters: _uidQuery(uid)),
          headers: await _headers(json: false),
        )
        .timeout(_timeout);
    final body = await _decode(res) as Map<String, dynamic>;
    return body['message']?.toString() ?? 'Đã khôi phục cây.';
  }

  // ── B1 — Nhận diện ảnh ─────────────────────────────────────────────────

  /// `POST /predict` (multipart, field `file`).
  ///
  /// 3 nhánh `status`:
  ///   • `success`  → ảnh rõ, cho phép thêm vào vườn
  ///   • `uncertain` → ảnh mờ / cây lạ → vẫn cho thêm nhưng phải cảnh báo
  ///   • `unknown`  → không phải cây → không cho thêm
  Future<PredictResult> predict(File file) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.detectUrl}/predict'),
    );
    request.headers.addAll(await _headers(json: false));
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final res = await http.Response.fromStream(streamed);
    return PredictResult.fromJson(await _decode(res) as Map<String, dynamic>);
  }

  // ── B2 — Tìm trong danh mục ────────────────────────────────────────────

  /// ⚠️ Tham số là `q`, KHÔNG phải `query` (sai sẽ nhận 422).
  Future<List<PlantSearchResult>> searchPlants(String q) async {
    final uri = Uri.parse('${AppConfig.mapUserUrl}/api/v1/plants/search')
        .replace(queryParameters: {'q': q});
    final res = await _client.get(uri, headers: await _headers()).timeout(_timeout);
    final body = await _decode(res) as Map<String, dynamic>;
    return ((body['results'] ?? []) as List)
        .whereType<Map<String, dynamic>>()
        .map(PlantSearchResult.fromJson)
        .toList();
  }

  void dispose() => _client.close();
}

/// Kết quả tìm trong danh mục — `plant_id` dùng làm `ten_label` khi thêm cây.
class PlantSearchResult {
  const PlantSearchResult({
    required this.plantId,
    required this.commonName,
    this.scientificName,
    this.imageUrl,
  });

  final String plantId;
  final String commonName;
  final String? scientificName;
  final String? imageUrl;

  factory PlantSearchResult.fromJson(Map<String, dynamic> j) => PlantSearchResult(
        plantId: j['plant_id'] ?? '',
        commonName: j['common_name'] ?? '',
        scientificName: j['scientific_name'],
        imageUrl: j['image_url'],
      );
}
