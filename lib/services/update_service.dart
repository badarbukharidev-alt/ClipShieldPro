import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_update.dart';

/// Tracks the release the admin panel is advertising.
///
/// The panel attaches the current release to every API response, so an update
/// is noticed during ordinary traffic rather than needing a call of its own.
/// The last one seen is cached, which means a phone that is offline at launch
/// still knows an update exists — it simply cannot fetch it yet.
///
/// Deliberately *not* a downloader. Tapping through opens the APK link in the
/// browser and Android's own installer takes over. Silently downloading and
/// installing would need REQUEST_INSTALL_PACKAGES, and an app that can install
/// packages on its own is one panel compromise away from being a delivery
/// mechanism. The extra tap is the point.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const String _keyCached = 'clipshield_update_cached';
  static const String _keySkipped = 'clipshield_update_skipped_code';

  SharedPreferences? _prefs;

  /// The running build's `versionCode`, read from the APK itself rather than a
  /// constant, so it cannot drift from what was actually shipped.
  int _currentCode = 0;
  int get currentBuildNumber => _currentCode;

  String _currentName = '';
  String get currentVersionName => _currentName;

  /// Highest version the user has chosen to skip. A mandatory update ignores it.
  int _skippedCode = 0;

  /// The advertised release, or null if none is cached. Listenable so the
  /// prompt can appear when a sync lands rather than only at launch.
  final ValueNotifier<AppUpdate?> latest = ValueNotifier<AppUpdate?>(null);

  Future<void> init() async {
    // Assigned, not `??=`: init is the lifecycle entry point and should re-read
    // the store rather than trust an instance captured earlier.
    _prefs = await SharedPreferences.getInstance();

    try {
      final info = await PackageInfo.fromPlatform();
      _currentCode = int.tryParse(info.buildNumber) ?? 0;
      _currentName = info.version;
    } catch (_) {
      // Tests and any platform without the plugin: a zero current code would
      // make every advertised release look newer, so treat it as unknown and
      // let isUpdateAvailable stay false.
      _currentCode = 0;
      _currentName = '';
    }

    _skippedCode = _prefs!.getInt(_keySkipped) ?? 0;

    final cached = _prefs!.getString(_keyCached);
    if (cached != null && cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is Map) {
          latest.value = AppUpdate.fromMap(decoded.cast<String, dynamic>());
        }
      } catch (_) {
        await _prefs!.remove(_keyCached);
      }
    }
  }

  /// Picks the `update` block out of any API response.
  ///
  /// An absent block leaves the cache alone — a response that simply does not
  /// carry the field must not be read as "the update was withdrawn". The panel
  /// withdraws one explicitly by sending `update: null`, which is what
  /// unticking "enabled" produces.
  Future<void> applyFromApi(Map<String, dynamic> response) async {
    if (!response.containsKey('update')) return;

    _prefs ??= await SharedPreferences.getInstance();
    final raw = response['update'];

    if (raw is! Map) {
      latest.value = null;
      await _prefs!.remove(_keyCached);
      return;
    }

    final update = AppUpdate.fromMap(raw.cast<String, dynamic>());
    latest.value = update;

    if (update == null) {
      await _prefs!.remove(_keyCached);
    } else {
      await _prefs!.setString(_keyCached, jsonEncode(update.toMap()));
    }
  }

  /// True when there is a genuinely newer build to offer.
  bool get isUpdateAvailable {
    final update = latest.value;
    if (update == null || _currentCode <= 0) return false;

    return update.versionCode > _currentCode;
  }

  /// Whether to put the dialog in front of the user right now. A skipped
  /// version stays skipped until a newer one appears; a mandatory one is shown
  /// regardless, which is the only thing that flag buys.
  bool get shouldPrompt {
    final update = latest.value;
    if (!isUpdateAvailable || update == null) return false;
    if (update.mandatory) return true;

    return update.versionCode > _skippedCode;
  }

  /// Records "Later". Stored per version, so the next release asks again.
  Future<void> skipCurrent() async {
    final update = latest.value;
    if (update == null) return;

    _prefs ??= await SharedPreferences.getInstance();
    _skippedCode = update.versionCode;
    await _prefs!.setInt(_keySkipped, _skippedCode);
  }

  @visibleForTesting
  void debugSetCurrent(int code, [String name = '']) {
    _currentCode = code;
    _currentName = name;
  }
}
