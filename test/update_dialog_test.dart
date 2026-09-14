import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clipshield/models/app_update.dart';
import 'package:clipshield/screens/update_dialog.dart';
import 'package:clipshield/services/update_service.dart';

const AppUpdate optional = AppUpdate(
  versionName: '1.2.11',
  versionCode: 14,
  apkUrl: 'https://example.com/app.apk',
  notes: 'Faster renders on long videos.',
);

const AppUpdate required_ = AppUpdate(
  versionName: '1.3.0',
  versionCode: 20,
  apkUrl: 'https://example.com/app.apk',
  mandatory: true,
);

Future<void> openDialog(WidgetTester tester, AppUpdate update) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => UpdateDialog.show(context, update),
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
    await UpdateService.instance.init();
  });

  testWidgets('an optional update can be dismissed', (tester) async {
    await openDialog(tester, optional);

    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Version 1.2.11'), findsOneWidget);
    expect(find.text('Faster renders on long videos.'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('a mandatory update offers no way out', (tester) async {
    await openDialog(tester, required_);

    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Later'), findsNothing,
        reason: 'a mandatory update must not offer a dismiss button');

    // Tapping the barrier must not close it either.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Update required'), findsOneWidget);
  });

  testWidgets('"Later" records the skip so the prompt does not return',
      (tester) async {
    final service = UpdateService.instance;
    service.debugSetCurrent(13, '1.2.10');
    await service.applyFromApi({
      'update': {
        'version_name': '1.2.11',
        'version_code': 14,
        'apk_url': 'https://example.com/app.apk',
      }
    });
    expect(service.shouldPrompt, isTrue);

    await openDialog(tester, service.latest.value!);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(service.shouldPrompt, isFalse);
    expect(service.isUpdateAvailable, isTrue,
        reason: 'still reachable from Settings after being dismissed');
  });

  testWidgets('a release with no notes still lays out', (tester) async {
    await openDialog(
      tester,
      const AppUpdate(
        versionName: '1.2.11',
        versionCode: 14,
        apkUrl: 'https://example.com/app.apk',
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Update available'), findsOneWidget);
  });

  testWidgets('long release notes scroll instead of overflowing',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await openDialog(
      tester,
      AppUpdate(
        versionName: '1.2.11',
        versionCode: 14,
        apkUrl: 'https://example.com/app.apk',
        notes: List.filled(40, 'Another line of release notes.').join(' '),
      ),
    );

    expect(tester.takeException(), isNull,
        reason: 'a long changelog on a small screen must not overflow');
  });
}
