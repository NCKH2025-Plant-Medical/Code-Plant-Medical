import re
with open('D:/NCKH2026/PlantVision/lib/screens/auth/register_details_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

submit_mod = '''  Future<void> _submit() async {
    if (_isCheckingUsername) return; // Wait for check
    if (_isUsernameAvailable == false) {
      thunghiem1_dialog.showErrorDialog(context, 'Tên đăng nhập đã tồn tại', title: 'Lỗi');
      return;
    }
    if (!_formKey.currentState!.validate()) return;'''

text = text.replace('  Future<void> _submit() async {\n    if (!_formKey.currentState!.validate()) return;', submit_mod)

with open('D:/NCKH2026/PlantVision/lib/screens/auth/register_details_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)
