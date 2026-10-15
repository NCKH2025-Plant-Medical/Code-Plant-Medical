import re

with open('D:/NCKH2026/PlantVision/lib/screens/sign_up_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Remove validation block
val_pattern = r'if \(password != confirmPassword\) \{[\s\S]*?\}'
text = re.sub(val_pattern, '', text)

# Remove confirmPassword extracting
text = text.replace('final confirmPassword = _confirmPasswordController.text.trim();', '')

# Update empty check
text = text.replace('if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {', 'if (email.isEmpty || password.isEmpty) {')

# Find the start of confirm password field and remove it
confirm_field_pattern = r'// XAc nh-n m-t khcu.*?const SizedBox\(height: 32\),'
# Because of encoding, let's just use a more forgiving regex
confirm_field_pattern2 = r'// Xác nhận mật khẩu[\s\S]*?const SizedBox\(height: 32\),'
text = re.sub(r'// XAc.*?const SizedBox\(height: 32\),', 'const SizedBox(height: 32),', text, flags=re.DOTALL)
text = re.sub(r'// Xác.*?const SizedBox\(height: 32\),', 'const SizedBox(height: 32),', text, flags=re.DOTALL)

with open('D:/NCKH2026/PlantVision/lib/screens/sign_up_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)
