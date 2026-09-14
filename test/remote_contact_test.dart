import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clipshield/services/license_service.dart';
import 'package:clipshield/services/remote_config_service.dart';

/// The support number is now panel-owned. These pin the two properties that
/// matter: a number the panel sends must reach the WhatsApp link, and a
/// response that omits or mangles it must never blank out a working contact.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await RemoteConfigService.instance.load();
  });

  test('falls back to the shipped number before the panel is ever reached', () {
    expect(RemoteConfigService.instance.supportWhatsApp,
        RemoteConfigService.defaultWhatsApp);
    expect(
      LicenseService.instance.getWhatsAppUrl('CS-AAAA-BBBB-CCCC'),
      contains('wa.me/${RemoteConfigService.defaultWhatsApp}'),
    );
  });

  test('adopts a number sent by the panel', () async {
    await RemoteConfigService.instance.applyFromApi({
      'support_whatsapp': '441234567890',
      'support_phone': '01234 567890',
    });

    expect(RemoteConfigService.instance.supportWhatsApp, '441234567890');
    expect(LicenseService.supportPhone, '01234 567890');
    expect(
      LicenseService.instance.getWhatsAppUrl('CS-AAAA-BBBB-CCCC'),
      startsWith('https://wa.me/441234567890?text='),
    );
  });

  test('a response with no contact fields leaves the number alone', () async {
    await RemoteConfigService.instance.applyFromApi({'support_whatsapp': '441234567890'});
    await RemoteConfigService.instance.applyFromApi({'ok': true, 'credits_earned': 3});

    expect(RemoteConfigService.instance.supportWhatsApp, '441234567890');
  });

  test('rubbish in the panel field is rejected rather than shipped', () async {
    await RemoteConfigService.instance.applyFromApi({'support_whatsapp': '441234567890'});

    for (final bad in ['', '   ', 'call me', '12', '9' * 40, "923079031153'; DROP"]) {
      await RemoteConfigService.instance.applyFromApi({'support_whatsapp': bad});
      expect(RemoteConfigService.instance.supportWhatsApp, '441234567890',
          reason: 'rejected input "$bad" must not overwrite a good number');
    }
  });

  test('the number survives a restart', () async {
    await RemoteConfigService.instance.applyFromApi({'support_whatsapp': '441234567890'});
    await RemoteConfigService.instance.load();

    expect(RemoteConfigService.instance.supportWhatsApp, '441234567890');
  });
}
