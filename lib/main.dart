import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:thunghiem1/app.dart';
import 'package:thunghiem1/theme/theme_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final themeNotifier = ThemeNotifier();
  await themeNotifier.load();

  runApp(PlantVisionApp(themeNotifier: themeNotifier));
}
