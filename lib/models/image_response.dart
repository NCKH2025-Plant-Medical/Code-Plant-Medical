class ImageResponse {
  final String id;
  final String imageUrl;
  final String capturedAt;

  ImageResponse({
    required this.id,
    required this.imageUrl,
    required this.capturedAt,
  });

  factory ImageResponse.fromJson(Map<String, dynamic> json) {
    return ImageResponse(
      id: json['id']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      capturedAt: json['captured_at']?.toString() ?? '',
    );
  }
}

class ImagesListResponse {
  final int total;
  final List<ImageResponse> images;

  ImagesListResponse({
    required this.total,
    required this.images,
  });

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

  UploadImageData({
    required this.id,
    required this.capturedAt,
  });

  factory UploadImageData.fromJson(Map<String, dynamic> json) {
    return UploadImageData(
      id: json['id']?.toString() ?? '',
      capturedAt: json['captured_at']?.toString() ?? '',
    );
  }
}
