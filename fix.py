import re

with open('D:/NCKH2026/PlantVision/lib/services/auth_api_service.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Replace the whole block starting from /// GET /api/auth/check-username
text = re.sub(
    r'  /// GET /api/auth/check-username[\S\s]*?return false;\n    \}\n  \}',
    '''  /// GET /api/auth/check-username\n  Future<bool> checkUsername(String username) async {\n    try {\n      final url = Uri.parse('\${_base}/api/auth/check-username?username=\$username');\n      final response = await http.get(url).timeout(_timeout);\n      if (response.statusCode == 200) {\n        final data = json.decode(utf8.decode(response.bodyBytes));\n        return data['available'] ?? false;\n      }\n      return false;\n    } catch (e) {\n      return false;\n    }\n  }''',
    text
)

with open('D:/NCKH2026/PlantVision/lib/services/auth_api_service.dart', 'w', encoding='utf-8') as f:
    f.write(text)
