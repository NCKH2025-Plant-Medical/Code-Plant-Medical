import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thunghiem1/screens/shell/main_shell.dart';
import 'package:thunghiem1/theme/app_theme.dart';
import 'package:thunghiem1/theme/theme_notifier.dart';

class PlantVisionApp extends StatelessWidget {
  const PlantVisionApp({super.key, required this.themeNotifier});

  final ThemeNotifier themeNotifier;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) {
        final brightness = _resolveBrightness(themeNotifier.themeMode);
        _applySystemUiOverlay(brightness);

        return ThemeScope(
          notifier: themeNotifier,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeNotifier.themeMode,
            home: const MainShell(),
          ),
        );
      },
    );
  }

  Brightness _resolveBrightness(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
  }

  void _applySystemUiOverlay(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );
  }
}

class ThemeScope extends InheritedWidget {
  const ThemeScope({
    super.key,
    required this.notifier,
    required super.child,
  });

  final ThemeNotifier notifier;

  static ThemeNotifier of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope not found in widget tree');
    return scope!.notifier;
  }

  @override
  bool updateShouldNotify(ThemeScope oldWidget) {
    return notifier != oldWidget.notifier;
  }
}
