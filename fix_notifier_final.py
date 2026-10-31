import re
with open('D:/NCKH2026/PlantVision/lib/controllers/auth_notifier.dart', 'r', encoding='utf-8') as f:
    text = f.read()

new_method = '''  Future<bool> checkUsername(String username) async {
    return await _api.checkUsername(username);
  }

  /// Authenticates with [username] + [password] against the FastAPI backend.'''

text = text.replace('  /// Authenticates with [username] + [password] against the FastAPI backend.', new_method)

with open('D:/NCKH2026/PlantVision/lib/controllers/auth_notifier.dart', 'w', encoding='utf-8') as f:
    f.write(text)
