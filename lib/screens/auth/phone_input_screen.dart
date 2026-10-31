import 'package:thunghiem1/widgets/error_dialog.dart' as thunghiem1_dialog;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:thunghiem1/controllers/auth_notifier.dart';
import 'package:thunghiem1/screens/auth/otp_screen.dart';
import 'package:thunghiem1/theme/app_colors.dart';

/// Screen that collects the user's phone number before sending an OTP.
///
/// [flowType] controls whether this is the Registration flow or the
/// Forgot-Password flow — shared UI, different next-step semantics.
enum PhoneAuthFlow { register, forgotPassword }

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key, required this.flow});

  final PhoneAuthFlow flow;

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  // Selected dial code — defaults to Vietnam (+84).
  String _dialCode = '+84';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _fullPhoneNumber {
    // Strip leading zero from local number (Vietnamese convention).
    final local = _phoneController.text.trim().replaceAll(RegExp(r'^0'), '');
    return '$_dialCode$local';
  }

  String get _title =>
      widget.flow == PhoneAuthFlow.register ? 'Tạo tài khoản' : 'Quên mật khẩu';

  String get _subtitle => widget.flow == PhoneAuthFlow.register
      ? 'Nhập số điện thoại để nhận mã xác minh'
      : 'Nhập số điện thoại đã đăng ký để đặt lại mật khẩu';

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthNotifier>();
    final success = await auth.sendOtp(
      _fullPhoneNumber,
      isRegister: widget.flow == PhoneAuthFlow.register,
    );

    if (!mounted) return;

    if (success) {
      // Navigate to OTP screen and pass the flow type along.
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OtpScreen(flow: widget.flow)),
      );
    } else {
      // Error is already stored in auth.errorMessage — show SnackBar.
      _showError(auth.errorMessage ?? 'Gửi OTP thất bại.');
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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _subtitle,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),

                // Phone Input Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DialCodePicker(
                      selected: _dialCode,
                      onChanged: (val) => setState(() => _dialCode = val),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => isLoading ? null : _submit(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Nhập số điện thoại',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w400,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF3F4F6),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.redAccent,
                              width: 1,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.redAccent,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Vui lòng nhập số điện thoại';
                          }
                          if (v.trim().length < 8) {
                            return 'Số điện thoại không hợp lệ';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Hint ───────────────────────────────────────────────
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Mã xác minh sẽ được gửi qua SMS',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // ── Submit button ──────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
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
                            'Gửi mã xác minh',
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
}

// ── Dial-code picker widget ────────────────────────────────────────────────────

class _DialCodePicker extends StatelessWidget {
  const _DialCodePicker({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  static const _codes = {
    '🇻🇳': '+84',
    '🇺🇸': '+1',
    '🇬🇧': '+44',
    '🇯🇵': '+81',
    '🇰🇷': '+82',
    '🇸🇬': '+65',
  };

  @override
  Widget build(BuildContext context) {
    final flag = _codes.entries
        .firstWhere(
          (e) => e.value == selected,
          orElse: () => const MapEntry('🇻🇳', '+84'),
        )
        .key;

    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _CodePickerSheet(
          codes: _codes,
          selected: selected,
          onPick: (code) {
            onChanged(code);
            Navigator.pop(context);
          },
        ),
      ),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Text(
              selected,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _CodePickerSheet extends StatelessWidget {
  const _CodePickerSheet({
    required this.codes,
    required this.selected,
    required this.onPick,
  });

  final Map<String, String> codes;
  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chọn vùng quốc gia',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...codes.entries.map(
            (e) => ListTile(
              leading: Text(e.key, style: const TextStyle(fontSize: 24)),
              title: Text(e.value),
              trailing: e.value == selected
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () => onPick(e.value),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
