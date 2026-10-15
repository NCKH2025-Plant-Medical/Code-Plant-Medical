import 'package:thunghiem1/screens/shell/main_shell.dart';
import 'package:thunghiem1/widgets/error_dialog.dart' as thunghiem1_dialog;
import 'package:thunghiem1/screens/auth/phone_input_screen.dart' as thunghiem1;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:thunghiem1/controllers/auth_notifier.dart';
import 'package:thunghiem1/widgets/primary_button.dart';
import 'package:thunghiem1/widgets/standard_text_field.dart';
import 'package:thunghiem1/screens/sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isSocialLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    if (isError) {
      thunghiem1_dialog.showErrorDialog(context, message, title: 'Lỗi đăng nhập');
    } else {
      thunghiem1_dialog.showErrorDialog(context, message, title: 'Thành công');
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Vui lòng nhập đầy đủ email và mật khẩu');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthNotifier>();
      final success = await auth.login(username: email, password: password);
      if (mounted) {
        if (success) {
          Navigator.pop(context);
        } else {
          _showSnackBar(auth.errorMessage ?? 'Đăng nhập thất bại');
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSocialLogin(Future<bool> Function() loginFn) async {
    setState(() => _isSocialLoading = true);
    try {
      final auth = context.read<AuthNotifier>();
      final success = await loginFn();
      if (mounted) {
        if (success) {
          Navigator.pop(context);
        } else if (auth.errorMessage != null) {
          _showSnackBar(auth.errorMessage!);
        }
      }
    } finally {
      if (mounted) setState(() => _isSocialLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildLoginView(),
    );
  }

  Widget _buildLoginView() {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height + mediaQuery.viewInsets.bottom;

    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              // Banner ảnh lá cây ở nửa trên
              Stack(
                children: [
                  Container(
                    height: screenHeight * 0.38,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/img/LoginBanner.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(
                    height: screenHeight * 0.38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.2),
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                  // Back button overlay
                  Positioned(
                    top: 50,
                    left: 20,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),

              // Container bo góc trắng chứa form đăng nhập
              Transform.translate(
                offset: const Offset(0, -32),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(36),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back',
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in to continue your plant journey.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Input Email
                      const Text(
                        'Username',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StandardTextField(
                        hintText: 'Username...',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icon(Icons.email_outlined, size: 20, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 16),

                      // Input Mật khẩu
                      const Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StandardTextField(
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
                      ),
                      const SizedBox(height: 10),

                      // Quên mật khẩu
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const thunghiem1.PhoneInputScreen(
                                  flow: thunghiem1.PhoneAuthFlow.forgotPassword,
                                ),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(
                              color: Color(0xFF1B4332),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Nút Sign In (PrimaryButton)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B4332)))
                            : PrimaryButton(
                                text: 'Sign In',
                                onPressed: _isSocialLoading ? null : _signInWithEmail,
                              ),
                      ),
                      const SizedBox(height: 24),

                      // Divider OR CONNECT WITH
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'OR CONNECT WITH',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Nút Google
                      _buildSocialOutlineButton(
                        label: 'Continue with Google',
                        onPressed: _isSocialLoading || _isLoading
                            ? () {}
                            : () => _handleSocialLogin(
                                  () => context.read<AuthNotifier>().signInWithGoogle(),
                                ),
                      ),
                      const SizedBox(height: 12),

                      // Nút Facebook
                      _buildSocialOutlineButton(
                        label: 'Continue with Facebook',
                        onPressed: _isSocialLoading || _isLoading
                            ? () {}
                            : () => _handleSocialLogin(
                                  () => context.read<AuthNotifier>().signInWithFacebook(),
                                ),
                      ),
                      const SizedBox(height: 24),

                      // Footer chuyển sang đăng ký
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const thunghiem1.PhoneInputScreen(
                                      flow: thunghiem1.PhoneAuthFlow.register,
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                'Create an account',
                                style: TextStyle(
                                  color: Color(0xFF1B4332),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isSocialLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.35),
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B4332)),
            ),
          ),
      ],
    );
  }

  Widget _buildSocialOutlineButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          backgroundColor: Colors.white,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}