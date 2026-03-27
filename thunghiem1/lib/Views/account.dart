import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Account extends StatefulWidget {
  const Account({super.key});

  @override
  State<Account> createState() => _AccountState();
}

class _AccountState extends State<Account> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        decoration: BoxDecoration(
          color: Colors.grey[50], // Tương tự màu nền trong home.dart của bạn
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Phần Logo hoặc Hình ảnh minh họa
            Container(
              height: 150,
              width: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withOpacity(0.1),
              ),
              child: const Icon(Icons.eco, size: 80, color: Colors.green),
            ),
            const SizedBox(height: 40),

            Text(
              'Chào mừng bạn',
              style: GoogleFonts.roboto(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 50),

            // Nút đăng nhập Google
            _buildSocialButton(
              label: 'Đăng nhập với Google',
              icon: Icons.g_mobiledata_outlined,
              color: Colors.white,
              textColor: Colors.black87,
              onPressed: () {
                // Logic xử lý đăng nhập Google
                print("Login with Google");
              },
            ),

            const SizedBox(height: 15),

            // Nút đăng nhập Facebook
            _buildSocialButton(
              label: 'Đăng nhập với Facebook',
              icon: Icons.facebook,
              color: const Color(0xFF1877F2),
              textColor: Colors.white,
              onPressed: () {
                // Logic xử lý đăng nhập Facebook
                print("Login with Facebook");
              },
            ),
          ],
        ),
      ),
    );
  }

  // Widget dùng chung cho các nút mạng xã hội
  Widget _buildSocialButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: textColor, size: 30),
        label: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: color == Colors.white
                ? BorderSide(color: Colors.grey.shade300)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}