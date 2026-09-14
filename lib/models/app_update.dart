/// An update the admin panel is advertising.
///
/// [versionCode] is the comparison key, not [versionName]: it is the same
/// integer Android uses for `versionCode`, so "1.2.10" vs "1.2.9" never has to
/// be parsed and a release can be renamed without confusing the comparison.
class AppUpdate {
  final String versionName;
  final int versionCode;
  final String apkUrl;
  final String notes;

  /// A mandatory update cannot be dismissed. Reserved for builds that genuinely
  /// stop working against the server — using it for ordinary releases trains
  /// people to see the app as hostile.
  final bool mandatory;

  const AppUpdate({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    this.notes = '',
    this.mandatory = false,
  });

  /// Returns null when the panel is advertising nothing usable. A blank or
  /// non-HTTPS URL is treated as "no update" rather than shown with a button
  /// that fails: the panel is the place to notice that, not the phone.
  static AppUpdate? fromMap(Map<String, dynamic> map) {
    final code = (map['version_code'] as num?)?.toInt() ?? 0;
    final url = (map['apk_url'] as String? ?? '').trim();
    final name = (map['version_name'] as String? ?? '').trim();

    if (code <= 0 || name.isEmpty) return null;
    if (!url.startsWith('https://')) return null;

    return AppUpdate(
      versionName: name,
      versionCode: code,
      apkUrl: url,
      notes: (map['notes'] as String? ?? '').trim(),
      mandatory: map['mandatory'] == true || map['mandatory'] == 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'version_name': versionName,
        'version_code': versionCode,
        'apk_url': apkUrl,
        'notes': notes,
        'mandatory': mandatory,
      };

  @override
  String toString() => 'AppUpdate($versionName / $versionCode)';
}
