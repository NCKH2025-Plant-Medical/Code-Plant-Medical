import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:thunghiem1/config/app_config.dart';

class ApiService {
  final String baseUrl = AppConfig.baseUrl;

  Future<Map<String, dynamic>> predictImage(String imagePath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/predict'),
    );
    request.files.add(await http.MultipartFile.fromPath('file', imagePath));

    final response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      return json.decode(respStr);
    } else {
      throw Exception('Failed to get prediction');
    }
  }
}
