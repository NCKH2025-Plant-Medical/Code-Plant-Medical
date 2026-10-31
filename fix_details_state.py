import re
with open('D:/NCKH2026/PlantVision/lib/screens/auth/register_details_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Make sure dart:async is imported for Timer
if 'dart:async' not in text:
    text = 'import \'dart:async\';\n' + text

state_injection = '''
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  Timer? _debounce;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
  }

  void _onUsernameChanged() {
    final val = _usernameController.text.trim();
    if (val.isEmpty) {
      setState(() {
        _isUsernameAvailable = null;
        _isCheckingUsername = false;
      });
      return;
    }

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    setState(() {
      _isCheckingUsername = true;
      _isUsernameAvailable = null;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final auth = context.read<AuthNotifier>();
      final isAvailable = await auth.checkUsername(val);
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = isAvailable;
        });
      }
    });
  }
'''

text = text.replace('  bool _obscurePassword = true;\n  bool _obscureConfirm = true;', state_injection)

# Add dispose for timer
dispose_injection = '''
  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.removeListener(_onUsernameChanged);'''
text = text.replace('  @override\n  void dispose() {', dispose_injection)

with open('D:/NCKH2026/PlantVision/lib/screens/auth/register_details_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)
