import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:thunghiem1/models/image_response.dart';

class ImageService {
  final String baseUrl;

  ImageService({required this.baseUrl});

  Future<ImagesListResponse> getAllImages({
    int limit = 100,
    String orderBy = 'uploaded_at',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/images').replace(
        queryParameters: {
          'limit': limit.toString(),
          'order_by': orderBy,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ImagesListResponse.fromJson(jsonData);
      } else {
        throw Exception(
          'Failed to load images: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching images: $e');
    }
  }

  Future<UploadImageResponse> uploadImage({
    required String imagePath,
    String? capturedAt,
  }) async {
    try {
      final File imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist at path: $imagePath');
      }

      final uri = Uri.parse('$baseUrl/api/upload-image');
      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath('image', imagePath),
      );

      if (capturedAt != null && capturedAt.isNotEmpty) {
        request.fields['captured_at'] = capturedAt;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return UploadImageResponse.fromJson(jsonData);
      } else {
        throw Exception(
          'Failed to upload image: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }
}
