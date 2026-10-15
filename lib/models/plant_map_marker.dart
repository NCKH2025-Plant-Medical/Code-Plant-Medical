import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:thunghiem1/core/cluster/cluster_item.dart';

/// Nguồn dữ liệu của marker — phân biệt MySQL (system) vs MongoDB (user)
enum PlantSource { system, user }

/// Model đại diện cho một cây trên bản đồ.
/// Dùng [ClusterItem] mixin để tương thích với cluster manager.
class PlantMapMarker with ClusterItem {
  final String id;
  final String name;
  final String? imageUrl;
  final PlantSource source;
  final double latitude;
  final double longitude;

  PlantMapMarker({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.source,
    required this.latitude,
    required this.longitude,
  });

  @override
  LatLng get location => LatLng(latitude, longitude);

  // ── Factory constructors ──────────────────────────────────────────────────

  /// Parse từ JSON của API System-Plants (MySQL)
  factory PlantMapMarker.fromSystemJson(Map<String, dynamic> json) {
    return PlantMapMarker(
      id: 'sys_${json['id'] ?? json['_id'] ?? ''}',
      name: json['name'] as String? ?? 'Cây hệ thống',
      imageUrl: json['image_url'] as String?,
      source: PlantSource.system,
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
    );
  }

  /// Parse từ JSON của API User-Plants (MongoDB)
  factory PlantMapMarker.fromUserJson(Map<String, dynamic> json) {
    return PlantMapMarker(
      id: 'usr_${json['id'] ?? json['_id'] ?? ''}',
      name: json['name'] as String? ?? 'Cây cá nhân',
      // Backend trả về field "thumbnail_url" (khớp với UserPlantMapItem schema)
      imageUrl: json['thumbnail_url'] as String?,
      source: PlantSource.user,
      latitude: _parseDouble(json['lat']),
      longitude: _parseDouble(json['lng']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
