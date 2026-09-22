import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clipshield/screens/home_screen.dart';
import 'package:clipshield/theme/app_theme.dart';

Future<void> pumpDashboard(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // The dashboard loads stats on init; without this the plugin channel throws.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('dashboard shows the fast input card', (WidgetTester tester) async {
    await pumpDashboard(tester);

    expect(find.text("ClipShield Studio"), findsOneWidget);
    expect(find.text("FAST INPUT"), findsOneWidget);
    expect(find.text("Paste YouTube link (https://...)"), findsOneWidget);
    expect(find.text("Choose Video or Audio from Storage"), findsOneWidget);
  });

  testWidgets('the licence status card tells a trial user what is left',
      (WidgetTester tester) async {
    // Fresh install with no key defaults to the free trial, so the home screen
    // must state the plan and the renders remaining rather than hiding it.
    await pumpDashboard(tester);

    expect(find.text("Free Trial"), findsOneWidget,
        reason: 'the plan must be named on the home screen');
    expect(find.textContaining("render"), findsWidgets,
        reason: 'a trial user should see how many free renders remain');
  });

  testWidgets('the app icon sits beside the wordmark',
      (WidgetTester tester) async {
    await pumpDashboard(tester);

    // Asset bytes do not decode in the test harness, so assert the widget is
    // wired up rather than what it paints.
    final header = find.ancestor(
      of: find.text("ClipShield Studio"),
      matching: find.byType(Row),
    );
    expect(header, findsWidgets);
    expect(
      find.descendant(of: header.first, matching: find.byType(Image)),
      findsOneWidget,
      reason: 'the launcher icon should render next to the title',
    );
  });

  testWidgets('unselected action tabs are not greyed out',
      (WidgetTester tester) async {
    await pumpDashboard(tester);

    // An unselected tab used to paint AppColors.mut, which read as disabled.
    final shorts = tester.widget<Text>(find.text("AI Shorts"));
    final song = tester.widget<Text>(find.text("Song Copyright"));
    expect(shorts.style?.color, isNot(AppColors.mut));
    expect(song.style?.color, isNot(AppColors.mut));
  });

  testWidgets('all three actions are reachable from one screen',
      (WidgetTester tester) async {
    await pumpDashboard(tester);

    expect(find.text("CHOOSE ACTION"), findsOneWidget);
    expect(find.text("Copyright"), findsOneWidget);
    expect(find.text("AI Shorts"), findsOneWidget);
    expect(find.text("Song Copyright"), findsOneWidget);
  });

  testWidgets('copyright is the default action', (WidgetTester tester) async {
    await pumpDashboard(tester);

    expect(find.text("Long Video Copyright Remover"), findsOneWidget);
    expect(find.text("16:9 COPYRIGHT REMOVER"), findsOneWidget);
    expect(find.text("Start Copyright Protection"), findsOneWidget);
  });

  testWidgets('switching the segment swaps the whole action card',
      (WidgetTester tester) async {
    await pumpDashboard(tester);

    await tester.tap(find.text("AI Shorts"));
    await tester.pumpAndSettle();

    expect(find.text("AI Shorts Generator"), findsOneWidget);
    expect(find.text("Find Best Moments"), findsOneWidget);
    expect(find.text("Long Video Copyright Remover"), findsNothing);

    await tester.tap(find.text("Song Copyright"));
    await tester.pumpAndSettle();

    expect(find.text("Song Copyright Remover"), findsOneWidget);
    expect(find.text("Remove Song Copyright"), findsOneWidget);
  });

  testWidgets('balanced is the default processing preset',
      (WidgetTester tester) async {
    await pumpDashboard(tester);

    // The chip styling encodes selection: the active chip is filled with ink.
    final balanced = tester.widget<Text>(find.text("Balanced"));
    final fast = tester.widget<Text>(find.text("Fast"));
    expect(balanced.style?.color, Colors.white);
    expect(fast.style?.color, isNot(Colors.white));
  });

  testWidgets('the preset row only appears where it is wired through',
      (WidgetTester tester) async {
    await pumpDashboard(tester);

    // Copyright mode passes the preset into TransformPipelineScreen.
    expect(find.text("Processing Preset"), findsOneWidget);
    expect(find.text("Fast"), findsOneWidget);
    expect(find.text("Balanced"), findsOneWidget);
    expect(find.text("Deep"), findsOneWidget);

    // Song Copyright has no preset plumbing, so it must not show a dead control.
    await tester.tap(find.text("Song Copyright"));
    await tester.pumpAndSettle();
    expect(find.text("Processing Preset"), findsNothing);
  });

  testWidgets('starting with no source asks for one instead of navigating',
      (WidgetTester tester) async {
    await pumpDashboard(tester);

    final cta = find.text("Start Copyright Protection");
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    await tester.tap(cta);
    await tester.pump(); // dispatch
    await tester.pump(const Duration(milliseconds: 100)); // snackbar enters

    expect(find.text("Paste a link or choose a file first"), findsOneWidget);
    // Still on the dashboard.
    expect(find.text("FAST INPUT"), findsOneWidget);
  });

  testWidgets('a non-YouTube link is rejected before navigating',
      (WidgetTester tester) async {
    await pumpDashboard(tester);

    await tester.enterText(find.byType(TextField).first, "not-a-link");
    await tester.pump();

    final cta = find.text("Start Copyright Protection");
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    await tester.tap(cta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text("That does not look like a YouTube video or Shorts link"),
      findsOneWidget,
    );
  });

  testWidgets('bottom navigation switches tabs', (WidgetTester tester) async {
    await pumpDashboard(tester);

    expect(find.text("Home"), findsOneWidget);
    expect(find.text("Projects"), findsOneWidget);
    expect(find.text("Settings"), findsOneWidget);

    await tester.tap(find.text("Projects"));
    await tester.pump();
    expect(find.text("FAST INPUT"), findsNothing);
    expect(find.text("Projects & History"), findsOneWidget);
  });
}
