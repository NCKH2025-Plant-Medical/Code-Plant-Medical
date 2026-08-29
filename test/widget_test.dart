import 'package:flutter_test/flutter_test.dart';
import 'package:thunghiem1/app.dart';
import 'package:thunghiem1/theme/theme_notifier.dart';

void main() {
  testWidgets('App loads home screen', (WidgetTester tester) async {
    final themeNotifier = ThemeNotifier();

    await tester.pumpWidget(PlantVisionApp(themeNotifier: themeNotifier));
    await tester.pumpAndSettle();

    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Welcome to Plant Vision'), findsOneWidget);
  });
}
