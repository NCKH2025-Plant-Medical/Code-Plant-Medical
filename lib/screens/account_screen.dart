import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:thunghiem1/controllers/auth_notifier.dart';
import 'package:thunghiem1/screens/history_screen.dart';
import 'package:thunghiem1/screens/sign_in_screen.dart';
import 'package:thunghiem1/screens/auth/phone_input_screen.dart';
import 'package:thunghiem1/theme/app_colors.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to authentication state changes
    final isAuthenticated = context.select<AuthNotifier, bool>(
      (n) => n.isAuthenticated,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isAuthenticated ? 'Hồ sơ cá nhân' : 'Tài khoản',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      body: isAuthenticated ? const _LoggedInView() : const _GuestView(),
    );
  }
}

class _GuestView extends StatelessWidget {
  const _GuestView();

  @override
  Widget build(BuildContext context) {
    // TẠM ẨN: không cho xem lịch sử nhận diện khi chưa đăng nhập.
    // Để bật lại, bỏ comment khối Padding "Lịch sử nhận diện" bên dưới.
    return Column(
      children: [
        // Padding(
        //   padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        //   child: Container(
        //     decoration: BoxDecoration(
        //       color: Theme.of(context).cardColor,
        //       borderRadius: BorderRadius.circular(24),
        //       boxShadow: [
        //         BoxShadow(
        //           color: Colors.black.withValues(alpha: 0.04),
        //           blurRadius: 16,
        //           offset: const Offset(0, 4),
        //         ),
        //       ],
        //     ),
        //     child: _ModernMenuTile(
        //       icon: Icons.history_rounded,
        //       title: 'Lịch sử nhận diện',
        //       iconColor: Colors.blue.shade600,
        //       onTap: () {
        //         Navigator.push(
        //           context,
        //           MaterialPageRoute(builder: (_) => const ImagesListScreen()),
        //         );
        //       },
        //       isFirst: true,
        //       isLast: true,
        //     ),
        //   ),
        // ),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_circle_outlined,
                size: 80,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Đăng nhập để trải nghiệm\nđầy đủ tính năng',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Lưu trữ lịch sử nhận diện, đánh dấu cây yêu thích và đồng bộ trên các thiết bị.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),

            // Login Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'Đăng nhập',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Register Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const PhoneInputScreen(flow: PhoneAuthFlow.register),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'Tạo tài khoản mới',
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
    );
  }
}

class _LoggedInView extends StatelessWidget {
  const _LoggedInView();

  @override
  Widget build(BuildContext context) {
    final authNotifier = context.watch<AuthNotifier>();
    final isLoggingOut = authNotifier.status == AuthStatus.loading;
    final displayName = authNotifier.displayName;
    final avatarUrl = authNotifier.avatarUrl;

    return SafeArea(
      child: Column(
        children: [
          // 1. Header Section (User Profile)
          _buildProfileHeader(context, displayName, avatarUrl, authNotifier),

          const SizedBox(height: 28),

          // 2. Body Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  // Menu Group Card
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _ModernMenuTile(
                          icon: Icons.history_rounded,
                          title: 'Lịch sử nhận diện',
                          iconColor: Colors.blue.shade600,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ImagesListScreen(),
                              ),
                            );
                          },
                          isFirst: true,
                        ),
                        const Divider(
                          height: 1,
                          indent: 56,
                          endIndent: 16,
                          color: Colors.black12,
                        ),
                        _ModernMenuTile(
                          icon: Icons.favorite_rounded,
                          title: 'Cây đã lưu',
                          iconColor: Colors.pink.shade500,
                          onTap: () {},
                        ),
                        const Divider(
                          height: 1,
                          indent: 56,
                          endIndent: 16,
                          color: Colors.black12,
                        ),
                        _ModernMenuTile(
                          icon: Icons.settings_rounded,
                          title: 'Cài đặt',
                          iconColor: Colors.grey.shade700,
                          onTap: () {},
                          isLast: true,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // 3. Logout Button
                  _buildLogoutButton(context, isLoggingOut, authNotifier),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET CHỨC NĂNG ---

  Widget _buildProfileHeader(
    BuildContext context,
    String displayName,
    String? avatarUrl,
    AuthNotifier authNotifier,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, left: 24.0, right: 24.0),
      child: Row(
        children: [
          // Avatar với viền bọc ngoài (Stroke)
          Container(
            padding: const EdgeInsets.all(3), // Độ dày viền
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? const Icon(
                      Icons.person_rounded,
                      size: 36,
                      color: AppColors.primary,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // TẠM ẨN: nút đổi tên người dùng.
                    // Để bật lại, bỏ comment IconButton bên dưới.
                    // IconButton(
                    //   visualDensity: VisualDensity.compact,
                    //   padding: EdgeInsets.zero,
                    //   constraints: const BoxConstraints(),
                    //   tooltip: 'Đổi tên người dùng',
                    //   icon: Icon(
                    //     Icons.edit_outlined,
                    //     size: 18,
                    //     color: Colors.grey.shade600,
                    //   ),
                    //   onPressed: () => _showEditNameDialog(
                    //     context,
                    //     authNotifier,
                    //     displayName,
                    //   ),
                    // ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green.shade500,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Đã kết nối',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TẠM ẨN: dialog đổi tên (dùng lại khi bật nút sửa tên).
  // ignore: unused_element
  Future<void> _showEditNameDialog(
    BuildContext context,
    AuthNotifier authNotifier,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Đổi tên người dùng',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          maxLength: 50,
          decoration: InputDecoration(
            hintText: 'Nhập tên mới...',
            counterText: '',
            filled: true,
            fillColor: const Color(0xFFF3F4F6),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (value) => Navigator.pop(ctx, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (newName == null) return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == currentName) return;

    final ok = await authNotifier.updateDisplayName(trimmed);
    if (!context.mounted) return;
    if (!ok) {
      final msg = authNotifier.errorMessage ?? 'Không thể đổi tên.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Widget _buildLogoutButton(
    BuildContext context,
    bool isLoggingOut,
    AuthNotifier authNotifier,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: TextButton(
        onPressed: isLoggingOut
            ? null
            : () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Text(
                      'Xác nhận đăng xuất',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    content: const Text(
                      'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Hủy',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          authNotifier.logout();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Đăng xuất'),
                      ),
                    ],
                  ),
                );
              },
        style: TextButton.styleFrom(
          backgroundColor: Colors.red.shade50,
          foregroundColor: Colors.red.shade700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // Bo góc mềm mại kiểu M3
          ),
        ),
        child: isLoggingOut
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.red.shade400,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    size: 22,
                    color: Colors.red.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Đăng xuất',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// Widget Menu thiết kế chuẩn Material với hiệu ứng chạm
class _ModernMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  const _ModernMenuTile({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(24) : Radius.zero,
          bottom: isLast ? const Radius.circular(24) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
