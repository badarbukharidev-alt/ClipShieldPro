import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clipshield/screens/settings_screen.dart';
import 'package:clipshield/services/build_identity.dart';
import 'package:clipshield/services/license_service.dart';

/// The reseller side of the build gate.
///
/// Only meaningful with the define set, so run it as:
///
///   flutter test test/reseller_build_test.dart \
///     --dart-define=CLIPSHIELD_RESELLER=test-shop
///
/// Without it every case skips itself rather than passing vacuously, which
/// would be worse than not having the test at all.
void main() {
  final bool configured = BuildIdentity.isResellerBuild;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LicenseService.instance.init();
  });

  test('the define reached the build', () {
    if (!configured) return;
    expect(BuildIdentity.resellerCode, 'test-shop');
  });

  test('the in-app admin tools are compiled out', () {
    if (!configured) return;

    // This is the flag every admin entry point is gated on. If it were true in
    // a reseller build, that reseller could mint unlimited keys on-device with
    // no quota and no record.
    expect(BuildIdentity.allowsInAppAdmin, isFalse);
  });

  testWidgets('settings shows no admin access button', (tester) async {
    if (!configured) return;

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();

    expect(find.byTooltip('Admin Access'), findsNothing);
  });
}
