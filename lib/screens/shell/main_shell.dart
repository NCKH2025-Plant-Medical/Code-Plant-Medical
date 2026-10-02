import 'package:flutter/material.dart';
import 'package:thunghiem1/screens/account_screen.dart';
import 'package:thunghiem1/screens/camera_screen.dart';
import 'package:thunghiem1/screens/home_screen.dart';
import 'package:thunghiem1/screens/setting_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // index 0=Home, 1=Setting, 2=Account (camera không nằm trong stack)
  int _currentIndex = 0;

  // IndexedStack giữ state tab Home/Setting/Account khi chuyển qua lại
  final List<Widget> _screens = const [
    HomeScreen(),
    SettingScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        // Camera ở giữa (index 1 trong nav bar) nhưng currentIndex không nhảy vào
        currentIndex: _currentIndex >= 1 ? _currentIndex + 1 : _currentIndex,
        onTap: (index) {
          if (index == 1) {
            // Camera tab → push, không thay đổi _currentIndex
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CameraScreen()),
            );
          } else {
            // 0 → Home (stack index 0), 2 → Setting (stack index 1), 3 → Account (stack index 2)
            setState(() => _currentIndex = index > 1 ? index - 1 : index);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Camera'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Setting'),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
