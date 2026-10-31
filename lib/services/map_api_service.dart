// lib/services/map_api_service.dart
//
// Chịu trách nhiệm gọi 2 API BẢN ĐỒ:
//   GET /api/v1/system-plants/map  (MySQL – không cần auth)
//   GET /api/v1/user-plants/map    (MongoDB – cần Bearer token)
//
// Xử lý Partial Failure:
//   Mỗi API có error handler độc lập → không bao giờ crash màn hình.
//   Kết quả có field [partialErrorMessage] để UI hiển thị toast.
//
// HỢP ĐỒNG API:
//   GET {MAP_SYSTEM_URL}/api/v1/system-plants/map
//       ?min_lat=..&max_lat=..&min_lng=..&max_lng=..
//   → 200: [ { "id": 1, "name": "...", "image_url": "...",
//              "latitude": 21.03, "longitude": 105.85 } ]
//     hoặc { "data": [ ... ] }
//
//   GET {MAP_USER_URL}/api/v1/user-plants/map
//       ?min_lat=..&max_lat=..&min_lng=..&max_lng=..
//       Header: Authorization: Bearer <JWT>
//   → 200: [ { "id": "...", "name": "...", "thumbnail_url": "...",
//              "lat": 21.03, "lng": 105.85 } ]
//     hoặc { "data": [ ... ] }
//
// Backend chưa sẵn sàng → chạy với --dart-define=MAP_MOCK=true để dùng
// dữ liệu giả lập, UI vẫn chạy trọn vẹn.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:thunghiem1/config/app_config.dart';
import 'package:thunghiem1/models/plant_map_marker.dart';
import 'package:thunghiem1/services/auth_api_service.dart';
import 'package:thunghiem1/services/secure_storage_service.dart';

// ── Models cho Cây gần đây (Nearby) & Chỉ đường (Directions) ───────────────────

class NearbyPlantItem {
  final String id;
  final int? locationId;
  final String name;
  final String? scientificName;
  final String? description;
  final String? imageUrl;
  final String? thumbnailUrl;
  final double latitude;
  final double longitude;
  final String? addressName;
  final PlantSource source;
  final double distanceKm;
  final String distanceDisplay;

  LatLng get location => LatLng(latitude, longitude);

  const NearbyPlantItem({
    required this.id,
    this.locationId,
    required this.name,
    this.scientificName,
    this.description,
    this.imageUrl,
    this.thumbnailUrl,
    required this.latitude,
    required this.longitude,
    this.addressName,
    required this.source,
    required this.distanceKm,
    required this.distanceDisplay,
  });

  factory NearbyPlantItem.fromJson(Map<String, dynamic> json) {
    final src = (json['source'] as String? ?? 'system') == 'user'
        ? PlantSource.user
        : PlantSource.system;

    return NearbyPlantItem(
      id: json['id']?.toString() ?? '',
      locationId: (json['location_id'] ?? json['locationId']) as int?,
      name: json['name'] as String? ?? 'Cây thuốc',
      scientificName:
          json['scientific_name'] as String? ?? json['scientificName'] as String?,
      description: json['description'] as String? ?? json['notes'] as String?,
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String?,
      thumbnailUrl:
          json['thumbnail_url'] as String? ?? json['thumbnailUrl'] as String?,
      latitude:
          (json['latitude'] ?? json['lat']) is num
          ? ((json['latitude'] ?? json['lat']) as num).toDouble()
          : double.tryParse('${json['latitude'] ?? json['lat']}') ?? 0.0,
      longitude:
          (json['longitude'] ?? json['lng']) is num
          ? ((json['longitude'] ?? json['lng']) as num).toDouble()
          : double.tryParse('${json['longitude'] ?? json['lng']}') ?? 0.0,
      addressName: json['address_name'] as String? ?? json['address'] as String?,
      source: src,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      distanceDisplay: json['distance_display'] as String? ?? '',
    );
  }
}

class DirectionsResult {
  final double distanceKm;
  final String distanceDisplay;
  final int durationMinutes;
  final String durationDisplay;
  final double bearing;
  final List<LatLng> points;

  const DirectionsResult({
    required this.distanceKm,
    required this.distanceDisplay,
    required this.durationMinutes,
    required this.durationDisplay,
    required this.bearing,
    required this.points,
  });

  factory DirectionsResult.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List? ?? [];
    final pointsList = <LatLng>[];
    for (final p in rawPoints) {
      if (p is List && p.length >= 2) {
        final lat = (p[0] as num).toDouble();
        final lng = (p[1] as num).toDouble();
        pointsList.add(LatLng(lat, lng));
      }
    }

    return DirectionsResult(
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      distanceDisplay: json['distance_display'] as String? ?? '',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      durationDisplay: json['duration_display'] as String? ?? '',
      bearing: (json['bearing'] as num?)?.toDouble() ?? 0.0,
      points: pointsList,
    );
  }
}

// ── Result model ──────────────────────────────────────────────────────────────

/// Kết quả ghép từ 2 API (partial failure được dung hòa)
class MapFetchResult {
  final List<PlantMapMarker> markers;

  /// null = thành công hoàn toàn, non-null = ít nhất 1 API lỗi
  final String? partialErrorMessage;

  /// true = dữ liệu đến từ mock (backend chưa sẵn sàng)
  final bool isMock;

  const MapFetchResult({
    required this.markers,
    this.partialErrorMessage,
    this.isMock = false,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────

class MapApiService {
  MapApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// System-plants (MySQL) → remote server, không cần auth
  final String _remoteBase = AppConfig.mapSystemUrl;

  /// User-plants (MongoDB) → cần JWT của backend
  final String _localBase = AppConfig.mapUserUrl;

  static const _timeout = Duration(seconds: 15);

  /// Host đã được auto-discovery (null = chưa dò).
  String? _resolvedBase;

  /// Trong quá trình dò host, tránh gọi song song nhiều lần.
  Future<String?>? _resolvingFuture;

  /// Danh sách host ứng viên: host chính + các host dự phòng.
  List<String> get _candidateBases {
    final list = <String>[_remoteBase];
    for (final raw in AppConfig.mapFallbackUrls.split(',')) {
      final url = raw.trim();
      if (url.isEmpty) continue;
      if (!list.contains(url)) list.add(url);
    }
    return list;
  }

  /// Tự động dò host nào thực sự phục vụ API bản đồ.
  ///
  /// Backend có thể chạy ở local (emulator / LAN) hoặc production.
  /// Nếu host chính không phục vụ `/api/v1/system-plants/map` → thử host kế tiếp.
  /// Kết quả được cache lại để không dò lại mỗi lần fetch.
  Future<String?> _resolveBase() {
    if (_resolvedBase != null) return Future.value(_resolvedBase);
    final pending = _resolvingFuture;
    if (pending != null) return pending;

    final future = () async {
      for (final base in _candidateBases) {
        try {
          final probe = Uri.parse(
            '$base/api/v1/system-plants/map',
          ).replace(
            queryParameters: const {
              'min_lat': '20.0',
              'max_lat': '20.1',
              'min_lng': '105.0',
              'max_lng': '105.1',
            },
          );
          final res = await _client.get(probe).timeout(
            const Duration(seconds: 6),
          );
          // 404 cũng chấp nhận (host có router nhưng chưa có dữ liệu) —
          // chỉ cần host "sống" và phục vụ đúng path.
          if (res.statusCode != 0) {
            _resolvedBase = base;
            debugPrint('[MapAPI] Base URL bản đồ: $base');
            return base;
          }
        } catch (e) {
          debugPrint('[MapAPI] Probe thất bại $base: $e');
        }
      }
      return null;
    }();

    _resolvingFuture = future;
    return future;
  }

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

  // ── Public API ────────────────────────────────────────────────────────────

  /// Gọi đồng thời 2 API bằng [Future.wait].
  /// Lỗi từng API được bắt RIÊNG → luôn trả về, không throw.
  Future<MapFetchResult> fetchMarkersInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    if (AppConfig.mapMock) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final mock = MockMapData.markersInBounds(
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
      );
      return MapFetchResult(markers: mock, isMock: true);
    }

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

    return MapFetchResult(markers: combined, partialErrorMessage: partialError);
  }

  // ── System Plants (MySQL) ─────────────────────────────────────────────────

  Future<List<PlantMapMarker>> _fetchSystemPlants(
    Map<String, String> params,
  ) async {
    final base = await _resolveBase() ?? _remoteBase;
    final uri = Uri.parse(
      '$base/api/v1/system-plants/map',
    ).replace(queryParameters: params);

    final response = await _client.get(uri).timeout(_timeout);

    return _parseList(response, isSystem: true);
  }

  // ── User Plants (MongoDB) ─────────────────────────────────────────────────

  Future<List<PlantMapMarker>> _fetchUserPlants(
    Map<String, String> params,
  ) async {
    // Lấy JWT backend (HS256) từ SecureStorage — KHÔNG dùng Firebase Token
    final token = await _backendJwt();

    if (token == null) {
      // Chưa đăng nhập → bỏ qua user-plants, không throw (partial failure)
      debugPrint('[MapAPI] Bỏ qua user-plants: chưa có JWT backend.');
      return [];
    }

    final uri = Uri.parse(
      '$_localBase/api/v1/user-plants/map',
    ).replace(queryParameters: params);
    final response = await _client
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(_timeout);

    if (response.statusCode == 401) {
      debugPrint(
        '[MapAPI] user-plants 401: Access Token hết hạn. Thử làm mới qua Refresh Token...',
      );
      final newToken = await AuthApiService().refreshToken();
      if (newToken != null) {
        final retryResponse = await _client
            .get(uri, headers: {'Authorization': 'Bearer $newToken'})
            .timeout(_timeout);
        if (retryResponse.statusCode == 200) {
          return _parseList(retryResponse, isSystem: false);
        }
      }
      debugPrint(
        '[MapAPI] Không thể làm mới token hoặc phiên đăng nhập đã hết hạn.',
      );
      return [];
    }

    return _parseList(response, isSystem: false);
  }

  // ── Parser chung ─────────────────────────────────────────────────────────

  List<PlantMapMarker> _parseList(
    http.Response response, {
    required bool isSystem,
  }) {
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
        .map(
          (json) => isSystem
              ? PlantMapMarker.fromSystemJson(json)
              : PlantMapMarker.fromUserJson(json),
        )
        .toList();
  }

  /// Lấy toàn bộ cây cá nhân của user (không giới hạn viewport)
  Future<List<PlantMapMarker>> fetchAllUserPlants() async {
    final token = await _backendJwt();
    if (token == null) return [];

    final uri = Uri.parse('$_localBase/api/v1/user-plants/all');
    try {
      final response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout);

      if (response.statusCode == 401) {
        final newToken = await AuthApiService().refreshToken();
        if (newToken != null) {
          final retry = await _client
              .get(uri, headers: {'Authorization': 'Bearer $newToken'})
              .timeout(_timeout);
          if (retry.statusCode == 200) {
            return _parseList(retry, isSystem: false);
          }
        }
        return [];
      }
      return _parseList(response, isSystem: false);
    } catch (e) {
      debugPrint('[MapAPI] fetchAllUserPlants error: $e');
      return [];
    }
  }

  /// Lấy danh sách cây thuốc xung quanh người dùng (Backend xử lý Haversine, lọc bán kính, sắp xếp)
  Future<List<NearbyPlantItem>> fetchNearbyPlants({
    required double lat,
    required double lng,
    double radiusKm = 3.0,
    int limit = 50,
  }) async {
    final token = await _backendJwt();
    final uri = Uri.parse('$_remoteBase/api/v1/plants/nearby').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radius_km': radiusKm.toString(),
        'limit': limit.toString(),
      },
    );

    final headers = <String, String>{};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await _client.get(uri, headers: headers).timeout(_timeout);
      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> list =
            decoded is List ? decoded : (decoded['data'] as List? ?? []);
        return list
            .whereType<Map<String, dynamic>>()
            .map((j) => NearbyPlantItem.fromJson(j))
            .toList();
      }
    } catch (e) {
      debugPrint('[MapAPI] fetchNearbyPlants error: $e');
    }
    return [];
  }

  /// Tính toán chỉ đường, khoảng cách realtime, góc xoay bearing (Backend OSRM)
  Future<DirectionsResult?> fetchDirections({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final uri = Uri.parse('$_remoteBase/api/v1/routing/directions').replace(
      queryParameters: {
        'start_lat': startLat.toString(),
        'start_lng': startLng.toString(),
        'end_lat': endLat.toString(),
        'end_lng': endLng.toString(),
      },
    );

    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode == 200) {
        final decoded =
            json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return DirectionsResult.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('[MapAPI] fetchDirections error: $e');
    }
    return null;
  }

  void dispose() => _client.close();
}

// ── Mock data ────────────────────────────────────────────────────────────────
// Dùng để phát triển UI khi backend chưa xong.
// Bật bằng: flutter run --dart-define=MAP_MOCK=true

class MockMapData {
  static final _plants = <PlantMapMarker>[
    PlantMapMarker(
      id: 'sys_1',
      plantId: '1',
      name: 'Actaea pachysoda',
      scientificName: 'Actaea pachysoda',
      description: 'Cây thuốc dược liệu quý trong vườn dược liệu.',
      source: PlantSource.system,
      latitude: 21.0285,
      longitude: 105.8542,
    ),
    PlantMapMarker(
      id: 'sys_2',
      plantId: '2',
      name: 'Bồ công anh',
      scientificName: 'Taraxacum mongolicum',
      description: 'Cây thuốc thanh nhiệt, tiêu hóa.',
      source: PlantSource.system,
      latitude: 21.0350,
      longitude: 105.8480,
    ),
    PlantMapMarker(
      id: 'sys_3',
      plantId: '3',
      name: 'Bạch chỉ',
      scientificName: 'Angelica dahurica',
      description: 'Dược liệu giải đau, trừ phong.',
      source: PlantSource.system,
      latitude: 21.0200,
      longitude: 105.8620,
    ),
    PlantMapMarker(
      id: 'sys_4',
      plantId: '4',
      name: 'Cây bồ đề',
      scientificName: 'Aloe vera',
      description: 'Cây chữa bỏng, làm mát da.',
      source: PlantSource.system,
      latitude: 21.0420,
      longitude: 105.8610,
    ),
    PlantMapMarker(
      id: 'usr_1',
      plantId: 'u1',
      name: 'Cây của tôi',
      scientificName: 'Ocimum basilicum',
      description: 'Cây cá nhân đã lưu vào bản đồ.',
      source: PlantSource.user,
      latitude: 21.0300,
      longitude: 105.8560,
    ),
    PlantMapMarker(
      id: 'usr_2',
      plantId: 'u2',
      name: 'Rau mùi tôi trồng',
      scientificName: 'Mentha spicata',
      description: 'Cây cá nhân trong vườn nhà.',
      source: PlantSource.user,
      latitude: 21.0180,
      longitude: 105.8450,
    ),
  ];

  /// Lọc mock theo bounding box (giống hành vi server).
  static List<PlantMapMarker> markersInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) {
    return _plants
        .where(
          (p) =>
              p.latitude >= minLat &&
              p.latitude <= maxLat &&
              p.longitude >= minLng &&
              p.longitude <= maxLng,
        )
        .toList();
  }

  /// Toàn bộ mock markers (dùng cho cache offline khi chưa có dữ liệu thật).
  static List<PlantMapMarker> get all => List.unmodifiable(_plants);
}
