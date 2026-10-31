import 'dart:ui' show Color;

import 'package:latlong2/latlong.dart';
import 'package:thunghiem1/core/cluster/cluster_item.dart';

/// Nguồn dữ liệu của marker — phân biệt MySQL (system) vs MongoDB (user)
enum PlantSource { system, user }

extension PlantSourceX on PlantSource {
  /// Nhãn hiển thị trên UI (info window, bottom sheet, legend).
  String get label =>
      this == PlantSource.system ? 'Cây hệ thống' : 'Cây cá nhân';

  /// Màu chủ đạo tương ứng (đồng bộ với legend trên map).
  Color get color => this == PlantSource.system
      ? const Color(0xFF1565C0)
      : const Color(0xFFE65100);
}

/// Model đại diện cho một cây trên bản đồ.
/// Dùng [ClusterItem] mixin để tương thích với cluster manager.
class PlantMapMarker with ClusterItem {
  /// Khóa duy nhất để phân biệt marker (đã prefix theo nguồn).
  final String id;

  /// ID gốc từ backend (dùng để gọi API chi tiết cây).
  final String plantId;

  final String name;
  final String? imageUrl;
  final String? scientificName;
  final String? description;
  final PlantSource source;
  final double latitude;
  final double longitude;

  PlantMapMarker({
    required this.id,
    this.plantId = '',
    required this.name,
    this.imageUrl,
    this.scientificName,
    this.description,
    required this.source,
    required this.latitude,
    required this.longitude,
  });

  @override
  LatLng get location => LatLng(latitude, longitude);

  // ── Factory constructors ──────────────────────────────────────────────────

  /// Parse từ JSON của API System-Plants (MySQL)
  factory PlantMapMarker.fromSystemJson(Map<String, dynamic> json) {
    final rawId = (json['id'] ?? json['_id'] ?? '').toString();
    final locId = (json['location_id'] ?? json['loc_id'] ?? rawId).toString();
    return PlantMapMarker(
      id: 'sys_$locId',
      plantId: rawId,
      name:
          json['name'] as String? ??
          json['common_name'] as String? ??
          'Cây hệ thống',
      imageUrl: _firstString(json, ['image_url', 'thumbnail_url', 'image']),
      scientificName: _firstString(json, ['scientific_name', 'latin_name']),
      description: _firstString(json, ['description', 'short_description']),
      source: PlantSource.system,
      latitude: _parseDouble(json['latitude'] ?? json['lat']),
      longitude: _parseDouble(json['longitude'] ?? json['lng']),
    );
  }

  /// Parse từ JSON của API User-Plants (MongoDB)
  factory PlantMapMarker.fromUserJson(Map<String, dynamic> json) {
    final rawId = (json['id'] ?? json['_id'] ?? '').toString();
    return PlantMapMarker(
      id: 'usr_$rawId',
      plantId: rawId,
      name:
          json['name'] as String? ??
          json['common_name'] as String? ??
          'Cây cá nhân',
      // Backend trả về field "thumbnail_url" (khớp với UserPlantMapItem schema)
      imageUrl: _firstString(json, ['thumbnail_url', 'image_url', 'image']),
      scientificName: _firstString(json, ['scientific_name', 'latin_name']),
      description: _firstString(json, ['description', 'notes']),
      source: PlantSource.user,
      latitude: _parseDouble(json['lat'] ?? json['latitude']),
      longitude: _parseDouble(json['lng'] ?? json['longitude']),
    );
  }

  /// Dùng cho cache offline (SharedPreferences).
  factory PlantMapMarker.fromCacheJson(Map<String, dynamic> json) {
    return PlantMapMarker(
      id: json['id'] as String? ?? '',
      plantId: json['plantId'] as String? ?? '',
      name: json['name'] as String? ?? 'Cây',
      imageUrl: json['imageUrl'] as String?,
      scientificName: json['scientificName'] as String?,
      description: json['description'] as String?,
      source: (json['source'] as String?) == 'user'
          ? PlantSource.user
          : PlantSource.system,
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'plantId': plantId,
    'name': name,
    'imageUrl': imageUrl,
    'scientificName': scientificName,
    'description': description,
    'source': source == PlantSource.user ? 'user' : 'system',
    'latitude': latitude,
    'longitude': longitude,
  };

  static String? _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return null;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
