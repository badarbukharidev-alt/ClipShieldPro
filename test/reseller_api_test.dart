import 'package:flutter_test/flutter_test.dart';

import 'package:clipshield/services/reseller_api_service.dart';
import 'package:clipshield/services/task_api_service.dart';

/// The reseller key desk talks to the panel over the same signed channel as the
/// task API. If the tier strings or the canonical signing string drift from what
/// inc/reseller.php and inc/sign.php expect, every request fails with a bad
/// signature or an unknown tier — so those are pinned here.
void main() {
  group('tier wire values match the panel CS_TIERS', () {
    test('exactly these three, spelled this way', () {
      expect(ResellerTier.values.map((t) => t.wire).toList(),
          ['lifetime', 'monthly', 'videopack']);
    });

    test('labels are human, wire values are not', () {
      expect(ResellerTier.lifetime.label, 'Lifetime');
      expect(ResellerTier.videopack.wire, 'videopack');
      expect(ResellerTier.videopack.label, 'Video pack');
    });
  });

  group('quota parsing', () {
    test('reads each tier, defaulting a missing one to zero', () {
      final q = ResellerQuotas.fromMap({'lifetime': 5, 'monthly': 2});

      expect(q.of(ResellerTier.lifetime), 5);
      expect(q.of(ResellerTier.monthly), 2);
      expect(q.of(ResellerTier.videopack), 0);
      expect(q.total, 7);
    });

    test('a non-map is treated as all zero rather than throwing', () {
      final q = ResellerQuotas.fromMap(null);
      expect(q.total, 0);
    });
  });

  group('signing matches the panel canonical form', () {
    test('device id is empty and the code goes in extra', () {
      // The panel calls api_verify(action, '', ts, nonce, code), so the app must
      // sign with an empty device id and the reseller code as the extra field.
      final canonical =
          TaskApiService.canonicalString('reseller.login', '', 1700000000, 'abc', 'shopcode');

      expect(canonical, 'reseller.login||1700000000|abc|shopcode');
    });

    test('the same secret and inputs produce a stable signature', () {
      final a = TaskApiService.signWith(
          'x' * 64, 'reseller.generate', '', 1700000000, 'n1', 'shopcode');
      final b = TaskApiService.signWith(
          'x' * 64, 'reseller.generate', '', 1700000000, 'n1', 'shopcode');

      expect(a, b);
      expect(a, hasLength(64)); // hex sha256
    });
  });

  group('quotas survive the app being closed', () {
    // The bug this covers: quotas arrived only as a side effect of login or
    // generate. A token outlives the app, so on reopen the reseller was signed
    // in with no numbers -- every tier read "0 left" and Generate was disabled.
    test('there is a way to ask for quotas on their own', () {
      expect(ResellerApiService.instance.fetchQuotas, isA<Function>(),
          reason: 'without a standalone fetch, a restored session has no '
              'allowance to show');
    });

    test('fetching with no session asks for re-auth rather than hanging',
        () async {
      final result = await ResellerApiService.instance.fetchQuotas();

      expect(result.ok, isFalse);
      expect(result.error, 'reauth_required');
    });
  });

  group('availability', () {
    test('the desk is unavailable without a reseller build and a secret', () {
      // In a plain test run there is no reseller code and no API secret, so the
      // service must report itself unavailable rather than trying to call out.
      expect(ResellerApiService.instance.isAvailable, isFalse);
    });

    test('a generate call with no session asks for re-auth, not a crash', () async {
      final result = await ResellerApiService.instance.generateKey(
        deviceId: 'CS-AAAA-BBBB-CCCC',
        tier: ResellerTier.lifetime,
        param: 0,
      );

      expect(result.ok, isFalse);
      expect(result.error, 'reauth_required');
    });
  });
}
