import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:thunghiem1/app.dart';
import 'package:thunghiem1/firebase_options.dart';
import 'package:thunghiem1/theme/theme_notifier.dart';

import 'package:thunghiem1/widgets/error_dialog.dart';

void _showGlobalError(String message) {
  final context = globalNavigatorKey.currentContext;
  if (context != null) {
    showErrorDialog(context, message, title: 'Lỗi ứng dụng');
  } else {
    final messenger = globalSnackbarKey.currentState;
    if (messenger != null) {
      // Snackbars are disabled per user request.
      // print('Lỗi ứng dụng (no context): $message');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch Flutter UI errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _showGlobalError('Lỗi giao diện: ${details.exceptionAsString()}');
  };

  // Catch asynchronous errors
  PlatformDispatcher.instance.onError = (error, stack) {
    _showGlobalError('Lỗi không xác định: $error');
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Container(
      color: Colors.red.shade100,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          'Đã xảy ra lỗi hiển thị (Vui lòng kiểm tra log)',
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  };

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final themeNotifier = ThemeNotifier();
  await themeNotifier.load();

  runApp(PlantVisionApp(themeNotifier: themeNotifier));
}
