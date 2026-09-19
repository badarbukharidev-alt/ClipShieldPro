import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clipshield/models/app_update.dart';
import 'package:clipshield/services/update_service.dart';

/// The update prompt is the one dialog that can appear unprompted in front of
/// every user at once, and the button on it installs software. These pin the
/// cases where getting it wrong is expensive: prompting for a build that is not
/// newer, offering a link that could be tampered with, nagging someone who
/// already said "Later", or silently dropping a withdrawal.
Map<String, dynamic> announcement({
  String name = '1.2.11',
  int code = 14,
  String url = 'https://example.com/app-v1.2.11.apk',
  String notes = 'Faster renders.',
  bool mandatory = false,
}) {
  return {
    'ok': true,
    'update': {
      'version_name': name,
      'version_code': code,
      'apk_url': url,
      'notes': notes,
      'mandatory': mandatory,
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = UpdateService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await service.init();
    // PackageInfo is unavailable in tests, so state the running build directly.
    service.debugSetCurrent(13, '1.2.10');
  });

  group('deciding whether to offer an update', () {
    test('offers a higher version code', () async {
      await service.applyFromApi(announcement(code: 14));

      expect(service.isUpdateAvailable, isTrue);
      expect(service.shouldPrompt, isTrue);
      expect(service.latest.value!.versionName, '1.2.11');
    });

    test('does not offer the build already installed', () async {
      await service.applyFromApi(announcement(code: 13));

      expect(service.isUpdateAvailable, isFalse);
      expect(service.shouldPrompt, isFalse);
    });

    test('does not offer an older build', () async {
      await service.applyFromApi(announcement(code: 9));

      expect(service.isUpdateAvailable, isFalse);
    });

    test('an unknown current build never prompts', () async {
      // PackageInfo failing must not make every release look newer than zero.
      service.debugSetCurrent(0);
      await service.applyFromApi(announcement(code: 14));

      expect(service.isUpdateAvailable, isFalse);
    });

    test('does not offer an update if installed version name matches or is newer', () async {
      service.debugSetCurrent(13, '1.2.19');
      await service.applyFromApi(announcement(code: 25, name: '1.2.19'));

      expect(service.isUpdateAvailable, isFalse);
      expect(service.shouldPrompt, isFalse);
    });

    test('does not offer an update if installed version name is higher than announcement', () async {
      service.debugSetCurrent(13, '1.2.20');
      await service.applyFromApi(announcement(code: 25, name: '1.2.19'));

      expect(service.isUpdateAvailable, isFalse);
      expect(service.shouldPrompt, isFalse);
    });
  });

  group('rejecting announcements that should never reach a user', () {
    test('a non-https link is not offered', () async {
      await service.applyFromApi(
          announcement(url: 'http://example.com/app.apk'));

      expect(service.latest.value, isNull,
          reason: 'an APK over plain http can be swapped in transit');
    });

    test('a blank or malformed link is not offered', () async {
      for (final url in ['', '   ', 'example.com/app.apk', 'ftp://x/app.apk']) {
        await service.applyFromApi(announcement(url: url));
        expect(service.latest.value, isNull, reason: 'rejected "$url"');
      }
    });

    test('a missing version name or code is not offered', () async {
      await service.applyFromApi(announcement(name: ''));
      expect(service.latest.value, isNull);

      await service.applyFromApi(announcement(code: 0));
      expect(service.latest.value, isNull);
    });
  });

  group('dismissal', () {
    test('"Later" stops the prompt for that version only', () async {
      await service.applyFromApi(announcement(code: 14));
      await service.skipCurrent();

      expect(service.isUpdateAvailable, isTrue,
          reason: 'still available -- Settings must still be able to show it');
      expect(service.shouldPrompt, isFalse);

      await service.applyFromApi(announcement(code: 15, name: '1.2.12'));
      expect(service.shouldPrompt, isTrue, reason: 'a newer release asks again');
    });

    test('a skip survives a restart', () async {
      await service.applyFromApi(announcement(code: 14));
      await service.skipCurrent();

      await service.init();
      service.debugSetCurrent(13, '1.2.10');

      expect(service.shouldPrompt, isFalse);
    });

    test('a mandatory update ignores a previous skip', () async {
      await service.applyFromApi(announcement(code: 14));
      await service.skipCurrent();
      await service.applyFromApi(announcement(code: 14, mandatory: true));

      expect(service.shouldPrompt, isTrue);
    });
  });

  group('withdrawal and caching', () {
    test('an explicit null withdraws the announcement', () async {
      await service.applyFromApi(announcement());
      expect(service.latest.value, isNotNull);

      await service.applyFromApi({'ok': true, 'update': null});
      expect(service.latest.value, isNull);
    });

    test('a response without the key leaves the announcement alone', () async {
      await service.applyFromApi(announcement());
      await service.applyFromApi({'ok': true, 'credits_earned': 3});

      expect(service.latest.value, isNotNull,
          reason: 'an absent key is not a withdrawal');
    });

    test('the announcement survives a restart, for an offline launch', () async {
      await service.applyFromApi(announcement(code: 14));

      await service.init();
      service.debugSetCurrent(13, '1.2.10');

      expect(service.latest.value?.versionCode, 14);
      expect(service.shouldPrompt, isTrue);
    });

    test('a withdrawal clears the cache, not just the field', () async {
      await service.applyFromApi(announcement());
      await service.applyFromApi({'ok': true, 'update': null});

      await service.init();
      service.debugSetCurrent(13, '1.2.10');

      expect(service.latest.value, isNull);
    });
  });

  test('AppUpdate round-trips through the cache unchanged', () {
    const original = AppUpdate(
      versionName: '1.2.11',
      versionCode: 14,
      apkUrl: 'https://example.com/a.apk',
      notes: 'Notes here.',
      mandatory: true,
    );

    final restored = AppUpdate.fromMap(original.toMap())!;

    expect(restored.versionName, original.versionName);
    expect(restored.versionCode, original.versionCode);
    expect(restored.apkUrl, original.apkUrl);
    expect(restored.notes, original.notes);
    expect(restored.mandatory, original.mandatory);
  });
}
