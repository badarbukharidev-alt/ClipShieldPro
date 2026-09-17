import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app died the instant Render was tapped, on every Android 14 phone.
///
/// `mediaProcessing` was the only foreground service type declared, and that
/// type **only exists from API 35 (Android 15)** — verified against the SDK's
/// own attrs_manifest.xml:
///
///   API 34: camera, connectedDevice, dataSync, fileManagement, health,
///           location, mediaPlayback, mediaProjection, microphone, phoneCall,
///           remoteMessaging, shortService, specialUse, systemExempted
///   API 35: ...the same, plus mediaProcessing
///
/// On Android 14 the system therefore resolved the service to *no type*, and an
/// app targeting API 34+ that calls `startForeground()` without a valid type is
/// killed immediately with MissingForegroundServiceTypeException. The plugin
/// uses the two-argument `startForeground(id, notification)`, so the type comes
/// entirely from the manifest.
///
/// A unit test cannot catch a native crash, but it can catch the declaration
/// that causes it — which is the part that was actually wrong.

/// Foreground service types and the API level each was introduced in.
const Map<String, int> _typeSinceApi = {
  'camera': 29,
  'connectedDevice': 29,
  'dataSync': 29,
  'location': 29,
  'mediaPlayback': 29,
  'mediaProjection': 29,
  'microphone': 29,
  'phoneCall': 29,
  'health': 34,
  'remoteMessaging': 34,
  'shortService': 34,
  'specialUse': 34,
  'systemExempted': 34,
  'fileManagement': 34,
  'mediaProcessing': 35,
};

String _readFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail('$path not found. Run this from the project root.');
  }

  return file.readAsStringSync();
}

void main() {
  const manifestPath = 'android/app/src/main/AndroidManifest.xml';
  const gradlePath = 'android/app/build.gradle';

  late String manifest;
  late int minSdk;

  setUpAll(() {
    manifest = _readFile(manifestPath);

    final gradle = _readFile(gradlePath);
    final match = RegExp(r'minSdk\s*=?\s*(\d+)').firstMatch(gradle);
    minSdk = match == null ? 24 : int.parse(match.group(1)!);
  });

  List<String> declaredTypes() {
    final match =
        RegExp(r'android:foregroundServiceType="([^"]+)"').firstMatch(manifest);
    if (match == null) return const [];

    return match.group(1)!.split('|').map((t) => t.trim()).toList();
  }

  test('a foreground service type is declared at all', () {
    // Without one, an app targeting API 34+ cannot start a foreground service.
    expect(declaredTypes(), isNotEmpty);
  });

  test('every declared type is a real Android type', () {
    for (final type in declaredTypes()) {
      expect(_typeSinceApi.containsKey(type), isTrue,
          reason: '"$type" is not a foreground service type Android knows');
    }
  });

  test('at least one type works on every Android version that needs one', () {
    final types = declaredTypes();

    // Foreground service types did not exist before API 29, and a service on
    // those versions needs none -- so that, not minSdk, is the floor a type has
    // to reach. minSdk is $minSdk here.
    const typesIntroducedAt = 29;
    final floor = minSdk > typesIntroducedAt ? minSdk : typesIntroducedAt;

    // This is the assertion that would have caught the crash. Declaring only
    // mediaProcessing leaves every device below API 35 with no usable type.
    final usableAtFloor =
        types.where((t) => (_typeSinceApi[t] ?? 999) <= floor).toList();

    expect(usableAtFloor, isNotEmpty,
        reason: 'every declared type (${types.join(", ")}) needs an Android '
            'newer than API $floor. A device below the lowest declared type '
            'resolves the service to no type at all and is killed on '
            'startForeground().');
  });

  test('a type usable on Android 14 is declared', () {
    // Called out on its own because Android 14 is where this actually bit: it
    // is the first version that *enforces* the type, and the last before
    // mediaProcessing exists.
    final types = declaredTypes();
    final usableOn34 =
        types.where((t) => (_typeSinceApi[t] ?? 999) <= 34).toList();

    expect(usableOn34, isNotEmpty,
        reason: 'nothing here works on Android 14, which enforces the type but '
            'does not know mediaProcessing');
  });

  test('every declared type has its matching permission', () {
    // Android 14+ requires the permission that goes with each type; without it
    // startForeground throws SecurityException instead.
    const permissionForType = {
      'dataSync': 'FOREGROUND_SERVICE_DATA_SYNC',
      'mediaProcessing': 'FOREGROUND_SERVICE_MEDIA_PROCESSING',
      'mediaPlayback': 'FOREGROUND_SERVICE_MEDIA_PLAYBACK',
      'specialUse': 'FOREGROUND_SERVICE_SPECIAL_USE',
      'shortService': null, // needs no permission
    };

    for (final type in declaredTypes()) {
      if (!permissionForType.containsKey(type)) continue;
      final permission = permissionForType[type];
      if (permission == null) continue;

      expect(manifest, contains('android.permission.$permission'),
          reason: 'type "$type" is declared without its $permission permission');
    }
  });

  test('the base FOREGROUND_SERVICE permission is present', () {
    expect(manifest, contains('android.permission.FOREGROUND_SERVICE'));
  });

  test('no XML comment contains a double hyphen', () {
    // XML forbids "--" inside a comment, and aapt2 rejects the whole file with
    // "Error parsing AndroidManifest.xml" rather than pointing at the line.
    // Writing "--" as an em dash in a comment has broken this build three
    // separate times, so it is checked rather than remembered.
    final dir = Directory('android');
    if (!dir.existsSync()) return;

    final offenders = <String>[];
    final comment = RegExp(r'<!--(.*?)-->', dotAll: true);

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.xml')) continue;
      // Generated output is not ours to police.
      if (entity.path.contains('build')) continue;

      final body = entity.readAsStringSync();
      for (final match in comment.allMatches(body)) {
        if (match.group(1)!.contains('--')) {
          offenders.add(entity.path);
          break;
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'these files have "--" inside an XML comment, which makes the '
            'Android build fail to parse them');
  });
}
