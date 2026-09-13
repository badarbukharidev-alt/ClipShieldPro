import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clipshield/models/app_modes.dart';
import 'package:clipshield/screens/home_screen.dart';
import 'package:clipshield/theme/app_theme.dart';

/// Widths covering small (360), common (411) and large (480) Android phones.
const List<double> _phoneWidths = [360, 411, 480];

Future<void> pumpAt(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width * 2, 890 * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: const HomeScreen(),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in _phoneWidths) {
    testWidgets('dashboard lays out without overflow at ${width.toInt()}dp',
        (WidgetTester tester) async {
      await pumpAt(tester, width);
      expect(tester.takeException(), isNull,
          reason: 'the dashboard overflowed at ${width.toInt()}dp');
    });

    testWidgets('every action card lays out without overflow at ${width.toInt()}dp',
        (WidgetTester tester) async {
      await pumpAt(tester, width);

      for (final label in ['AI Shorts', 'Song DSP', 'Copyright']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '$label overflowed at ${width.toInt()}dp');
      }
    });
  }

  testWidgets('copyright is the first segment, not the enum default order',
      (WidgetTester tester) async {
    await pumpAt(tester, 411);

    // AppMode declares longVideoToShorts first; the dashboard must still lead
    // with Copyright to match the intended action order.
    final segments = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((d) => d == 'Copyright' || d == 'AI Shorts' || d == 'Song DSP')
        .toList();

    expect(segments, ['Copyright', 'AI Shorts', 'Song DSP']);
    expect(AppMode.values.first, AppMode.longVideoToShorts,
        reason: 'guards the assumption this ordering exists to correct');
  });

  testWidgets('all three preset chips stay reachable', (WidgetTester tester) async {
    await pumpAt(tester, 360);

    for (final chip in ['Fast', 'Balanced', 'Deep']) {
      final finder = find.text(chip);
      expect(finder, findsOneWidget);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
