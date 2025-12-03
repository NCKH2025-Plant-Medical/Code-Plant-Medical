import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = "http://172.20.10.14:5000";


  Future<Map<String, dynamic>> predictImage(String imagePath) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/predict'),
    );
    request.files.add(await http.MultipartFile.fromPath('file', imagePath));

    var response = await request.send();
    if (response.statusCode == 200) {
      var respStr = await response.stream.bytesToString();
      return json.decode(respStr);
    } else {
      throw Exception("Failed to get prediction");
    }
  }
}