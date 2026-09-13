import 'package:flutter_test/flutter_test.dart';
import 'package:clipshield/services/license_service.dart';

/// Pins the Dart key generator against known-good vectors.
///
/// The PHP admin panel (ClipShield-Admin/inc/license.php) implements the same
/// HMAC scheme and must produce these exact strings. If either side drifts,
/// keys minted on the server stop validating in the app — so these vectors are
/// the contract between the two codebases. Do not "fix" a failure here by
/// editing the expected values.
void main() {
  const device = 'CS-A1B2-C3D4-E5F6';

  group('cross-port key vectors', () {
    test('lifetime', () {
      expect(
        LicenseService.generateLifetimeKey(device),
        'CSL-4D4D-F0C6-E5B9-8EDE',
      );
    });

    test('monthly 30 days', () {
      expect(
        LicenseService.generateMonthlyKey(device, days: 30),
        'CSM30-0B7E-58AE-0CEC-5030',
      );
    });

    test('video pack of 5', () {
      expect(
        LicenseService.generateVideoPackKey(device, videoCount: 5),
        'CSV05-8A28-B441-F7C1-E6FB',
      );
    });
  });

  group('generated keys validate against the same device', () {
    test('lifetime round trip', () {
      final key = LicenseService.generateLifetimeKey(device);
      final result = LicenseService.validateKeyDetailed(key, device);
      expect(result.isValid, isTrue);
      expect(result.tier, LicenseTier.lifetime);
    });

    test('monthly round trip carries its day count', () {
      final key = LicenseService.generateMonthlyKey(device, days: 30);
      final result = LicenseService.validateKeyDetailed(key, device);
      expect(result.isValid, isTrue);
      expect(result.tier, LicenseTier.monthly);
      expect(result.parameter, 30);
    });

    test('a key is rejected on a different device', () {
      final key = LicenseService.generateLifetimeKey(device);
      final result = LicenseService.validateKeyDetailed(key, 'CS-9999-9999-9999');
      expect(result.isValid, isFalse);
    });

    test('device id is case and whitespace insensitive', () {
      final upper = LicenseService.generateLifetimeKey(device);
      final messy = LicenseService.generateLifetimeKey('  cs-a1b2-c3d4-e5f6  ');
      expect(messy, upper);
    });
  });
}
