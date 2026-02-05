import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// Model cho Image Response
class ImageResponse {
  final String id;
  final String imageBase64;
  final String capturedAt;

  ImageResponse({
    required this.id,
    required this.imageBase64,
    required this.capturedAt,
  });

  factory ImageResponse.fromJson(Map<String, dynamic> json) {
    return ImageResponse(
      id: json['id'] ?? '',
      imageBase64: json['image_base64'] ?? '',
      capturedAt: json['captured_at'] ?? '',
    );
  }
}

// Model cho Images List Response
class ImagesListResponse {
  final int total;
  final List<ImageResponse> images;

  ImagesListResponse({
    required this.total,
    required this.images,
  });

  factory ImagesListResponse.fromJson(Map<String, dynamic> json) {
    var imagesList = json['images'] as List;
    List<ImageResponse> images =
    imagesList.map((i) => ImageResponse.fromJson(i)).toList();

    return ImagesListResponse(
      total: json['total'] ?? 0,
      images: images,
    );
  }
}

// Model cho Upload Image Response
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

// Service class để gọi API
class ImageService {
  final String baseUrl;

  ImageService({required this.baseUrl});

  Future<ImagesListResponse> getAllImages({
    int limit = 100,
    String orderBy = 'uploaded_at',
  }) async {
    try {
      // Tạo URL với query parameters
      final uri = Uri.parse('$baseUrl/api/images').replace(
        queryParameters: {
          'limit': limit.toString(),
          'order_by': orderBy,
        },
      );

      // Gọi API
      final response = await http.get(uri);

      // Kiểm tra response status
      if (response.statusCode == 200) {
        // Parse JSON response
        final jsonData = json.decode(response.body);
        return ImagesListResponse.fromJson(jsonData);
      } else {
        throw Exception(
            'Failed to load images: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching images: $e');
    }
  }

  /// Upload image to API using multipart/form-data
  ///
  /// Parameters:
  /// - imagePath: Đường dẫn file ảnh cần upload
  /// - capturedAt: Thời gian chụp ảnh (optional, format ISO 8601)
  ///
  /// Returns: UploadImageResponse với thông tin upload
  Future<UploadImageResponse> uploadImage({
    required String imagePath,
    String? capturedAt,
  }) async {
    try {
      // Kiểm tra file có tồn tại không
      final File imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist at path: $imagePath');
      }

      print('📤 Uploading image: $imagePath');

      // Tạo URL
      final uri = Uri.parse('$baseUrl/api/upload-image');

      // Tạo multipart request
      var request = http.MultipartRequest('POST', uri);

      // Thêm file ảnh với field name là 'image'
      request.files.add(
        await http.MultipartFile.fromPath(
          'image', // Field name theo API doc
          imagePath,
        ),
      );

      // Thêm captured_at nếu có
      if (capturedAt != null && capturedAt.isNotEmpty) {
        request.fields['captured_at'] = capturedAt;
        print('📅 Captured at: $capturedAt');
      }

      print('🔄 Sending request to $uri...');

      // Gửi request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 Response status: ${response.statusCode}');

      // Kiểm tra response status
      if (response.statusCode == 200) {
        print('✅ Upload successful!');
        // Parse JSON response
        final jsonData = json.decode(response.body);
        return UploadImageResponse.fromJson(jsonData);
      } else {
        throw Exception(
            'Failed to upload image: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }
}