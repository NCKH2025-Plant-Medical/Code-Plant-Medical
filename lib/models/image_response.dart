class ImageResponse {
  final String id;
  final String imageUrl;
  final String capturedAt;

  /// Vĩ độ lúc chụp (null nếu không có dữ liệu GPS).
  final double? latitude;

  /// Kinh độ lúc chụp (null nếu không có dữ liệu GPS).
  final double? longitude;

  /// Tên cây (nếu backend trả về).
  final String? commonName;

  ImageResponse({
    required this.id,
    required this.imageUrl,
    required this.capturedAt,
    this.latitude,
    this.longitude,
    this.commonName,
  });

  factory ImageResponse.fromJson(Map<String, dynamic> json) {
    return ImageResponse(
      id: json['id']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      capturedAt: json['captured_at']?.toString() ?? '',
      latitude: _parseDouble(json['latitude'] ?? json['lat']),
      longitude: _parseDouble(json['longitude'] ?? json['lng'] ?? json['lon']),
      commonName: (json['common_name'] ?? json['name'])?.toString(),
    );
  }

  /// Có tọa độ hợp lệ để hiển thị icon bản đồ không.
  bool get hasLocation =>
      latitude != null && longitude != null && latitude != 0 && longitude != 0;

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }
}

class ImagesListResponse {
  final int total;
  final List<ImageResponse> images;

  ImagesListResponse({required this.total, required this.images});

  factory ImagesListResponse.fromJson(Map<String, dynamic> json) {
    final imagesList = json['images'] as List? ?? [];
    // Bỏ qua phần tử không phải Map để tránh crash
    final images = imagesList
        .whereType<Map<String, dynamic>>()
        .map((i) => ImageResponse.fromJson(i))
        .toList();

    return ImagesListResponse(
      total: json['total'] as int? ?? 0,
      images: images,
    );
  }
}

class UploadImageResponse {
  final bool success;
  final String message;
  final UploadImageData? data;

  UploadImageResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory UploadImageResponse.fromJson(Map<String, dynamic> json) {
    return UploadImageResponse(
      success: json['success'] as bool? ?? false,
      message: json['message']?.toString() ?? '',
      data: json['data'] is Map<String, dynamic>
          ? UploadImageData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

class UploadImageData {
  final String id;
  final String capturedAt;

  UploadImageData({required this.id, required this.capturedAt});

  factory UploadImageData.fromJson(Map<String, dynamic> json) {
    return UploadImageData(
      id: json['id']?.toString() ?? '',
      capturedAt: json['captured_at']?.toString() ?? '',
    );
  }
}
