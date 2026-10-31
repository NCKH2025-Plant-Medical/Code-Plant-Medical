import 'package:flutter/material.dart';
import 'package:thunghiem1/screens/camera_screen.dart';
import 'package:thunghiem1/screens/home_screen.dart';
import 'package:thunghiem1/screens/setting_screen.dart';
import 'package:thunghiem1/theme/app_colors.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Key để các màn hình khác (vd: sau khi đăng nhập) yêu cầu shell
  /// chuyển về tab Home.
  static final GlobalKey<MainShellState> shellKey = GlobalKey<MainShellState>();

  /// Đóng toàn bộ route đang mở và đưa người dùng về tab Home.
  static void goHome() {
    final state = shellKey.currentState;
    if (state == null) return;

    state.goToHome();

    // Nếu đang ở route con (Sign In, OTP, ...) thì pop về shell.
    final navigator = Navigator.maybeOf(state.context);
    if (navigator != null && navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  // index 0 = Home, 1 = Setting (Camera được push, không nằm trong stack)
  int _currentIndex = 0;

  /// Chuyển về tab Home.
  void goToHome() {
    if (!mounted) return;
    setState(() => _currentIndex = 0);
  }

  void _onTap(int navIndex) {
    if (navIndex == 1) {
      // Nút Camera ở chính giữa → mở màn hình chụp, giữ nguyên tab hiện tại
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CameraScreen()),
      );
    } else {
      // 0 → Home, 2 → Setting
      setState(() => _currentIndex = navIndex > 1 ? navIndex - 1 : navIndex);
    }
  }

  /// Chỉ số tương ứng Home / Setting (Camera không có tab riêng)
  int get _navIndex => _currentIndex == 0 ? 0 : 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [HomeScreen(), SettingScreen()],
      ),
      bottomNavigationBar: _AppBottomBar(
        currentIndex: _navIndex,
        onTap: _onTap,
      ),
    );
  }
}

/// Bottom bar tuỳ biến: Home - [Camera nổi bật ở giữa] - Setting.
class _AppBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _AppBottomBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : Colors.white;

    return SizedBox(
      height: 80,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Nền của thanh điều hướng
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      isSelected: currentIndex == 0,
                      onTap: () => onTap(0),
                    ),
                  ),
                  // Khoảng trống ở giữa dành cho nút Camera
                  const SizedBox(width: 88),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.settings_rounded,
                      label: 'Setting',
                      isSelected: currentIndex == 2,
                      onTap: () => onTap(2),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Nút Camera nổi bật, đặt chính giữa (nổi lên trên thanh)
          Positioned(
            bottom: 20,
            child: GestureDetector(
              onTap: () => onTap(1),
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: surface, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? AppColors.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 6),
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
