import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipshield/screens/home_screen.dart';
import 'package:clipshield/theme/app_theme.dart';

void main() {
  testWidgets('ClipShieldProApp HomeScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("ClipShield Studio"), findsOneWidget);
    expect(find.text("Long Video Copyright Remover"), findsOneWidget);
    expect(find.text("Long Video → Shorts"), findsOneWidget);
  });
}
