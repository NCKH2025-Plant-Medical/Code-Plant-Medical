import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:thunghiem1/controllers/auth_notifier.dart';
import 'package:thunghiem1/screens/shell/main_shell.dart';
import 'package:thunghiem1/theme/app_theme.dart';
import 'package:thunghiem1/theme/theme_notifier.dart';

final GlobalKey<ScaffoldMessengerState> globalSnackbarKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

class PlantVisionApp extends StatelessWidget {
  const PlantVisionApp({super.key, required this.themeNotifier});

  final ThemeNotifier themeNotifier;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // AuthNotifier is created here once; its init() is called via
        // the lazy:false flag so the token check happens immediately.
        ChangeNotifierProvider<AuthNotifier>(
          create: (_) => AuthNotifier()..init(),
        ),
      ],
      child: ListenableBuilder(
        listenable: themeNotifier,
        builder: (context, _) {
          final brightness = _resolveBrightness(themeNotifier.themeMode);
          final isDark = brightness == Brightness.dark;

          final overlayStyle = SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          );

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlayStyle,
            child: ThemeScope(
              notifier: themeNotifier,
              child: MaterialApp(
                scaffoldMessengerKey: globalSnackbarKey,
                navigatorKey: globalNavigatorKey,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: themeNotifier.themeMode,
                home: const MainShell(),
              ),
            ),
          );
        },
      ),
    );
  }

  Brightness _resolveBrightness(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.system:
        return WidgetsBinding
            .instance.platformDispatcher.platformBrightness;
    }
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
    final scope =
        context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope not found in widget tree');
    return scope!.notifier;
  }

  @override
  bool updateShouldNotify(ThemeScope oldWidget) {
    return notifier != oldWidget.notifier;
  }
}

