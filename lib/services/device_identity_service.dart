import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Resolves the stable `CS-XXXX-XXXX-XXXX` identity for this installation.
///
/// The original scheme was a random UUID in SharedPreferences, which meant
/// clearing app data produced a brand new identity — resetting the free trial
/// and, once reward credits exist, allowing them to be farmed indefinitely.
///
/// New installations derive the ID from `Settings.Secure.ANDROID_ID`, which
/// survives clearing app data and uninstall/reinstall.
///
/// **Existing installations keep whatever ID they already have.** Licence keys
/// are HMACs over the device ID, so silently re-deriving it would invalidate
/// every key already sold.
class DeviceIdentityService {
  DeviceIdentityService._();
  static final DeviceIdentityService instance = DeviceIdentityService._();

  static const MethodChannel _channel = MethodChannel('com.clipshield/device');

  /// Same key the original implementation used, so a pre-existing value is
  /// found and preserved rather than regenerated.
  static const String _keyDeviceId = 'clipshield_device_id';

  /// Records how the stored ID was produced, for diagnostics only.
  static const String _keyDeviceIdSource = 'clipshield_device_id_source';

  /// Namespacing salt. Hashing means the raw hardware ID never leaves the
  /// device or lands in the backend database.
  static const String _idSalt = 'CS_DEVICE_ID_V2';

  String? _cached;

  /// 'android_id' | 'legacy_uuid' | 'random_fallback'
  String? _source;
  String? get source => _source;

  Future<String> getDeviceId() async {
    final cached = _cached;
    if (cached != null && cached.isNotEmpty) return cached;

    final prefs = await SharedPreferences.getInstance();

    // 1. An ID already exists: keep it. Any licence issued for this device is
    //    bound to this exact string.
    final stored = prefs.getString(_keyDeviceId);
    if (stored != null && stored.isNotEmpty) {
      _cached = stored;
      _source = prefs.getString(_keyDeviceIdSource) ?? 'legacy_uuid';
      return stored;
    }

    // 2. Fresh install: prefer the wipe-resistant hardware identifier.
    final androidId = await _readAndroidId();
    String id;
    if (androidId != null && androidId.isNotEmpty && androidId != '9774d56d682e549c') {
      // That literal is a well-known buggy ANDROID_ID shared by many older
      // devices; treating it as unique would merge unrelated installs.
      id = _formatFromSeed(androidId);
      _source = 'android_id';
    } else {
      id = _formatFromSeed(const Uuid().v4());
      _source = 'random_fallback';
    }

    await prefs.setString(_keyDeviceId, id);
    await prefs.setString(_keyDeviceIdSource, _source!);
    _cached = id;
    return id;
  }

  /// True when this device's ID cannot be reset by clearing app data.
  Future<bool> isWipeResistant() async {
    await getDeviceId();
    return _source == 'android_id';
  }

  Future<String?> _readAndroidId() async {
    try {
      return await _channel.invokeMethod<String>('getAndroidId');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      // Non-Android platform, or the channel is unavailable in tests.
      return null;
    }
  }

  Future<String?> deviceFingerprint() async {
    try {
      return await _channel.invokeMethod<String>('getDeviceFingerprint');
    } catch (_) {
      return null;
    }
  }

  /// Hashes a seed into the established `CS-XXXX-XXXX-XXXX` shape.
  ///
  /// Exposed for tests; the format must stay identical to the original
  /// generator or previously issued keys would no longer parse.
  static String formatFromSeed(String seed) => _formatFromSeed(seed);

  static String _formatFromSeed(String seed) {
    final digest = Hmac(sha256, utf8.encode(_idSalt)).convert(utf8.encode(seed));
    final hex = digest.toString().toUpperCase();
    return 'CS-${hex.substring(0, 4)}-${hex.substring(4, 8)}-${hex.substring(8, 12)}';
  }
}
