import 'package:flutter_test/flutter_test.dart';
import 'package:clipshield/services/task_api_service.dart';
import 'package:clipshield/services/device_identity_service.dart';

/// Pins the request-signing scheme against the PHP implementation in
/// ClipShield-Admin/inc/sign.php. If either side changes its canonical string,
/// every API call starts failing with bad_signature — so these vectors are the
/// contract between the app and the panel.
void main() {
  const secret = 'test_secret_0123456789abcdef0123456789abcdef0123456789abcdef01';
  const device = 'CS-A1B2-C3D4-E5F6';
  const ts = 1760000000;
  const nonce = 'abc123nonce';

  group('canonical string', () {
    test('is pipe-joined in a fixed order', () {
      expect(
        TaskApiService.canonicalString('tasks.claim', device, ts, nonce, '7'),
        'tasks.claim|CS-A1B2-C3D4-E5F6|1760000000|abc123nonce|7',
      );
    });

    test('uppercases and trims the device id', () {
      expect(
        TaskApiService.canonicalString('tasks.list', '  cs-a1b2-c3d4-e5f6 ', ts, nonce, ''),
        'tasks.list|CS-A1B2-C3D4-E5F6|1760000000|abc123nonce|',
      );
    });
  });

  group('signature vectors match PHP hash_hmac', () {
    test('claim binds to the task id', () {
      expect(
        TaskApiService.signWith(secret, 'tasks.claim', device, ts, nonce, '7'),
        '0eb80edcc2dddc2c01fafdc212479a8c5058a9c87ffa27c5fabb3908cee7c9ce',
      );
    });

    test('list has an empty extra', () {
      expect(
        TaskApiService.signWith(secret, 'tasks.list', device, ts, nonce, ''),
        '231a70b01daa1eb0d0edffc763c0f59344ad1b3c6731dd3c8f19b0c1efbe147c',
      );
    });

    test('a signature for one task does not verify for another', () {
      final forTask7 = TaskApiService.signWith(secret, 'tasks.claim', device, ts, nonce, '7');
      final forTask8 = TaskApiService.signWith(secret, 'tasks.claim', device, ts, nonce, '8');
      expect(forTask7, isNot(forTask8));
    });

    test('a signature does not carry across devices', () {
      final a = TaskApiService.signWith(secret, 'tasks.list', device, ts, nonce, '');
      final b = TaskApiService.signWith(secret, 'tasks.list', 'CS-9999-9999-9999', ts, nonce, '');
      expect(a, isNot(b));
    });
  });

  group('configuration guard', () {
    test('the placeholder secret counts as unconfigured', () {
      // Ships disabled so a misconfigured build cannot spam the API.
      expect(TaskApiService.isConfigured, isFalse,
          reason: 'set a real API_SECRET before shipping the task system');
    });
  });

  group('device id format', () {
    test('derived ids keep the established CS-XXXX-XXXX-XXXX shape', () {
      final id = DeviceIdentityService.formatFromSeed('some-android-id');
      expect(RegExp(r'^CS-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}$').hasMatch(id), isTrue);
    });

    test('the same seed always yields the same id', () {
      expect(
        DeviceIdentityService.formatFromSeed('abc'),
        DeviceIdentityService.formatFromSeed('abc'),
      );
    });

    test('different seeds yield different ids', () {
      expect(
        DeviceIdentityService.formatFromSeed('abc'),
        isNot(DeviceIdentityService.formatFromSeed('abd')),
      );
    });
  });
}
