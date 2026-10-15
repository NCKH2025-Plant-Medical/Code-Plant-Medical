import re
with open('D:/NCKH2026/PlantVision/lib/screens/auth/register_details_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

old_field = '''TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hint: 'Ví dụ: NguyenVanA',
                    icon: Icons.person_outline,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Vui lòng nhập tên đăng nhập';
                    }
                    return null;
                  },
                ),'''

new_field = '''TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hint: 'Ví dụ: NguyenVanA',
                    icon: Icons.person_outline,
                    suffix: _isCheckingUsername
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : (_isUsernameAvailable == true
                            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                            : (_isUsernameAvailable == false
                                ? const Icon(Icons.cancel, color: Colors.red, size: 20)
                                : null)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Vui lòng nhập tên đăng nhập';
                    }
                    if (_isUsernameAvailable == false) {
                      return 'Tên đăng nhập đã tồn tại';
                    }
                    return null;
                  },
                ),'''

# Handle encoding differences by regex matching the structure
text = re.sub(r'TextFormField\(\s*controller: _usernameController,\s*textInputAction: TextInputAction\.next,\s*decoration: _inputDecoration\([\s\S]*?validator: \(v\) \{[\s\S]*?return null;\s*\},[\s\n]*\),', new_field, text)

with open('D:/NCKH2026/PlantVision/lib/screens/auth/register_details_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)
