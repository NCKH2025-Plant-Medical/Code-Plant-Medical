import re

with open('D:/NCKH2026/PlantVision/lib/services/auth_api_service.dart', 'r', encoding='utf-8') as f:
    text = f.read()

injection = '''
  /// GET /api/auth/check-username
  Future<bool> checkUsername(String username) async {
    try {
      final url = Uri.parse('\/api/auth/check-username?username=\');
      final response = await http.get(url).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['available'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// POST /api/auth/login'''

# We will replace   /// POST /api/auth/login`
text = re.sub(r'  /// POST /api/auth/login', injection, text)

with open('D:/NCKH2026/PlantVision/lib/services/auth_api_service.dart', 'w', encoding='utf-8') as f:
    f.write(text)
