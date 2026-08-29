import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:thunghiem1/app.dart';
import 'package:thunghiem1/theme/theme_notifier.dart';

// Thêm dòng import này để nhận diện cấu hình Firebase
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cập nhật hàm khởi tạo Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final themeNotifier = ThemeNotifier();
  await themeNotifier.load();

  runApp(PlantVisionApp(themeNotifier: themeNotifier));
}