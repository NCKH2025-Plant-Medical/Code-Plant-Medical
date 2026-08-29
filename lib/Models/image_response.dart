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
      id: json['id'] ?? '',
      imageUrl: json['image_url'] ?? '',
      capturedAt: json['captured_at'] ?? '',
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
    final images = imagesList.map((i) => ImageResponse.fromJson(i)).toList();

    return ImagesListResponse(
      total: json['total'] ?? 0,
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
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null
          ? UploadImageData.fromJson(json['data'])
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
      id: json['id'] ?? '',
      capturedAt: json['captured_at'] ?? '',
    );
  }
}
