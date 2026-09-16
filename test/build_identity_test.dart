import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clipshield/screens/settings_screen.dart';
import 'package:clipshield/services/build_identity.dart';
import 'package:clipshield/services/license_service.dart';

/// The reseller code moved from a compile-time define to a bundled asset, so
/// one build can be stamped for every reseller instead of one build each.
///
/// That makes the code *editable inside a finished APK*, which is exactly why
/// the admin gate did NOT move with it: those screens mint licence keys on the
/// device with no quota and no record, so in a reseller build they must be
/// absent rather than hidden behind a flag someone repackaging could flip back.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    BuildIdentity.debugReset();
    await LicenseService.instance.init();
  });

  tearDown(BuildIdentity.debugReset);

  group('reading the stamped code', () {
    test('an unstamped build is the house build', () async {
      // The asset ships holding a placeholder. It must read as "no reseller",
      // not as a reseller literally called __RESELLER__.
      await BuildIdentity.load();

      expect(BuildIdentity.resellerCode, isEmpty);
      expect(BuildIdentity.isResellerBuild, isFalse);
    });

    test('a stamped code is adopted', () {
      BuildIdentity.debugSet('abrar');

      expect(BuildIdentity.resellerCode, 'abrar');
      expect(BuildIdentity.isResellerBuild, isTrue);
    });

    test('the code is normalised the way the panel normalises it', () {
      BuildIdentity.debugSet('  ABRAR  ');
      expect(BuildIdentity.resellerCode, 'abrar');
    });

    test('a bad stamp yields a house build, not a broken reseller', () {
      for (final bad in [
        '',
        '   ',
        '__RESELLER__',
        'a',
        '-leading',
        'has space',
        'semi;colon',
        'x' * 33,
      ]) {
        BuildIdentity.debugSet(bad);
        expect(BuildIdentity.resellerCode, isEmpty,
            reason: '"$bad" must not be accepted as a reseller code');
      }
    });
  });

  group('the admin gate stays a compile-time exclusion', () {
    test('the house build keeps the admin tools', () {
      expect(BuildIdentity.allowsInAppAdmin, isTrue);
    });

    test('stamping a code does not remove them from a house build', () {
      // The point of the separation: the gate is not keyed on the reseller
      // code, so editing the asset cannot toggle it either way.
      BuildIdentity.debugSet('abrar');

      expect(BuildIdentity.allowsInAppAdmin, isTrue,
          reason: 'this build was compiled with the admin tools in; only the '
              'CLIPSHIELD_RESELLER_BASE define removes them');
    });

    testWidgets('settings shows the admin button in a house build',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await tester.pump();

      expect(find.byTooltip('Admin Access'), findsOneWidget);
    });
  });
}
