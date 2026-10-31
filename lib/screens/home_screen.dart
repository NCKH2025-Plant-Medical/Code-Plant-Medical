import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:thunghiem1/controllers/auth_notifier.dart';
import 'package:thunghiem1/services/disclaimer_service.dart';
import 'package:thunghiem1/widgets/search_text_field.dart';
import 'package:thunghiem1/screens/map_screen.dart';
import 'package:thunghiem1/screens/search_screen.dart';
import 'package:thunghiem1/screens/chat_ai_screen.dart';
import 'package:thunghiem1/screens/account_screen.dart';
import 'package:thunghiem1/widgets/action_cards.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Hiển thị hộp thoại cảnh báo sau khi giao diện render xong.
    // - Chưa đăng nhập: hiện mỗi lần mở app.
    // - Đã đăng nhập: chỉ hiện duy nhất 1 lần.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowDisclaimer();
    });
  }

  Future<void> _maybeShowDisclaimer() async {
    if (!mounted) return;
    final auth = context.read<AuthNotifier>();
    // Chờ đọc xong trạng thái đăng nhập đã lưu để quyết định đúng luật hiển thị.
    await auth.ready;
    if (!mounted) return;
    final isAuthenticated = auth.isAuthenticated;
    final shouldShow = await DisclaimerService.instance.shouldShow(
      isAuthenticated: isAuthenticated,
    );
    if (!shouldShow || !mounted) return;
    _showDisclaimerDialog(isAuthenticated: isAuthenticated);
  }

  void _showDisclaimerDialog({required bool isAuthenticated}) {
    showDialog(
      context: context,
      barrierDismissible:
          false, // Bắt buộc người dùng bấm đồng ý mới đóng dialog
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFD97706),
                size: 28,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Lưu ý quan trọng',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF1B4332),
                  ),
                ),
              ),
            ],
          ),
          content: const SingleChildScrollView(
            child: Text(
              'Mọi thông tin nhận diện, đặc tính và công dụng dược liệu trên ứng dụng chỉ mang tính chất tham khảo, nghiên cứu và học tập.\n\n'
              'Chúng tôi không chịu bất kỳ trách nhiệm pháp lý nào đối với các rủi ro, tổn thất hoặc vấn đề sức khỏe phát sinh do việc tự ý chẩn đoán, điều trị hoặc áp dụng thông tin từ ứng dụng mà không có sự chỉ định hay tư vấn chuyên môn từ bác sĩ/chuyên gia y tế.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  DisclaimerService.instance.markAccepted(
                    isAuthenticated: isAuthenticated,
                  );
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B4332),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Tôi đã hiểu và đồng ý',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SingleChildScrollView(
        child: SafeArea(
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      offset: const Offset(2, 0),
                      color: isDark ? Colors.black54 : Colors.grey,
                      blurRadius: 0.9,
                    ),
                  ],
                ),
                child: Image.asset('assets/img/Banner.jpg'),
              ),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20.0, 40.0, 20.0, 0.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Hello',
                          style: GoogleFonts.darkerGrotesque(
                            fontSize: 31,
                            color: Colors.white70,
                            fontWeight: FontWeight.w800,
                            shadows: const [
                              Shadow(
                                offset: Offset(0.8, 0.8),
                                blurRadius: 1.5,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        // Nút Account thay cho kính lúp / chuông
                        _HomeAccountButton(onTap: _openAccount),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20.0, 5.0, 20.0, 0.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Welcome to Plant Vision',
                          style: GoogleFonts.darkerGrotesque(
                            color: Colors.white70,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            shadows: const [
                              Shadow(
                                offset: Offset(0.8, 0.8),
                                blurRadius: 1.5,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22.0, 24.0, 22.0, 0.0),
                    child: SearchTextField(
                      hintText: 'Searching',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SearchScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24.0, 40.0, 24.0, 0.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ActionCard(
                            title: 'Plant Map',
                            subtitle: 'Hello',
                            icon: Icons.map_outlined,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const PlantMapScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ActionCard(
                            title: 'Hỏi đáp AI',
                            subtitle: 'Hello',
                            icon: Icons.chat_bubble_outline_rounded,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ChatAiScreen(),
                                ),
                              );
                            },
                          ),
                        ),                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ActionCard(
                            title: 'Chức năng 3',
                            subtitle: 'Hello',
                            icon: Icons.grid_view_rounded,
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ActionCard(
                            title: 'Chức năng 4',
                            subtitle: 'Hello',
                            icon: Icons.widgets_outlined,
                            onTap: () {},
                          ),
                        ),
                      ],
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

/// Nút Account đặt ở góc trên phải màn hình Home.
class _HomeAccountButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HomeAccountButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthNotifier>(
      builder: (context, auth, _) {
        final avatarUrl = auth.userProfile?['avatar_url'] as String?;
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.25),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    )
                  : const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
            ),
          ),
        );
      },
    );
  }
}
