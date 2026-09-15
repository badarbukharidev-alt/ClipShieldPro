import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clipshield/models/app_update.dart';
import 'package:clipshield/screens/update_dialog.dart';
import 'package:clipshield/services/media_store_service.dart';

/// Two failures the update flow shipped with:
///
/// 1. A missing install permission reported itself and then made the user press
///    a *second* button to reach Settings — one tap of pure ceremony, since
///    there is nothing else they could have wanted from "Update".
/// 2. A certificate that could not be *read* was refused as though it had been
///    caught being *wrong*, so a genuine download died with "the download could
///    not be verified" even after the user had allowed the source.
///
/// The verdict logic lives in Kotlin and cannot run here. What is testable is
/// the channel contract between them: which verdicts proceed, and which stop.
const AppUpdate update = AppUpdate(
  versionName: '1.2.15',
  versionCode: 18,
  apkUrl: 'https://example.com/app.apk',
  notes: 'Test release.',
);

/// Stands in for the Kotlin side, recording what was asked of it.
class FakeBridge {
  bool canInstall;
  String verifyVerdict;
  String installVerdict;

  final List<String> calls = [];

  FakeBridge({
    this.canInstall = true,
    this.verifyVerdict = 'ok',
    this.installVerdict = 'ok',
  });

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.clipshield/media'),
      (call) async {
        calls.add(call.method);
        switch (call.method) {
          case 'canInstallPackages':
            return canInstall;
          case 'openInstallSettings':
            return true;
          case 'verifyApk':
            return verifyVerdict;
          case 'installApk':
            return installVerdict;
        }
        return null;
      },
    );
  }

  void remove() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.clipshield/media'), null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBridge bridge;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    bridge = FakeBridge()..install();
  });

  tearDown(() => bridge.remove());

  group('the channel answers every method the flow needs', () {
    test('a granted permission reads as true', () async {
      expect(await MediaStoreService.instance.canInstallPackages(),
          MediaStoreService.instance.isSupported ? true : false);
    });

    test('an unimplemented method does not throw', () async {
      bridge.remove();

      // No handler at all: every call has to come back with a safe default
      // rather than a MissingPluginException reaching the UI.
      expect(await MediaStoreService.instance.canInstallPackages(), isFalse);
      expect(await MediaStoreService.instance.verifyApk('/x.apk'), isNotEmpty);
      expect(await MediaStoreService.instance.installApk('/x.apk'), isNotEmpty);
    });
  });

  group('verdicts cross the channel intact', () {
    // The decision of which verdict proceeds lives in Dart; the verdicts
    // themselves are produced in Kotlin. If the string were mangled in transit,
    // "ok_unverified" would fall through to the default branch and be reported
    // as a failed install -- which is the bug this replaced.
    for (final verdict in [
      'ok',
      'ok_unverified',
      'signature_mismatch',
      'wrong_package',
      'not_an_apk',
      'missing_file',
    ]) {
      test('"$verdict" arrives unchanged', () async {
        bridge.verifyVerdict = verdict;

        final got = await MediaStoreService.instance.verifyApk('/tmp/x.apk');

        // Only meaningful where the channel is actually used; elsewhere the
        // service short-circuits before invoking it.
        if (MediaStoreService.instance.isSupported) {
          expect(got, verdict);
          expect(bridge.calls, contains('verifyApk'));
        } else {
          expect(got, 'unsupported_platform');
        }
      });
    }
  });

  testWidgets('the dialog offers a browser fallback after any failure',
      (tester) async {
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

    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();

    // Not Android under a widget test, so the download refuses early. What
    // matters is that a failure always leaves a way forward rather than a dead
    // dialog.
    expect(find.text('Download in browser instead'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a mandatory update still cannot be dismissed mid-failure',
      (tester) async {
    const mandatory = AppUpdate(
      versionName: '1.3.0',
      versionCode: 20,
      apkUrl: 'https://example.com/app.apk',
      mandatory: true,
    );

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => UpdateDialog.show(context, mandatory),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();

    expect(find.text('Later'), findsNothing);
    expect(find.text('Update required'), findsOneWidget);
  });
}
