import re

with open('D:/NCKH2026/PlantVision/lib/screens/sign_in_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

old_social = '''if (success) {
            Navigator.pop(context);
          } else if (auth.errorMessage != null) {'''

new_social = '''if (success) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainShell()),
              (route) => false,
            );
          } else if (auth.errorMessage != null) {'''

text = text.replace(old_social, new_social)

with open('D:/NCKH2026/PlantVision/lib/screens/sign_in_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)
