import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clipshield/screens/settings_screen.dart';
import 'package:clipshield/services/build_identity.dart';
import 'package:clipshield/services/license_service.dart';

/// The reseller base build: admin tools compiled out.
///
/// Only meaningful with the define set, so run it as:
///
///   flutter test test/reseller_build_test.dart \
///     --dart-define=CLIPSHIELD_RESELLER_BASE=true
///
/// Without it every case skips itself rather than passing vacuously, which
/// would be worse than not having the test at all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // allowsInAppAdmin is false only when the base define is set.
  final bool isBase = !BuildIdentity.allowsInAppAdmin;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    BuildIdentity.debugReset();
    await LicenseService.instance.init();
  });

  tearDown(BuildIdentity.debugReset);

  test('the define reached the build', () {
    if (!isBase) return;
    expect(BuildIdentity.allowsInAppAdmin, isFalse);
  });

  test('editing the stamped code cannot bring the admin tools back', () {
    if (!isBase) return;

    // This is the property that justifies keeping the gate compiled in while
    // the reseller code is a swappable asset.
    BuildIdentity.debugSet('abrar');
    expect(BuildIdentity.allowsInAppAdmin, isFalse);

    BuildIdentity.debugSet('');
    expect(BuildIdentity.allowsInAppAdmin, isFalse,
        reason: 'clearing the reseller code must not re-enable the admin tools');
  });

  testWidgets('settings shows no admin access button', (tester) async {
    if (!isBase) return;

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();

    expect(find.byTooltip('Admin Access'), findsNothing);
  });
}
