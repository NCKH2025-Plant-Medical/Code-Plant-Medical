// lib/models/user_plant.dart
//
// Model cho cây cá nhân do chính người dùng chụp & lưu vào bản đồ.
//
// Nguồn dữ liệu: MongoDB (API /api/v1/user-plants).
// Được dùng cho:
//   • Lưu cây mới (POST multipart) sau khi nhận diện ảnh.
//   • Hiển thị Quick View / chi tiết cây cá nhân trên bản đồ.
//   • Hiển thị lịch sử chụp có tọa độ GPS.

class UserPlant {
  /// ID từ backend (MongoDB ObjectId dạng string).
  final String id;

  /// ID cây trong hệ thống (plant_id) — có thể rỗng nếu user tự nhập.
  final String plantId;

  /// Tên cây (common_name).
  final String name;

  /// Tên khoa học.
  final String? scientificName;

  /// Ảnh (URL sau khi upload lên Cloudinary).
  final String? imageUrl;

  /// Ảnh thumbnail.
  final String? thumbnailUrl;

  /// Mô tả / ghi chú của user.
  final String? notes;

  /// Độ tin cậy nhận diện (0..100).
  final double? confidence;

  /// Tọa độ lúc chụp.
  final double? latitude;
  final double? longitude;

  /// Thời điểm chụp.
  final DateTime? capturedAt;

  const UserPlant({
    required this.id,
    this.plantId = '',
    required this.name,
    this.scientificName,
    this.imageUrl,
    this.thumbnailUrl,
    this.notes,
    this.confidence,
    this.latitude,
    this.longitude,
    this.capturedAt,
  });

  /// Parse từ JSON của API user-plants.
  ///
  /// Backend có thể trả về biến thể field khác nhau giữa MySQL và MongoDB
  /// → thử nhiều key, giá trị thiếu thì để null thay vì crash.
  factory UserPlant.fromJson(Map<String, dynamic> json) {
    return UserPlant(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      plantId: (json['plant_id'] ?? json['plantId'] ?? '').toString(),
      name:
          _firstString(json, ['name', 'common_name', 'commonName']) ??
          'Cây của tôi',
      scientificName: _firstString(json, [
        'scientific_name',
        'scientificName',
        'latin_name',
      ]),
      imageUrl: _firstString(json, ['image_url', 'imageUrl']),
      thumbnailUrl: _firstString(json, ['thumbnail_url', 'thumbnailUrl']),
      notes: _firstString(json, ['notes', 'description']),
      confidence: _parseDouble(json['confidence']),
      latitude: _parseDouble(json['latitude'] ?? json['lat']),
      longitude: _parseDouble(json['longitude'] ?? json['lng'] ?? json['lon']),
      capturedAt: DateTime.tryParse(
        (json['captured_at'] ?? json['capturedAt'] ?? '').toString(),
      ),
    );
  }

  /// Ảnh nào nên hiển thị (ưu tiên thumbnail → image).
  String? get displayImageUrl {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) return thumbnailUrl;
    return imageUrl;
  }

  /// Dựng [UserPlant] từ marker trên bản đồ.
  ///
  /// Marker chỉ mang thông tin tối giản (tên, ảnh, tọa độ) → đủ để hiển thị
  /// Quick View / chi tiết cây cá nhân mà không cần gọi thêm API.
  factory UserPlant.fromMapMarker({
    required String id,
    required String plantId,
    required String name,
    String? scientificName,
    String? imageUrl,
    String? description,
    double? latitude,
    double? longitude,
  }) {
    return UserPlant(
      id: id,
      plantId: plantId,
      name: name,
      scientificName: scientificName,
      imageUrl: imageUrl,
      thumbnailUrl: imageUrl,
      notes: description,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Có tọa độ hợp lệ để hiển thị trên bản đồ không.
  bool get hasLocation =>
      latitude != null && longitude != null && latitude != 0 && longitude != 0;

  static String? _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v is String && v.trim().isNotEmpty) return v;
      if (v is num) return v.toString();
    }
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll('%', '').trim());
    }
    return null;
  }
}
