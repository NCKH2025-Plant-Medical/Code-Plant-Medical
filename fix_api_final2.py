with open('D:/NCKH2026/PlantVision/lib/services/auth_api_service.dart', 'r', encoding='utf-8') as f:
    text = f.read()

injection = '''throw AuthException(message, statusCode: response.statusCode);
  }

  /// GET /api/auth/check-username
  Future<bool> checkUsername(String username) async {
    try {
      final url = Uri.parse('\/api/auth/check-username?username=\');
      final response = await http.get(url).timeout(_timeout);
      if (response.statusCode == 200) {
        import 'dart:convert';
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['available'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }'''

text = text.replace('throw AuthException(message, statusCode: response.statusCode);\n  }', injection)

with open('D:/NCKH2026/PlantVision/lib/services/auth_api_service.dart', 'w', encoding='utf-8') as f:
    f.write(text)
