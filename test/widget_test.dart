import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  testWidgets('dashboard shows the fast input card', (WidgetTester tester) async {
    await pumpDashboard(tester);

    expect(find.text("ClipShield Studio"), findsOneWidget);
    expect(find.text("FAST INPUT"), findsOneWidget);
    expect(find.text("Paste YouTube link (https://...)"), findsOneWidget);
    expect(find.text("Choose Video or Audio from Storage"), findsOneWidget);
  });

  testWidgets('all three actions are reachable from one screen',
      (WidgetTester tester) async {
    await pumpDashboard(tester);

    expect(find.text("CHOOSE ACTION"), findsOneWidget);
    expect(find.text("Copyright"), findsOneWidget);
    expect(find.text("AI Shorts"), findsOneWidget);
    expect(find.text("Song DSP"), findsOneWidget);
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

    await tester.tap(find.text("Song DSP"));
    await tester.pumpAndSettle();

    expect(find.text("Song DSP & Cover Export"), findsOneWidget);
    expect(find.text("Open Song DSP"), findsOneWidget);
  });

  testWidgets('the preset row only appears where it is wired through',
      (WidgetTester tester) async {
    await pumpDashboard(tester);

    // Copyright mode passes the preset into TransformPipelineScreen.
    expect(find.text("Processing Preset"), findsOneWidget);
    expect(find.text("Fast"), findsOneWidget);
    expect(find.text("Balanced"), findsOneWidget);
    expect(find.text("Deep"), findsOneWidget);

    // Song DSP has no preset plumbing, so it must not show a dead control.
    await tester.tap(find.text("Song DSP"));
    await tester.pumpAndSettle();
    expect(find.text("Processing Preset"), findsNothing);
  });

  testWidgets('starting with no source asks for one instead of navigating',
      (WidgetTester tester) async {
    await pumpDashboard(tester);

    await tester.tap(find.text("Start Copyright Protection"));
    await tester.pump();

    expect(find.text("Paste a link or choose a file first"), findsOneWidget);
    // Still on the dashboard.
    expect(find.text("FAST INPUT"), findsOneWidget);
  });

  testWidgets('a non-YouTube link is rejected before navigating',
      (WidgetTester tester) async {
    await pumpDashboard(tester);

    await tester.enterText(find.byType(TextField).first, "not-a-link");
    await tester.pump();

    await tester.tap(find.text("Start Copyright Protection"));
    await tester.pump();

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
    await tester.pumpAndSettle();
    expect(find.text("FAST INPUT"), findsNothing);
  });
}
