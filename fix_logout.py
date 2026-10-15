import re

with open('D:/NCKH2026/PlantVision/lib/screens/account_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

old_btn = '''Widget _buildLogoutButton(bool isLoggingOut, AuthNotifier authNotifier) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: TextButton
        (
        onPressed: isLoggingOut ? null : () => authNotifier.logout(),'''

new_btn = '''Widget _buildLogoutButton(bool isLoggingOut, AuthNotifier authNotifier) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: TextButton
        (
        onPressed: isLoggingOut ? null : () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Xác nhận đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
              content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Hủy', style: TextStyle(color: Colors.grey.shade700)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    authNotifier.logout();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Đăng xuất'),
                ),
              ],
            ),
          );
        },'''

text = text.replace(old_btn, new_btn)

with open('D:/NCKH2026/PlantVision/lib/screens/account_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)
