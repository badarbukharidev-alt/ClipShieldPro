import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_identity_service.dart';
import 'remote_config_service.dart';
import 'task_api_service.dart';

enum LicenseTier {
  trial,
  monthly,
  lifetime,
  videoPack,
}

class LicenseValidationResult {
  final bool isValid;
  final LicenseTier tier;
  final int parameter; // e.g. 30 (days) or 5 (videos)
  final String formattedKey;

  const LicenseValidationResult({
    required this.isValid,
    this.tier = LicenseTier.trial,
    this.parameter = 0,
    this.formattedKey = '',
  });
}

/// Service responsible for ClipShield Pro licensing, trial enforcement,
/// persistent device identification, and offline cryptographic activation.
class LicenseService {
  LicenseService._internal();
  static final LicenseService instance = LicenseService._internal();
  factory LicenseService() => instance;

  // Private cryptographic salt for offline HMAC-SHA256 signature verification
  static const String salt = 'CS_PRO_2026_SECURE_SALT_KEY';

  // Support & ordering contact. These are the shipped defaults; the live
  // values come from the admin panel via RemoteConfigService, so the number can
  // be changed without a new build.
  static String get supportPhone => RemoteConfigService.instance.supportPhoneDisplay;
  static String get supportWhatsAppInternational =>
      RemoteConfigService.instance.supportWhatsApp;

  // Preference Keys
  static const String _keyTrialCount = 'clipshield_trial_renders_count';
  static const String _keyActivationKey = 'clipshield_activation_key';
  static const String _keyIsActivated = 'clipshield_is_activated';
  static const String _keyLicenseTier = 'clipshield_license_tier';
  static const String _keyExpiresAt = 'clipshield_license_expires_at';
  static const String _keyRemainingVideos = 'clipshield_license_remaining_videos';

  // Task reward credits. Cached locally so already-earned credits still work
  // offline, but the server is the authority and reconciles on every sync.
  static const String _keyBonusEarned = 'clipshield_bonus_credits_earned';
  static const String _keyBonusUsed = 'clipshield_bonus_credits_used';

  // Maximum allowed free trial renders before requiring Pro activation
  static const int maxTrialRenders = 1;

  SharedPreferences? _prefs;
  String? _deviceId;
  int _trialCount = 0;
  bool _isActivated = false;
  bool _isInitialized = false;

  int _bonusEarned = 0;
  int _bonusUsed = 0;

  LicenseTier _currentTier = LicenseTier.trial;
  DateTime? _expiresAt;
  int _remainingVideos = 0;

  /// Cached device ID getter. Defaults to empty string until initialized.
  String get deviceId => _deviceId ?? '';

  /// Current number of completed trial renders.
  int get trialCount => _trialCount;

  /// Current active license tier.
  LicenseTier get currentTier => _currentTier;

  /// Expiry date for time-limited licenses.
  DateTime? get expiresAt => _expiresAt;

  /// Remaining videos for video pack licenses.
  int get remainingVideos => _remainingVideos;

  /// Task credits earned in total, and how many have been spent.
  int get bonusEarned => _bonusEarned;
  int get bonusUsed => _bonusUsed;

  /// Task credits still available to spend on a render.
  int get bonusAvailable => (_bonusEarned - _bonusUsed).clamp(0, 1 << 30);

  /// Remaining trial renders before lock out.
  int get remainingTrials => isActivated() ? 999 : (maxTrialRenders - _trialCount).clamp(0, maxTrialRenders);

  /// Human-readable status badge.
  String get statusBadge {
    if (_currentTier == LicenseTier.lifetime) return 'LIFETIME PRO';
    if (_currentTier == LicenseTier.monthly) {
      if (_expiresAt == null) return 'PRO MONTHLY';
      final diff = _expiresAt!.difference(DateTime.now()).inDays;
      return diff > 0 ? 'PRO ($diff DAYS LEFT)' : 'EXPIRED';
    }
    if (_currentTier == LicenseTier.videoPack) {
      return _remainingVideos > 0 ? 'PRO ($_remainingVideos VIDEOS LEFT)' : 'EXPIRED';
    }
    return _trialCount < maxTrialRenders ? 'FREE TRIAL' : 'TRIAL EXPIRED';
  }

  /// Detailed human-readable license status text.
  String get statusDescription {
    if (_currentTier == LicenseTier.lifetime) {
      return 'Lifetime License · Unlimited On-Device Renders';
    }
    if (_currentTier == LicenseTier.monthly) {
      if (_expiresAt == null) return 'Monthly License Active';
      final days = _expiresAt!.difference(DateTime.now()).inDays;
      if (days <= 0) return 'Monthly License Expired · Please renew key';
      return 'Monthly License · $days days remaining until renewal';
    }
    if (_currentTier == LicenseTier.videoPack) {
      if (_remainingVideos <= 0) return 'Video Pack Exhausted · Please renew key';
      return 'Video Pack · $_remainingVideos video renders remaining';
    }
    final left = max(0, maxTrialRenders - _trialCount);
    return left > 0 ? 'Free Trial · $left render remaining' : 'Trial Ended · Please activate to render';
  }

  /// Initializes the licensing engine, loads SharedPreferences,
  /// retrieves or generates the persistent Device ID, and checks activation status.
  Future<void> init() async {
    if (_isInitialized && _prefs != null) return;

    _prefs = await SharedPreferences.getInstance();
    _deviceId = await getDeviceId();
    _trialCount = _prefs?.getInt(_keyTrialCount) ?? 0;
    _bonusEarned = _prefs?.getInt(_keyBonusEarned) ?? 0;
    _bonusUsed = _prefs?.getInt(_keyBonusUsed) ?? 0;

    final storedKey = _prefs?.getString(_keyActivationKey);
    final storedExpiresStr = _prefs?.getString(_keyExpiresAt);
    _remainingVideos = _prefs?.getInt(_keyRemainingVideos) ?? 0;

    if (storedExpiresStr != null && storedExpiresStr.isNotEmpty) {
      _expiresAt = DateTime.tryParse(storedExpiresStr);
    }

    if (storedKey != null && storedKey.isNotEmpty && _deviceId != null) {
      final validation = validateKeyDetailed(storedKey, _deviceId!);
      if (validation.isValid) {
        _currentTier = validation.tier;

        if (_currentTier == LicenseTier.lifetime) {
          _isActivated = true;
        } else if (_currentTier == LicenseTier.monthly) {
          if (_expiresAt != null && DateTime.now().isBefore(_expiresAt!)) {
            _isActivated = true;
          } else {
            _isActivated = false;
          }
        } else if (_currentTier == LicenseTier.videoPack) {
          _isActivated = _remainingVideos > 0;
        }
      } else {
        _isActivated = false;
        _currentTier = LicenseTier.trial;
        await _prefs?.setBool(_keyIsActivated, false);
      }
    } else {
      _isActivated = false;
      _currentTier = LicenseTier.trial;
    }

    _isInitialized = true;
  }

  /// Returns true if ClipShield Pro has an active, non-expired license.
  bool isActivated() {
    if (!_isActivated) return false;
    if (_currentTier == LicenseTier.lifetime) return true;
    if (_currentTier == LicenseTier.monthly) {
      return _expiresAt != null && DateTime.now().isBefore(_expiresAt!);
    }
    if (_currentTier == LicenseTier.videoPack) {
      return _remainingVideos > 0;
    }
    return false;
  }

  /// Returns true if the user can perform a render:
  /// lifetime: always true; monthly: unexpired; videoPack: credits > 0; trial: trialCount < max.
  bool canRender() {
    if (_currentTier == LicenseTier.lifetime) return true;
    if (_currentTier == LicenseTier.monthly) {
      return _expiresAt != null && DateTime.now().isBefore(_expiresAt!);
    }
    if (_currentTier == LicenseTier.videoPack) {
      return _remainingVideos > 0;
    }
    // A trial render is allowed either from the free allowance or from credits
    // the user earned by completing tasks.
    return _trialCount < maxTrialRenders || bonusAvailable > 0;
  }

  /// Persistent Device ID (`CS-XXXX-XXXX-XXXX`).
  ///
  /// Delegates to [DeviceIdentityService], which keeps any pre-existing ID
  /// intact — licence keys are HMACs over this string, so changing it would
  /// invalidate every key already sold — and derives new ones from ANDROID_ID
  /// so they survive clearing app data.
  Future<String> getDeviceId() async {
    if (_deviceId != null && _deviceId!.isNotEmpty) {
      return _deviceId!;
    }

    _deviceId = await DeviceIdentityService.instance.getDeviceId();
    return _deviceId!;
  }

  // =========================================================================
  // ADMIN KEY GENERATORS (Offline Cryptographic HMAC-SHA256)
  // =========================================================================

  /// Computes a raw 16-hex HMAC signature for any payload string with deviceId and salt.
  static String _computeHmac16(String deviceId, String payload) {
    final cleanDevice = deviceId.trim().toUpperCase();
    final keyBytes = utf8.encode(salt);
    final messageBytes = utf8.encode('$cleanDevice:$payload');
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(messageBytes);
    return digest.toString().toUpperCase().substring(0, 16);
  }

  /// Legacy 16-character format for backwards compatibility with tests & older installs.
  /// Generates: `XXXX-XXXX-XXXX-XXXX`
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

  /// Generates a Lifetime License key: `CSL-XXXX-XXXX-XXXX-XXXX`
  static String generateLifetimeKey(String deviceId) {
    final sig = _computeHmac16(deviceId, 'LIFETIME');
    return 'CSL-${sig.substring(0, 4)}-${sig.substring(4, 8)}-${sig.substring(8, 12)}-${sig.substring(12, 16)}';
  }

  /// Generates a Monthly License key: `CSM30-XXXX-XXXX-XXXX-XXXX`
  static String generateMonthlyKey(String deviceId, {int days = 30}) {
    final sig = _computeHmac16(deviceId, 'MONTH:$days');
    final p = days.toString().padLeft(2, '0');
    return 'CSM$p-${sig.substring(0, 4)}-${sig.substring(4, 8)}-${sig.substring(8, 12)}-${sig.substring(12, 16)}';
  }

  /// Generates a Video Pack License key: `CSV05-XXXX-XXXX-XXXX-XXXX`
  static String generateVideoPackKey(String deviceId, {int videoCount = 5}) {
    final sig = _computeHmac16(deviceId, 'VPACK:$videoCount');
    final p = videoCount.toString().padLeft(2, '0');
    return 'CSV$p-${sig.substring(0, 4)}-${sig.substring(4, 8)}-${sig.substring(8, 12)}-${sig.substring(12, 16)}';
  }

  // =========================================================================
  // KEY VALIDATION & ACTIVATION LOGIC
  // =========================================================================

  /// Detailed cryptographic verification returning tier and parameters.
  static LicenseValidationResult validateKeyDetailed(String enteredKey, String deviceId) {
    final raw = enteredKey.replaceAll(' ', '').trim().toUpperCase();
    if (raw.isEmpty) return const LicenseValidationResult(isValid: false);

    // 1. Check Lifetime Prefix: CSL-XXXX-XXXX-XXXX-XXXX
    if (raw.startsWith('CSL-')) {
      final clean = raw.replaceAll('-', '').replaceFirst('CSL', '');
      if (clean.length == 16) {
        final expected = _computeHmac16(deviceId, 'LIFETIME');
        if (clean == expected) {
          return LicenseValidationResult(
            isValid: true,
            tier: LicenseTier.lifetime,
            formattedKey: 'CSL-${clean.substring(0, 4)}-${clean.substring(4, 8)}-${clean.substring(8, 12)}-${clean.substring(12, 16)}',
          );
        }
      }
    }

    // 2. Check Monthly Prefix: CSM<DAYS>-XXXX-XXXX-XXXX-XXXX (e.g. CSM30-...)
    if (raw.startsWith('CSM')) {
      final parts = raw.split('-');
      if (parts.length >= 2) {
        final header = parts[0];
        final daysStr = header.replaceFirst('CSM', '');
        final days = int.tryParse(daysStr) ?? 30;
        final clean = parts.sublist(1).join('');
        if (clean.length == 16) {
          final expected = _computeHmac16(deviceId, 'MONTH:$days');
          if (clean == expected) {
            return LicenseValidationResult(
              isValid: true,
              tier: LicenseTier.monthly,
              parameter: days,
              formattedKey: '$header-${clean.substring(0, 4)}-${clean.substring(4, 8)}-${clean.substring(8, 12)}-${clean.substring(12, 16)}',
            );
          }
        }
      }
    }

    // 3. Check Video Pack Prefix: CSV<COUNT>-XXXX-XXXX-XXXX-XXXX (e.g. CSV05-...)
    if (raw.startsWith('CSV')) {
      final parts = raw.split('-');
      if (parts.length >= 2) {
        final header = parts[0];
        final countStr = header.replaceFirst('CSV', '');
        final count = int.tryParse(countStr) ?? 5;
        final clean = parts.sublist(1).join('');
        if (clean.length == 16) {
          final expected = _computeHmac16(deviceId, 'VPACK:$count');
          if (clean == expected) {
            return LicenseValidationResult(
              isValid: true,
              tier: LicenseTier.videoPack,
              parameter: count,
              formattedKey: '$header-${clean.substring(0, 4)}-${clean.substring(4, 8)}-${clean.substring(8, 12)}-${clean.substring(12, 16)}',
            );
          }
        }
      }
    }

    // 4. Check Legacy 16-hex key format: XXXX-XXXX-XXXX-XXXX
    final cleanLegacy = raw.replaceAll('-', '');
    if (cleanLegacy.length == 16) {
      final expected = computeExpectedKey(deviceId).replaceAll('-', '');
      if (cleanLegacy == expected) {
        return LicenseValidationResult(
          isValid: true,
          tier: LicenseTier.lifetime,
          formattedKey: formatKey(cleanLegacy),
        );
      }
    }

    return const LicenseValidationResult(isValid: false);
  }

  /// Backward-compatible boolean verification method.
  static bool verifyKey(String enteredKey, String deviceId) {
    return validateKeyDetailed(enteredKey, deviceId).isValid;
  }

  /// Formats raw key with hyphens.
  static String formatKey(String key) {
    final clean = key.replaceAll('-', '').replaceAll(' ', '').trim().toUpperCase();
    if (clean.length != 16) return key;
    return '${clean.substring(0, 4)}-${clean.substring(4, 8)}-${clean.substring(8, 12)}-${clean.substring(12, 16)}';
  }

  /// Validates the entered key and activates ClipShield Pro under the decoded tier.
  Future<bool> activate(String enteredKey) async {
    final currentDevice = await getDeviceId();
    final result = validateKeyDetailed(enteredKey, currentDevice);

    if (result.isValid) {
      _isActivated = true;
      _currentTier = result.tier;
      final prefs = _prefs ?? await SharedPreferences.getInstance();

      await prefs.setString(_keyActivationKey, result.formattedKey);
      await prefs.setString(_keyLicenseTier, _currentTier.name);
      await prefs.setBool(_keyIsActivated, true);

      if (_currentTier == LicenseTier.monthly) {
        _expiresAt = DateTime.now().add(Duration(days: result.parameter));
        await prefs.setString(_keyExpiresAt, _expiresAt!.toIso8601String());
      } else if (_currentTier == LicenseTier.videoPack) {
        _remainingVideos = result.parameter;
        await prefs.setInt(_keyRemainingVideos, _remainingVideos);
      }

      return true;
    }

    return false;
  }

  /// Consumes one trial or video pack render credit. Does not affect lifetime or monthly.
  Future<void> consumeTrial() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();

    if (_currentTier == LicenseTier.videoPack) {
      _remainingVideos = max(0, _remainingVideos - 1);
      await prefs.setInt(_keyRemainingVideos, _remainingVideos);
      if (_remainingVideos <= 0) {
        _isActivated = false;
        await prefs.setBool(_keyIsActivated, false);
      }
      return;
    }

    if (isActivated()) return;

    // Spend the free allowance first, then earned task credits, so a user is
    // never charged a credit while a free render is still available.
    if (_trialCount < maxTrialRenders) {
      _trialCount += 1;
      await prefs.setInt(_keyTrialCount, _trialCount);
      return;
    }

    if (bonusAvailable > 0) {
      _bonusUsed += 1;
      await prefs.setInt(_keyBonusUsed, _bonusUsed);
      // Report the spend so a reinstall cannot forget it.
      unawaited(syncBonusCredits());
    }
  }

  /// Reconciles cached task credits with the server, which is authoritative.
  ///
  /// Silently does nothing when the API is unconfigured or unreachable, so the
  /// app keeps working fully offline with whatever credits it already has.
  Future<void> syncBonusCredits() async {
    if (!TaskApiService.isConfigured) return;

    final balance = await TaskApiService.instance.syncBalance(creditsUsed: _bonusUsed);
    if (balance == null) return;

    await applyBonusBalance(balance.earned, balance.used);
  }

  /// Writes a server-provided balance into local cache.
  Future<void> applyBonusBalance(int earned, int used) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _bonusEarned = earned < 0 ? 0 : earned;
    // Never let the server lower the used count below what we already spent,
    // otherwise a stale response would hand back a credit twice.
    _bonusUsed = used > _bonusUsed ? used : _bonusUsed;
    await prefs.setInt(_keyBonusEarned, _bonusEarned);
    await prefs.setInt(_keyBonusUsed, _bonusUsed);
  }

  /// Pre-composed WhatsApp order URL for the currently configured number.
  String getWhatsAppUrl(String deviceId) {
    const text = 'Hello%20ClipShield%20Team,%20I%20want%20to%20activate%20'
        'ClipShield%20Pro.%20My%20Device%20ID%20is:%20';
    return 'https://wa.me/$supportWhatsAppInternational?text=$text$deviceId';
  }

  /// Debug / testing helper to reset licensing state.
  Future<void> resetForTesting({bool activate = false, LicenseTier tier = LicenseTier.lifetime}) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _trialCount = 0;
    _isActivated = activate;
    _currentTier = activate ? tier : LicenseTier.trial;
    _remainingVideos = tier == LicenseTier.videoPack ? 5 : 0;
    _expiresAt = tier == LicenseTier.monthly ? DateTime.now().add(const Duration(days: 30)) : null;

    await prefs.setInt(_keyTrialCount, 0);
    await prefs.setBool(_keyIsActivated, activate);
    await prefs.remove(_keyActivationKey);
    await prefs.remove(_keyLicenseTier);
    await prefs.remove(_keyExpiresAt);
    await prefs.remove(_keyRemainingVideos);
  }
}
