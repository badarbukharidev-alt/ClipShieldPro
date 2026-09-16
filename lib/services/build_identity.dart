/// Which build this is: the house app, or a particular reseller's.
///
/// The code is compiled in with `--dart-define` rather than fetched, because it
/// has to be known before the first API call — it is *what the API keys off* to
/// decide whose support number and whose update to send back.
///
/// Build a reseller's copy with:
///
///     tools/build_reseller.sh <code>
///
/// and the house build with the ordinary `tools/build_release.sh`.
class BuildIdentity {
  BuildIdentity._();

  static const String _raw =
      String.fromEnvironment('CLIPSHIELD_RESELLER', defaultValue: '');

  /// Normalised reseller code, or empty for the house build.
  ///
  /// Validated with the same rule the panel applies, so a typo in a build
  /// command produces a plain house build rather than an app quietly reporting
  /// itself against a reseller that does not exist.
  static final String resellerCode = _normalise(_raw);

  static bool get isResellerBuild => resellerCode.isNotEmpty;

  /// Whether the hidden in-app admin tools are compiled in.
  ///
  /// Never in a reseller build. Those screens generate licence keys directly on
  /// the device with no quota and no record, which would let a reseller mint
  /// unlimited keys and bypass their allowance entirely — and the same gate is
  /// reachable by anyone holding a copy of their APK.
  static bool get allowsInAppAdmin => !isResellerBuild;

  static String _normalise(String raw) {
    final code = raw.trim().toLowerCase();
    if (code.isEmpty) return '';
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{1,31}$').hasMatch(code)) return '';

    return code;
  }
}
