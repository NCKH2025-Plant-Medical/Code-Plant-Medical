class ImageResponse {
  final String id;
  final String? plantId;
  final String imageUrl;
  final String capturedAt;

  /// Vĩ độ lúc chụp (null nếu không có dữ liệu GPS).
  final double? latitude;

  /// Kinh độ lúc chụp (null nếu không có dữ liệu GPS).
  final double? longitude;

  /// Tên cây (nếu backend trả về).
  final String? commonName;
  final String? scientificName;
  final double? confidence;
  final String? notes;
  final String? thumbnailUrl;

  String get displayImageUrl =>
      thumbnailUrl?.isNotEmpty == true ? thumbnailUrl! : imageUrl;

  DateTime? get savedAt {
    if (!RegExp(
      r'(Z|[+-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(capturedAt)) {
      return DateTime.tryParse('${capturedAt}Z');
    }
    return DateTime.tryParse(capturedAt);
  }

  String get savedAtLabel {
    final date = savedAt?.toLocal();
    if (date == null) return 'Chưa có thời gian lưu';
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${pad(date.day)}/${pad(date.month)}/${date.year} '
        '${pad(date.hour)}:${pad(date.minute)}';
  }

  ImageResponse({
    required this.id,
    this.plantId,
    required this.imageUrl,
    required this.capturedAt,
    this.latitude,
    this.longitude,
    this.commonName,
    this.scientificName,
    this.confidence,
    this.notes,
    this.thumbnailUrl,
  });

  factory ImageResponse.fromJson(Map<String, dynamic> json) {
    return ImageResponse(
      id: json['id']?.toString() ?? '',
      plantId: json['plant_id']?.toString(),
      imageUrl: json['image_url']?.toString() ?? '',
      capturedAt: (json['captured_at'] ?? json['created_at'])?.toString() ?? '',
      latitude: _parseDouble(json['latitude'] ?? json['lat']),
      longitude: _parseDouble(json['longitude'] ?? json['lng'] ?? json['lon']),
      commonName: (json['common_name'] ?? json['name'])?.toString(),
      scientificName: json['scientific_name']?.toString(),
      confidence: _parseDouble(json['confidence']),
      notes: json['notes']?.toString(),
      thumbnailUrl: json['thumbnail_url']?.toString(),
    );
  }

  /// Có tọa độ hợp lệ để hiển thị icon bản đồ không.
  bool get hasLocation =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180;

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
      capturedAt: (json['captured_at'] ?? json['created_at'])?.toString() ?? '',
    );
  }
}
