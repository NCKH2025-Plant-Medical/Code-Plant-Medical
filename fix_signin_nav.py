import re

with open('D:/NCKH2026/PlantVision/lib/screens/sign_in_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Make sure to import MainShell
if 'package:thunghiem1/screens/shell/main_shell.dart' not in text:
    text = 'import \'package:thunghiem1/screens/shell/main_shell.dart\';\n' + text

old_success = '''if (success) {
            Navigator.pop(context);
          } else {'''

new_success = '''if (success) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainShell()),
              (route) => false,
            );
          } else {'''

text = text.replace(old_success, new_success)

with open('D:/NCKH2026/PlantVision/lib/screens/sign_in_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)
