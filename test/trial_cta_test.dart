import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clipshield/screens/activation_dialog.dart';
import 'package:clipshield/screens/tasks_screen.dart';
import 'package:clipshield/services/license_service.dart';

/// This dialog appears at exactly the moment someone runs out of trial
/// renders — which is when they most need to know free ones are earnable.
/// Before, the only things on screen were "buy a key" and "close".
Future<void> openDialog(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => ActivationDialog.show(context),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LicenseService.instance.init();
  });

  testWidgets('the trial dialog offers the free route', (tester) async {
    await openDialog(tester);

    expect(find.text('Get free videos'), findsOneWidget);
    expect(find.textContaining('Complete quick tasks'), findsOneWidget);
  });

  testWidgets('the copy names both routes, not just the paid one',
      (tester) async {
    await openDialog(tester);

    expect(find.textContaining('Earn more free videos'), findsOneWidget);
  });

  testWidgets('tapping it closes the dialog and opens Tasks', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('Get free videos'));
    await tester.pumpAndSettle();

    expect(find.byType(TasksScreen), findsOneWidget);
    expect(find.text('Unlock ClipShield Pro'), findsNothing,
        reason: 'the dialog must close, so back from Tasks returns to the app '
            'rather than to a licence prompt');
  });

  testWidgets('an existing balance is stated rather than asked for again',
      (tester) async {
    await LicenseService.instance.applyBonusBalance(3, 0);
    await openDialog(tester);

    expect(find.text('You have 3 free videos'), findsOneWidget);
    expect(find.text('Get free videos'), findsNothing);
  });

  testWidgets('one credit is singular', (tester) async {
    await LicenseService.instance.applyBonusBalance(1, 0);
    await openDialog(tester);

    expect(find.text('You have 1 free video'), findsOneWidget);
  });

  testWidgets('the paid route is still there', (tester) async {
    await openDialog(tester);

    expect(find.text('Activate ClipShield Pro'), findsOneWidget);
    expect(find.textContaining('Order Key via WhatsApp'), findsOneWidget);
  });
}
