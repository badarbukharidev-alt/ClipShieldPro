import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service responsible for ClipShield Pro licensing, trial enforcement,
/// persistent device identification, and offline cryptographic activation.
class LicenseService {
  LicenseService._internal();
  static final LicenseService instance = LicenseService._internal();
  factory LicenseService() => instance;

  // Private cryptographic salt for offline HMAC-SHA256 signature verification
  static const String salt = 'CS_PRO_2026_SECURE_SALT_KEY';

  // Support & Ordering Contact
  static const String supportPhone = '03079031153';
  static const String supportWhatsAppInternational = '923079031153';

  // Preference Keys
  static const String _keyDeviceId = 'clipshield_device_id';
  static const String _keyTrialCount = 'clipshield_trial_renders_count';
  static const String _keyActivationKey = 'clipshield_activation_key';
  static const String _keyIsActivated = 'clipshield_is_activated';

  // Maximum allowed free trial renders before requiring Pro activation
  static const int maxTrialRenders = 1;

  SharedPreferences? _prefs;
  String? _deviceId;
  int _trialCount = 0;
  bool _isActivated = false;
  bool _isInitialized = false;

  /// Cached device ID getter. Defaults to empty string until initialized.
  String get deviceId => _deviceId ?? '';

  /// Current number of completed trial renders.
  int get trialCount => _trialCount;

  /// Remaining trial renders before lock out.
  int get remainingTrials => isActivated() ? 999 : (maxTrialRenders - _trialCount).clamp(0, maxTrialRenders);

  /// Initializes the licensing engine, loads SharedPreferences,
  /// retrieves or generates the persistent Device ID, and checks activation status.
  Future<void> init() async {
    if (_isInitialized && _prefs != null) return;

    _prefs = await SharedPreferences.getInstance();
    _deviceId = await getDeviceId();
    _trialCount = _prefs?.getInt(_keyTrialCount) ?? 0;

    // Verify stored activation key cryptographically
    final storedKey = _prefs?.getString(_keyActivationKey);
    final storedActivatedFlag = _prefs?.getBool(_keyIsActivated) ?? false;

    if (storedKey != null && storedKey.isNotEmpty && _deviceId != null) {
      if (verifyKey(storedKey, _deviceId!)) {
        _isActivated = true;
      } else {
        // Tampered or invalid key
        _isActivated = false;
        await _prefs?.setBool(_keyIsActivated, false);
      }
    } else if (storedActivatedFlag && storedKey != null) {
      _isActivated = verifyKey(storedKey, _deviceId ?? '');
    } else {
      _isActivated = false;
    }

    _isInitialized = true;
  }

  /// Returns true if ClipShield Pro has been activated with a valid key.
  bool isActivated() {
    return _isActivated;
  }

  /// Returns true if the user can perform a render:
  /// either the app is activated OR trial render count is less than 1.
  bool canRender() {
    return isActivated() || _trialCount < maxTrialRenders;
  }

  /// Generates a unique, persistent hardware/installation Device ID (e.g. `CS-XXXX-XXXX-XXXX`).
  /// Stored permanently in SharedPreferences.
  Future<String> getDeviceId() async {
    if (_deviceId != null && _deviceId!.isNotEmpty) {
      return _deviceId!;
    }

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    String? storedId = prefs.getString(_keyDeviceId);

    if (storedId == null || storedId.isEmpty) {
      storedId = _generateUniqueDeviceId();
      await prefs.setString(_keyDeviceId, storedId);
    }

    _deviceId = storedId;
    return storedId;
  }

  /// Internal generator for Device ID formatted as `CS-XXXX-XXXX-XXXX`.
  static String _generateUniqueDeviceId() {
    final raw = const Uuid().v4().replaceAll('-', '').toUpperCase();
    final p1 = raw.substring(0, 4);
    final p2 = raw.substring(4, 8);
    final p3 = raw.substring(8, 12);
    return 'CS-$p1-$p2-$p3';
  }

  /// Offline cryptographic activation key formula:
  /// Key = HMAC_SHA256(deviceId, salt).substring(0, 16).toUpperCase()
  /// Formatted as `XXXX-XXXX-XXXX-XXXX`.
  static String computeExpectedKey(String deviceId) {
    final cleanDevice = deviceId.trim();
    final keyBytes = utf8.encode(salt);
    final messageBytes = utf8.encode(cleanDevice);

    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(messageBytes);
    final hex = digest.toString().toUpperCase();

    final raw16 = hex.substring(0, 16);
    return '${raw16.substring(0, 4)}-${raw16.substring(4, 8)}-${raw16.substring(8, 12)}-${raw16.substring(12, 16)}';
  }

  /// Cryptographically verifies the entered activation key against the device ID.
  /// Tolerates case insensitivity and optional hyphens or whitespace.
  static bool verifyKey(String enteredKey, String deviceId) {
    final cleanEntered = enteredKey.replaceAll('-', '').replaceAll(' ', '').trim().toUpperCase();
    if (cleanEntered.length != 16) {
      return false;
    }

    final expectedKey = computeExpectedKey(deviceId).replaceAll('-', '');
    return cleanEntered == expectedKey;
  }

  /// Formats a raw 16-character key into `XXXX-XXXX-XXXX-XXXX`
  static String formatKey(String key) {
    final clean = key.replaceAll('-', '').replaceAll(' ', '').trim().toUpperCase();
    if (clean.length != 16) return key;
    return '${clean.substring(0, 4)}-${clean.substring(4, 8)}-${clean.substring(8, 12)}-${clean.substring(12, 16)}';
  }

  /// Validates the entered key and activates ClipShield Pro if valid.
  /// Returns true on success, false if key is invalid.
  Future<bool> activate(String enteredKey) async {
    final currentDevice = await getDeviceId();

    if (verifyKey(enteredKey, currentDevice)) {
      _isActivated = true;
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final formatted = formatKey(enteredKey);
      await prefs.setString(_keyActivationKey, formatted);
      await prefs.setBool(_keyIsActivated, true);
      return true;
    }

    return false;
  }

  /// Consumes one trial render. Does nothing if already activated.
  Future<void> consumeTrial() async {
    if (isActivated()) return;

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _trialCount += 1;
    await prefs.setInt(_keyTrialCount, _trialCount);
  }

  /// Returns the pre-composed WhatsApp order URL targeting 03079031153.
  /// Format: https://wa.me/923079031153?text=Hello%20ClipShield%20Team,%20I%20want%20to%20activate%20ClipShield%20Pro.%20My%20Device%20ID%20is:%20$deviceId
  String getWhatsAppUrl(String deviceId) {
    return 'https://wa.me/923079031153?text=Hello%20ClipShield%20Team,%20I%20want%20to%20activate%20ClipShield%20Pro.%20My%20Device%20ID%20is:%20$deviceId';
  }

  /// Debug / testing helper to reset trial count or de-activate.
  Future<void> resetForTesting({bool activate = false}) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _trialCount = 0;
    _isActivated = activate;
    await prefs.setInt(_keyTrialCount, 0);
    await prefs.setBool(_keyIsActivated, activate);
    if (!activate) {
      await prefs.remove(_keyActivationKey);
    }
  }
}
