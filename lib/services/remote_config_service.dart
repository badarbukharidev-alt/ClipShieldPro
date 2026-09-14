import 'package:shared_preferences/shared_preferences.dart';

/// Values the admin panel owns and the app mirrors.
///
/// Right now that is only the support contact, but the shape is deliberately
/// generic: the panel is the source of truth, the phone caches the last value
/// it was told, and a compiled-in default keeps the app usable on a fresh
/// install that has never reached the server (or a build with no API secret,
/// where [TaskApiService] never calls out at all).
///
/// Reads are synchronous because the support number is needed inline while
/// building a button label. [load] is called once at startup; until it
/// completes the defaults apply, which is correct rather than merely tolerable.
class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  /// Used until the panel says otherwise. Matches the number the app shipped
  /// with, so an offline install behaves exactly as it did before.
  static const String defaultWhatsApp = '923079031153';
  static const String defaultPhoneDisplay = '03079031153';

  static const String _keyWhatsApp = 'clipshield_support_whatsapp';
  static const String _keyPhone = 'clipshield_support_phone_display';

  SharedPreferences? _prefs;
  String _whatsApp = defaultWhatsApp;
  String _phoneDisplay = defaultPhoneDisplay;

  /// International format, digits only — what wa.me expects.
  String get supportWhatsApp => _whatsApp;

  /// How the number is written to the user, which is usually the local form.
  String get supportPhoneDisplay => _phoneDisplay;

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    _whatsApp = _clean(_prefs!.getString(_keyWhatsApp)) ?? defaultWhatsApp;
    _phoneDisplay = _clean(_prefs!.getString(_keyPhone)) ?? defaultPhoneDisplay;
  }

  /// Applies whatever the panel sent with an API response. Absent or blank
  /// fields leave the current value alone — a partial response must never
  /// silently reset the contact number to the default.
  Future<void> applyFromApi(Map<String, dynamic> response) async {
    final whatsApp = _clean(response['support_whatsapp']?.toString());
    final phone = _clean(response['support_phone']?.toString());
    if (whatsApp == null && phone == null) return;

    _prefs ??= await SharedPreferences.getInstance();

    if (whatsApp != null && whatsApp != _whatsApp) {
      _whatsApp = whatsApp;
      await _prefs!.setString(_keyWhatsApp, whatsApp);
    }
    if (phone != null && phone != _phoneDisplay) {
      _phoneDisplay = phone;
      await _prefs!.setString(_keyPhone, phone);
    }
  }

  /// Trims, and rejects anything that is not a plausible phone number, so a
  /// mistyped panel field cannot produce a wa.me link that goes nowhere.
  static String? _clean(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.length < 6 || trimmed.length > 24) return null;
    if (!RegExp(r'^[0-9+][0-9 +-]*$').hasMatch(trimmed)) return null;
    return trimmed;
  }
}
