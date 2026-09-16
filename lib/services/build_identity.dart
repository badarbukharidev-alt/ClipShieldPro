import 'package:flutter/services.dart';

/// Which build this is: the house app, or a particular reseller's.
///
/// ## Why the code is an asset and not a compile-time constant
///
/// It started as a `--dart-define`, which meant one full Flutter build per
/// reseller. Twenty resellers was twenty AOT compiles for twenty APKs that
/// differ by a single short string.
///
/// It now lives in `assets/build/reseller.txt`, which can be rewritten inside a
/// finished APK. The build pipeline compiles **twice** — once for the house app
/// and once for a reseller base — and then stamps each reseller's code into a
/// copy of that base and re-signs it. Seconds each instead of minutes.
///
/// ## What is still compiled in, and why
///
/// [allowsInAppAdmin] remains a compile-time define. It has to: the in-app admin
/// screens mint licence keys on the device with no quota and no record, so in a
/// reseller build they must be *absent*, not merely hidden behind a runtime
/// check on a file that anyone repackaging the APK could edit back. The reseller
/// base is built with the admin tools compiled out, and every stamped APK
/// inherits that.
class BuildIdentity {
  BuildIdentity._();

  /// Where the stamping step writes the code. Inside the APK this lands at
  /// `assets/flutter_assets/assets/build/reseller.txt`.
  static const String assetPath = 'assets/build/reseller.txt';

  /// What the file says before anything has been stamped into it. Treated as
  /// "no reseller", so an unstamped base build behaves as a plain app rather
  /// than reporting itself against a reseller literally called `__RESELLER__`.
  static const String placeholder = '__RESELLER__';

  /// Compile-time override, kept for a one-off build without the stamping step:
  ///
  ///     flutter build apk --dart-define=CLIPSHIELD_RESELLER=abrar
  ///
  /// Wins over the asset when set, because someone passing it explicitly means
  /// it.
  static const String _define =
      String.fromEnvironment('CLIPSHIELD_RESELLER', defaultValue: '');

  /// Set on the reseller base build. This is what removes the admin tools.
  static const bool _isResellerBase =
      bool.fromEnvironment('CLIPSHIELD_RESELLER_BASE', defaultValue: false);

  static String _resellerCode = '';
  static bool _loaded = false;

  /// Normalised reseller code, or empty for the house build.
  static String get resellerCode => _resellerCode;

  static bool get isResellerBuild => _resellerCode.isNotEmpty;

  /// Whether the hidden in-app admin tools are compiled in.
  ///
  /// False for the whole reseller base build, so it is false for every APK
  /// stamped from it — including one whose asset was tampered with, since the
  /// code simply is not there to reach.
  static bool get allowsInAppAdmin => !_isResellerBase;

  /// Reads the stamped code. Call once at startup, before the first API call —
  /// the code is what the server keys off to decide whose support number and
  /// whose update to return.
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;

    // An explicit define wins and saves the asset read entirely.
    final fromDefine = _normalise(_define);
    if (fromDefine.isNotEmpty) {
      _resellerCode = fromDefine;
      return;
    }

    try {
      final raw = await rootBundle.loadString(assetPath);
      _resellerCode = _normalise(raw);
    } catch (_) {
      // Missing asset means the house build, which is the safe reading: a
      // missing file must never be guessed into somebody's reseller code.
      _resellerCode = '';
    }
  }

  /// Validates with the same rule the panel applies, so a bad stamp produces a
  /// plain house build rather than an app reporting against a reseller that
  /// does not exist.
  static String _normalise(String raw) {
    final code = raw.trim().toLowerCase();
    if (code.isEmpty || code == placeholder.toLowerCase()) return '';
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{1,31}$').hasMatch(code)) return '';

    return code;
  }

  /// Test seam. Production code goes through [load].
  static void debugSet(String code) {
    _loaded = true;
    _resellerCode = _normalise(code);
  }

  static void debugReset() {
    _loaded = false;
    _resellerCode = '';
  }
}
