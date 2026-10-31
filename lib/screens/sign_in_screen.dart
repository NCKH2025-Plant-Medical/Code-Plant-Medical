import 'package:thunghiem1/widgets/error_dialog.dart' as thunghiem1_dialog;
import 'package:thunghiem1/screens/auth/phone_input_screen.dart' as thunghiem1;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:thunghiem1/controllers/auth_notifier.dart';
import 'package:thunghiem1/screens/shell/main_shell.dart';
import 'package:thunghiem1/widgets/primary_button.dart';
import 'package:thunghiem1/widgets/standard_text_field.dart';

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
      thunghiem1_dialog.showErrorDialog(
        context,
        message,
        title: 'Lỗi đăng nhập',
      );
    } else {
      thunghiem1_dialog.showErrorDialog(context, message, title: 'Thành công');
    }
  }

  /// Sau khi đăng nhập thành công → quay về màn hình Home (không phải Account).
  void _goToHome() {
    MainShell.goHome();
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
          _goToHome();
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
          _goToHome();
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Banner co giãn theo chiều cao màn hình để toàn bộ form
          // hiển thị đầy đủ mà không cần cuộn.
          final bannerHeight = (constraints.maxHeight * 0.18).clamp(
            100.0,
            200.0,
          );

          return Column(
            children: [
              _buildBanner(bannerHeight),
              Expanded(child: _buildForm()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBanner(double height) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/img/LoginBanner.jpg', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: DecoratedBox(
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
          ),
          Positioned(
            top: 44,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 17,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      // Đẩy form lên đè nhẹ lên banner cho gọn
      transform: Matrix4.translationValues(0, -22, 0),
      child: SingleChildScrollView(
        // Chỉ cuộn khi màn hình quá thấp; bình thường mọi thứ vừa khít.
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sign in to continue your plant journey.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),

            // Input Email
            const Text(
              'Username',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            StandardTextField(
              hintText: 'Username...',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icon(
                Icons.email_outlined,
                size: 20,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 12),

            // Input Mật khẩu
            const Text(
              'Password',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            StandardTextField(
              hintText: '••••••••',
              controller: _passwordController,
              obscureText: _obscurePassword,
              prefixIcon: Icon(
                Icons.lock_outline,
                size: 20,
                color: Colors.grey.shade500,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
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
            const SizedBox(height: 4),

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
            const SizedBox(height: 14),

            // Nút Sign In (PrimaryButton)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1B4332),
                      ),
                    )
                  : PrimaryButton(
                      text: 'Sign In',
                      onPressed: _isSocialLoading ? null : _signInWithEmail,
                    ),
            ),
            const SizedBox(height: 16),

            // Divider OR CONNECT WITH
            Row(
              children: [
                Expanded(
                  child: Divider(color: Colors.grey.shade300, thickness: 1),
                ),
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
                Expanded(
                  child: Divider(color: Colors.grey.shade300, thickness: 1),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Nút Google
            _buildSocialOutlineButton(
              label: 'Continue with Google',
              onPressed: _isSocialLoading || _isLoading
                  ? () {}
                  : () => _handleSocialLogin(
                      () => context.read<AuthNotifier>().signInWithGoogle(),
                    ),
            ),
            const SizedBox(height: 10),

            // Nút Facebook
            _buildSocialOutlineButton(
              label: 'Continue with Facebook',
              onPressed: _isSocialLoading || _isLoading
                  ? () {}
                  : () => _handleSocialLogin(
                      () => context.read<AuthNotifier>().signInWithFacebook(),
                    ),
            ),
            const SizedBox(height: 8),

            // Facebook (fallback): dùng Firebase OAuth qua trình duyệt,
            // dùng khi SDK Facebook native không mở được.
            TextButton(
              onPressed: _isSocialLoading || _isLoading
                  ? null
                  : () => _handleSocialLogin(
                      () => context
                          .read<AuthNotifier>()
                          .signInWithFacebookViaFirebase(),
                    ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Facebook (khác)?',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),

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
    );
  }

  Widget _buildSocialOutlineButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 46,
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
