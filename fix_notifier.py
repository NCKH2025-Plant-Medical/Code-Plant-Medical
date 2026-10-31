import re
with open('D:/NCKH2026/PlantVision/lib/controllers/auth_notifier.dart', 'r', encoding='utf-8') as f:
    text = f.read()

new_method = '''
  /// Kiểm tra tên đăng nhập đã tồn tại chưa
  Future<bool> checkUsername(String username) async {
    return await _api.checkUsername(username);
  }

  /// Authenticates using a local username/password.'''

text = text.replace('  /// Authenticates using a local username/password.', new_method)

with open('D:/NCKH2026/PlantVision/lib/controllers/auth_notifier.dart', 'w', encoding='utf-8') as f:
    f.write(text)
