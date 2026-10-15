import re

with open('D:/NCKH2026/PlantVision/lib/screens/sign_in_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Add _obscurePassword state
text = text.replace('bool _isLoading = false;', 'bool _isLoading = false;\n  bool _obscurePassword = true;')

# Update StandardTextField for password
old_field = '''StandardTextField(
                        hintText: '••••••••',
                        controller: _passwordController,
                        obscureText: true,
                        prefixIcon: Icon(Icons.lock_outline, size: 20, color: Colors.grey.shade500),
                      ),'''

new_field = '''StandardTextField(
                        hintText: '••••••••',
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        prefixIcon: Icon(Icons.lock_outline, size: 20, color: Colors.grey.shade500),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.grey.shade500,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),'''

text = text.replace(old_field, new_field)

with open('D:/NCKH2026/PlantVision/lib/screens/sign_in_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)
