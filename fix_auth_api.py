import re

with open('D:/NCKH2026/PlantVision/lib/services/auth_api_service.dart', 'r', encoding='utf-8') as f:
    text = f.read()

new_method = '''Future<bool> checkUsername(String username) async {
    try {
      final url = Uri.parse('/check-username?username=\');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['available'] ?? false;
      }
      return false;
    } catch (e) {
      return false; // Assuming not available on error to be safe or maybe handle it differently
    }
  }

  /// Khởi tạo'''

text = text.replace('/// Khởi tạo', new_method)

with open('D:/NCKH2026/PlantVision/lib/services/auth_api_service.dart', 'w', encoding='utf-8') as f:
    f.write(text)
