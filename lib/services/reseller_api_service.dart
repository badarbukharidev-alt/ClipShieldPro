import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'build_identity.dart';
import 'device_identity_service.dart';
import 'task_api_service.dart';

/// The three key tiers, matching the panel's CS_TIERS exactly.
enum ResellerTier { lifetime, monthly, videopack }

extension ResellerTierWire on ResellerTier {
  /// The string the panel expects. Must match CS_TIERS in inc/reseller.php.
  String get wire => switch (this) {
        ResellerTier.lifetime => 'lifetime',
        ResellerTier.monthly => 'monthly',
        ResellerTier.videopack => 'videopack',
      };

  String get label => switch (this) {
        ResellerTier.lifetime => 'Lifetime',
        ResellerTier.monthly => 'Monthly',
        ResellerTier.videopack => 'Video pack',
      };
}

/// What a reseller has left to spend, per tier.
class ResellerQuotas {
  final Map<ResellerTier, int> remaining;
  const ResellerQuotas(this.remaining);

  int of(ResellerTier tier) => remaining[tier] ?? 0;
  int get total => remaining.values.fold(0, (a, b) => a + b);

  static ResellerQuotas fromMap(dynamic raw) {
    final map = <ResellerTier, int>{};
    if (raw is Map) {
      for (final tier in ResellerTier.values) {
        map[tier] = (raw[tier.wire] as num?)?.toInt() ?? 0;
      }
    }
    return ResellerQuotas(map);
  }
}

/// Outcome of a login or a key generation.
class ResellerResult {
  final bool ok;
  final String? error;
  final String? key;
  final String? expires;
  final ResellerQuotas? quotas;

  const ResellerResult({
    required this.ok,
    this.error,
    this.key,
    this.expires,
    this.quotas,
  });
}

/// Lets a reseller sign in from inside their own build of the app and generate
/// keys against the allocation the admin granted them.
///
/// The heavy lifting — the password check, the quota, the key itself — all
/// happens on the panel. This is a thin signed client. The panel is the only
/// place a key can be minted for a reseller, so a reseller cannot exceed their
/// allowance no matter what the app does: even a tampered build hits the same
/// atomic quota check.
///
/// Only the short-lived token is kept on the phone, never the password.
class ResellerApiService {
  ResellerApiService._();
  static final ResellerApiService instance = ResellerApiService._();

  static const String _endpoint = '/api/reseller_app.php';
  static const String _keyToken = 'clipshield_reseller_token';
  static const String _keyName = 'clipshield_reseller_name';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: TaskApiService.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
    validateStatus: (status) => status != null && status < 500,
  ));

  final Random _random = Random.secure();

  String? _token;
  String _displayName = '';

  String get displayName => _displayName;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  /// True only in a build that carries a reseller code and the API secret.
  /// Without both, this screen has nothing to talk to.
  bool get isAvailable =>
      BuildIdentity.isResellerBuild && TaskApiService.isConfigured;

  String get _code => BuildIdentity.resellerCode;

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_keyToken);
    _displayName = prefs.getString(_keyName) ?? '';
  }

  Future<void> logout() async {
    _token = null;
    _displayName = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyName);
  }

  String _nonce() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Future<Map<String, dynamic>?> _post(
    String action,
    String extra,
    Map<String, dynamic> body,
  ) async {
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final nonce = _nonce();

    final payload = <String, dynamic>{
      ...body,
      'action': action,
      'code': _code,
      'ts': ts,
      'nonce': nonce,
      // Device id is empty in the canonical string for these actions; the code
      // goes in `extra`, matching api_verify() on the panel.
      'sig': TaskApiService.signWith(
        TaskApiService.apiSecret,
        action,
        '',
        ts,
        nonce,
        extra,
      ),
    };

    try {
      final response = await _dio.post<dynamic>(_endpoint, data: payload);
      final data = response.data;
      if (data is Map) return data.cast<String, dynamic>();
      if (data is String && data.isNotEmpty) {
        final decoded = jsonDecode(data);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      }
      return null;
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<ResellerResult> login(String username, String password) async {
    if (!isAvailable) {
      return const ResellerResult(ok: false, error: 'unavailable');
    }

    final res = await _post('reseller.login', _code, {
      'username': username.trim(),
      'password': password,
    });

    if (res == null) {
      return const ResellerResult(ok: false, error: 'network');
    }
    if (res['ok'] != true) {
      return ResellerResult(ok: false, error: res['error'] as String? ?? 'unknown');
    }

    _token = res['token'] as String?;
    _displayName = res['display_name'] as String? ?? '';

    final prefs = await SharedPreferences.getInstance();
    if (_token != null) await prefs.setString(_keyToken, _token!);
    await prefs.setString(_keyName, _displayName);

    return ResellerResult(ok: true, quotas: ResellerQuotas.fromMap(res['quotas']));
  }

  /// Generates one key against the reseller's allowance.
  ///
  /// Returns fresh quotas in the result, so the screen stays current without a
  /// separate refresh call. A `reauth_required` error means the stored token
  /// expired; it is cleared here so the screen falls back to the login form.
  Future<ResellerResult> generateKey({
    required String deviceId,
    required ResellerTier tier,
    required int param,
    String note = '',
  }) async {
    if (!isLoggedIn) {
      return const ResellerResult(ok: false, error: 'reauth_required');
    }

    final device = deviceId.trim().toUpperCase();

    final res = await _post('reseller.generate', _code, {
      'token': _token,
      'device_id': device,
      'tier': tier.wire,
      'param': param,
      'note': note.trim(),
    });

    if (res == null) {
      return const ResellerResult(ok: false, error: 'network');
    }

    // The token expired or was rejected; drop it so the UI shows the login form.
    if (res['error'] == 'reauth_required') {
      await logout();
      return const ResellerResult(ok: false, error: 'reauth_required');
    }

    if (res['ok'] != true) {
      return ResellerResult(
        ok: false,
        error: res['error'] as String? ?? 'unknown',
        quotas: res['quotas'] != null ? ResellerQuotas.fromMap(res['quotas']) : null,
      );
    }

    return ResellerResult(
      ok: true,
      key: res['key'] as String?,
      expires: res['expires'] as String?,
      quotas: ResellerQuotas.fromMap(res['quotas']),
    );
  }

  /// The customer's own device id, offered as the default so a reseller
  /// activating on the same phone need not type it.
  Future<String> currentDeviceId() => DeviceIdentityService.instance.getDeviceId();
}
