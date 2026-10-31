import re

with open('D:/NCKH2026/PlantVision/lib/screens/sign_up_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Using regex to find the section
text = re.sub(r'const Text\(\s*\'X.*c nh.*n m.*t kh.*u\',[\s\S]*?const SizedBox\(height: 28\),', 'const SizedBox(height: 28),', text)

with open('D:/NCKH2026/PlantVision/lib/screens/sign_up_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)
