// lib/services/map_api_service.dart
//
// Chịu trách nhiệm gọi 2 API BẢN ĐỒ:
//   GET /api/v1/system-plants/map  (MySQL – không cần auth)
//   GET /api/v1/user-plants/map    (MongoDB – cần Bearer token)
//
// Xử lý Partial Failure:
//   Mỗi API có error handler độc lập → không bao giờ crash màn hình.
//   Kết quả có field [partialErrorMessage] để UI hiển thị toast.

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:thunghiem1/config/app_config.dart';
import 'package:thunghiem1/models/plant_map_marker.dart';
import 'package:thunghiem1/services/secure_storage_service.dart';

// ── Result model ──────────────────────────────────────────────────────────────

/// Kết quả ghép từ 2 API (partial failure được dung hòa)
class MapFetchResult {
  final List<PlantMapMarker> markers;

  /// null = thành công hoàn toàn, non-null = ít nhất 1 API lỗi
  final String? partialErrorMessage;

  const MapFetchResult({
    required this.markers,
    this.partialErrorMessage,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────

class MapApiService {
  // System-plants (MySQL) → remote server không cần auth
  final String _remoteBase = AppConfig.detectUrl;

  // User-plants (MongoDB) → local server cần JWT của backend
  // 10.0.2.2 là IP của máy host khi chạy trên Android Emulator
  final String _localBase = AppConfig.detectUrlLocal;

  // ── JWT từ SecureStorage (khớp với backend HS256) ────────────────────────
  // KHÔNG dùng Firebase ID Token — backend verify bằng SECRET_KEY riêng,
  // không phải Firebase public key.

  Future<String?> _backendJwt() async {
    try {
      return await SecureStorageService().readToken();
    } catch (_) {
      return null;
    }
  }

  // ── Firebase ID Token (chỉ giữ lại phòng khi cần dùng Firebase Auth) ────
  // ignore: unused_element
  Future<String?> _firebaseIdToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      return await user?.getIdToken();
    } catch (_) {
      return null;
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Gọi đồng thời 2 API bằng [Future.wait].
  /// Lỗi từng API được bắt RIÊNG → luôn trả về, không throw.
  Future<MapFetchResult> fetchMarkersInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    final params = {
      'min_lat': minLat.toStringAsFixed(6),
      'max_lat': maxLat.toStringAsFixed(6),
      'min_lng': minLng.toStringAsFixed(6),
      'max_lng': maxLng.toStringAsFixed(6),
    };

    // Wrap mỗi future với sentinel để phân biệt thành công / thất bại
    bool systemFailed = false;
    bool userFailed = false;

    // Future.wait gọi ĐỒNG THỜI cả 2
    final results = await Future.wait([
      _fetchSystemPlants(params).catchError((e) {
        systemFailed = true;
        debugPrint('[MapAPI] System plants error: $e');
        return <PlantMapMarker>[];
      }),
      _fetchUserPlants(params).catchError((e) {
        userFailed = true;
        debugPrint('[MapAPI] User plants error: $e');
        return <PlantMapMarker>[];
      }),
    ]);

    final combined = [...results[0], ...results[1]];

    String? partialError;
    if (systemFailed && userFailed) {
      partialError = 'Không thể tải dữ liệu bản đồ lúc này';
    } else if (systemFailed || userFailed) {
      partialError = 'Không thể tải toàn bộ dữ liệu lúc này';
    }

    return MapFetchResult(
      markers: combined,
      partialErrorMessage: partialError,
    );
  }

  // ── System Plants (MySQL) ─────────────────────────────────────────────────

  Future<List<PlantMapMarker>> _fetchSystemPlants(
      Map<String, String> params) async {
    final uri = Uri.parse('$_remoteBase/api/v1/system-plants/map')
        .replace(queryParameters: params);

    final response =
        await http.get(uri).timeout(const Duration(seconds: 15));

    return _parseList(response, isSystem: true);
  }

  // ── User Plants (MongoDB) ─────────────────────────────────────────────────

  Future<List<PlantMapMarker>> _fetchUserPlants(
      Map<String, String> params) async {
    // Lấy JWT backend (HS256) từ SecureStorage — KHÔNG dùng Firebase Token
    final token = await _backendJwt();

    if (token == null) {
      // Chưa đăng nhập → bỏ qua user-plants, không throw (partial failure)
      debugPrint('[MapAPI] Bỏ qua user-plants: chưa có JWT backend.');
      return [];
    }

    final uri = Uri.parse('$_localBase/api/v1/user-plants/map')
        .replace(queryParameters: params);

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 401) {
      // Token hết hạn → log rõ, trả về list rỗng (không crash map)
      debugPrint('[MapAPI] user-plants 401: JWT hết hạn hoặc không hợp lệ. '
          'Vui lòng đăng nhập lại.');
      return [];
    }

    return _parseList(response, isSystem: false);
  }

  // ── Parser chung ─────────────────────────────────────────────────────────

  List<PlantMapMarker> _parseList(http.Response response,
      {required bool isSystem}) {
    if (response.statusCode != 200) {
      throw Exception(
        'HTTP ${response.statusCode} — '
        '${isSystem ? 'system' : 'user'}-plants/map',
      );
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes));

    // Hỗ trợ cả 2 format: List trực tiếp hoặc { "data": [...] }
    final List<dynamic> rawList = switch (decoded) {
      List l => l,
      Map m when m.containsKey('data') => m['data'] as List? ?? [],
      _ => [],
    };

    return rawList
        .whereType<Map<String, dynamic>>()
        .map((json) => isSystem
            ? PlantMapMarker.fromSystemJson(json)
            : PlantMapMarker.fromUserJson(json))
        .toList();
  }
}
