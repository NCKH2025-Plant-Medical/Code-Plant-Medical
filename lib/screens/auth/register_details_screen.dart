import 'dart:async';
import 'package:thunghiem1/widgets/error_dialog.dart' as thunghiem1_dialog;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:thunghiem1/controllers/auth_notifier.dart';
import 'package:thunghiem1/theme/app_colors.dart';

/// Final step of the Registration flow.
///
/// Receives [firebaseIdToken] (from OTP verification) and [phoneNumber]
/// from [OtpScreen], then collects username + password and calls the
/// FastAPI `/api/auth/register` endpoint.
///
/// On success, [Navigator.popUntil] returns the user all the way back
/// to the Account tab, which will automatically show the logged-in view
/// because [AuthNotifier.isAuthenticated] is now `true`.
class RegisterDetailsScreen extends StatefulWidget {
  const RegisterDetailsScreen({
    super.key,
    required this.firebaseIdToken,
    required this.phoneNumber,
  });

  final String firebaseIdToken;
  final String phoneNumber;

  @override
  State<RegisterDetailsScreen> createState() => _RegisterDetailsScreenState();
}

class _RegisterDetailsScreenState extends State<RegisterDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();


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



  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_isCheckingUsername) return; // Wait for check
    if (_isUsernameAvailable == false) {
      thunghiem1_dialog.showErrorDialog(context, 'Tên đăng nhập đã tồn tại', title: 'Lỗi');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthNotifier>();

    // ── Step 4 & 5: backend register → save JWT → update auth state ────────
    final success = await auth.register(
      username: _usernameController.text.trim(),
      phoneNumber: widget.phoneNumber,
      password: _passwordController.text,
      firebaseIdToken: widget.firebaseIdToken,
    );

    if (!mounted) return;

    if (success) {
      // ── Navigation rule: pop entire auth stack back to Account tab ─────
      // We use popUntil(first) to clear PhoneInput + OTP + this screen,
      // returning to the shell. The AccountScreen listens to AuthNotifier
      // and will automatically show the logged-in profile.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _showError(auth.errorMessage ?? 'Đăng ký thất bại.');
    }
  }

  void _showError(String msg) {
    thunghiem1_dialog.showErrorDialog(context, msg, title: 'Lỗi');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final isLoading = auth.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đăng ký tài khoản',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Vui lòng điền thông tin cho tài khoản của bạn.',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.5),
                ),
                const SizedBox(height: 40),

                // Username field
                _FieldLabel('Tên đăng nhập'),
                const SizedBox(height: 8),
                TextFormField(
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
                ),
                const SizedBox(height: 16),

                // Password field
                _FieldLabel('Mật khẩu'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hint: '••••••••',
                    icon: Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: Colors.grey.shade500,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                    if (v.length < 6) {
                      return 'Mật khẩu phải từ 6 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password field
                _FieldLabel('Xác nhận mật khẩu'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => isLoading ? null : _submit(),
                  decoration: _inputDecoration(
                    hint: '••••••••',
                    icon: Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: Colors.grey.shade500,
                      ),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Vui lòng xác nhận mật khẩu';
                    }
                    if (v != _passwordController.text) {
                      return 'Mật khẩu xác nhận không khớp';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 36),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Tạo tài khoản',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade500),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}

// ── Helper widget ─────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      );
}
