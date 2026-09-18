import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clipshield/screens/settings_screen.dart';
import 'package:clipshield/services/build_identity.dart';
import 'package:clipshield/services/license_service.dart';

/// The shield in Settings has two jobs depending on the build: the admin
/// passcode on the house build, reseller sign-in on a reseller build. These pin
/// that the right one shows, since a reseller must never reach the passcode
/// screen (unlimited on-device keys) and the house build must keep it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    BuildIdentity.debugReset();
    await LicenseService.instance.init();
  });

  tearDown(BuildIdentity.debugReset);

  testWidgets('house build shows Admin Access, not the reseller key icon',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();

    expect(find.byTooltip('Admin Access'), findsOneWidget);
    expect(find.byTooltip('Reseller keys'), findsNothing);
  });

  testWidgets('a stamped reseller build shows the reseller key icon instead',
      (tester) async {
    BuildIdentity.debugSet('abrar');

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();

    expect(find.byTooltip('Reseller keys'), findsOneWidget);
    expect(find.byTooltip('Admin Access'), findsNothing,
        reason: 'a reseller must never reach the unlimited on-device key screen');
  });
}
