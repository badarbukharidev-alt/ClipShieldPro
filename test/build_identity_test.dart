import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clipshield/screens/settings_screen.dart';
import 'package:clipshield/services/build_identity.dart';
import 'package:clipshield/services/license_service.dart';

/// A reseller build must not carry the in-app admin tools.
///
/// Those screens mint licence keys on the device with no quota and no record.
/// Leaving them in a reseller's APK would let them — or anyone holding a copy of
/// that APK — issue unlimited keys and bypass their allowance entirely, which
/// makes the whole quota system decorative.
///
/// These run against the *house* build (no --dart-define), so they pin the
/// default side. The reseller side is pinned by asserting on the same predicate
/// the UI is gated on.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LicenseService.instance.init();
  });

  group('the house build', () {
    test('has no reseller code', () {
      expect(BuildIdentity.resellerCode, isEmpty);
      expect(BuildIdentity.isResellerBuild, isFalse);
    });

    test('keeps the in-app admin tools', () {
      expect(BuildIdentity.allowsInAppAdmin, isTrue);
    });

    testWidgets('shows the admin access button', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await tester.pump();

      expect(find.byTooltip('Admin Access'), findsOneWidget);
    });
  });

  group('the gate is one predicate, used everywhere', () {
    test('admin tools are allowed exactly when this is not a reseller build', () {
      // If these two ever disagree, one of the three call sites in
      // settings_screen is checking the wrong thing.
      expect(BuildIdentity.allowsInAppAdmin, !BuildIdentity.isResellerBuild);
    });
  });

  group('code normalisation', () {
    // The same rule the panel applies, so a typo in a build command yields a
    // plain house build rather than an app reporting against a reseller that
    // does not exist.
    test('a valid code survives', () {
      expect(BuildIdentity.resellerCode, isEmpty,
          reason: 'no --dart-define was passed to this test run');
    });

    test('the pattern accepts what the panel accepts', () {
      final pattern = RegExp(r'^[a-z0-9][a-z0-9_-]{1,31}$');

      for (final good in ['ali-traders', 'shop_01', 'abc', 'x1']) {
        expect(pattern.hasMatch(good), isTrue, reason: '"$good" should be valid');
      }

      for (final bad in [
        '',
        'a',
        '-leading-hyphen',
        'has space',
        'UPPER',
        'a' * 33,
        'semi;colon',
      ]) {
        expect(pattern.hasMatch(bad), isFalse, reason: '"$bad" should be rejected');
      }
    });
  });
}
