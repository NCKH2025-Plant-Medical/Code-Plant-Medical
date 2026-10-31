import 'package:thunghiem1/widgets/error_dialog.dart' as thunghiem1_dialog;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import 'package:thunghiem1/controllers/auth_notifier.dart';
import 'package:thunghiem1/screens/auth/phone_input_screen.dart';
import 'package:thunghiem1/screens/auth/register_details_screen.dart';
import 'package:thunghiem1/screens/auth/reset_password_screen.dart';
import 'package:thunghiem1/theme/app_colors.dart';

/// OTP verification screen — shared by both the Register and ForgotPassword
/// flows via [PhoneAuthFlow].
///
/// On successful OTP verification:
/// - Register flow  → navigates to [RegisterDetailsScreen] with the Firebase
///   id-token, which then calls the backend and pops back to Account tab.
/// - ForgotPassword → navigates to [ResetPasswordScreen] with the id-token.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.flow});

  final PhoneAuthFlow flow;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // ── OTP input ──────────────────────────────────────────────────────────────
  final _pinController = TextEditingController();
  final _pinFocus = FocusNode();

  // ── Countdown timer ───────────────────────────────────────────────────────
  static const _countdownSeconds = 60;
  int _secondsLeft = _countdownSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocus.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ── Countdown logic ───────────────────────────────────────────────────────

  void _startCountdown() {
    _secondsLeft = _countdownSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  bool get _canResend => _secondsLeft == 0;

  // ── Resend OTP ─────────────────────────────────────────────────────────────

  Future<void> _resend() async {
    if (!_canResend) return;
    _pinController.clear();
    final auth = context.read<AuthNotifier>();
    final success = await auth.resendOtp();
    if (!mounted) return;
    if (success) {
      _startCountdown();
      thunghiem1_dialog.showErrorDialog(
        context,
        'Mã xác minh mới đã được gửi tới ${auth.pendingPhone ?? ""}',
        title: 'Thành công',
      );
    } else {
      _showError(auth.errorMessage ?? 'Gửi lại thất bại.');
    }
  }

  // ── Verify OTP → backend call ─────────────────────────────────────────────

  /// Called when the user taps "Xác nhận" or when Pinput auto-submits
  /// after all 6 digits are entered.
  Future<void> _verify(String code) async {
    if (code.length != 6) {
      _showError('Vui lòng nhập đủ 6 chữ số.');
      return;
    }

    final auth = context.read<AuthNotifier>();

    // ── Step 2: verify OTP with Firebase → get firebase_id_token ───────────
    final idToken = await auth.verifyOtp(code);

    if (!mounted) return;

    if (idToken == null) {
      // Error set by notifier; show it and clear the pin for retry.
      _showError(auth.errorMessage ?? 'Mã OTP không hợp lệ.');
      _pinController.clear();
      return;
    }

    // ── Navigate to the appropriate details screen ──────────────────────────
    if (widget.flow == PhoneAuthFlow.register) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RegisterDetailsScreen(
            firebaseIdToken: idToken,
            phoneNumber: auth.pendingPhone ?? '',
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
            firebaseIdToken: idToken,
            phoneNumber: auth.pendingPhone ?? '',
          ),
        ),
      );
    }
  }

  void _showError(String msg) {
    thunghiem1_dialog.showErrorDialog(context, msg, title: 'Lỗi');
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final isLoading = auth.status == AuthStatus.loading;
    final phone = auth.pendingPhone ?? '';

    // ── Pinput theme ───────────────────────────────────────────────────────
    final defaultPinTheme = PinTheme(
      width: 52,
      height: 60,
      textStyle: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.transparent, width: 1.5),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: AppColors.primary, width: 1.5),
        color: AppColors.primary.withValues(alpha: 0.05),
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: AppColors.primary.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.accent, width: 1.5),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(
          color: AppColors.primary,
          onPressed: () {
            _timer?.cancel();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Nhập mã xác minh',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              // ── Icon ────────────────────────────────────────────────
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sms_outlined,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 28),

              // ── Heading ──────────────────────────────────────────────
              Text(
                'Kiểm tra tin nhắn của bạn',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'Mã 6 chữ số đã được gửi tới\n'),
                    TextSpan(
                      text: phone,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // ── Pinput ───────────────────────────────────────────────
              Pinput(
                controller: _pinController,
                focusNode: _pinFocus,
                length: 6,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: focusedPinTheme,
                submittedPinTheme: submittedPinTheme,
                keyboardType: TextInputType.number,
                autofocus: true,
                // Auto-submit when all 6 digits are entered.
                onCompleted: isLoading ? null : (pin) => _verify(pin),
                hapticFeedbackType: HapticFeedbackType.lightImpact,
              ),
              const SizedBox(height: 40),

              // ── Verify button ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () => _verify(_pinController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.5,
                    ),
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
                          'Xác nhận',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Resend / countdown ───────────────────────────────────
              if (_canResend)
                TextButton(
                  onPressed: isLoading ? null : _resend,
                  child: Text(
                    'Gửi lại mã xác minh',
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Gửi lại mã sau ',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    // Animated countdown badge
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        '${_secondsLeft}s',
                        key: ValueKey(_secondsLeft),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
