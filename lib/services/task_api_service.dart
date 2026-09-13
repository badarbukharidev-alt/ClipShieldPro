import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../models/reward_task.dart';
import 'device_identity_service.dart';

/// Client for the ClipShield admin task/credit API.
///
/// Every request is HMAC-signed with [apiSecret], which must match `API_SECRET`
/// in the panel's `inc/config.php`. That secret is deliberately *not* the licence
/// salt: if this one leaks, the task endpoints are exposed but licence keys
/// remain unforgeable.
class TaskApiService {
  TaskApiService._();
  static final TaskApiService instance = TaskApiService._();

  /// Panel base URL. The endpoint is `<base>/api/v1.php`.
  static const String baseUrl = 'https://clipshieldpro.toolsfinity.io';

  /// Must be byte-identical to API_SECRET in inc/config.php.
  static const String apiSecret = 'CHANGE_ME_TO_A_64_CHAR_RANDOM_HEX_STRING';

  /// Reported to the panel so you can see which build a device is on.
  static const String appVersion = '1.2.7';

  static bool get isConfigured =>
      apiSecret != 'CHANGE_ME_TO_A_64_CHAR_RANDOM_HEX_STRING' && apiSecret.length >= 32;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 12),
    headers: {'Content-Type': 'application/json'},
    // Non-2xx responses carry a usable error code, so read them rather than throw.
    validateStatus: (status) => status != null && status < 500,
  ));

  final Random _random = Random.secure();

  String _nonce() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Canonical string must match api_canonical() in inc/sign.php exactly:
  ///   action|DEVICE_ID|ts|nonce|extra
  ///
  /// Static and public so a test can pin it against the PHP implementation
  /// without needing a configured secret or a device.
  static String canonicalString(
    String action,
    String deviceId,
    int ts,
    String nonce,
    String extra,
  ) {
    return [action, deviceId.trim().toUpperCase(), '$ts', nonce, extra].join('|');
  }

  static String signWith(
    String secret,
    String action,
    String deviceId,
    int ts,
    String nonce,
    String extra,
  ) {
    final canonical = canonicalString(action, deviceId, ts, nonce, extra);
    return Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(canonical)).toString();
  }

  String _sign(String action, String deviceId, int ts, String nonce, String extra) =>
      signWith(apiSecret, action, deviceId, ts, nonce, extra);

  Future<Map<String, dynamic>?> _post(
    String action, {
    String extra = '',
    Map<String, dynamic> body = const {},
  }) async {
    if (!isConfigured) return null;

    final deviceId = await DeviceIdentityService.instance.getDeviceId();
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final nonce = _nonce();

    final payload = <String, dynamic>{
      ...body,
      'action': action,
      'device_id': deviceId,
      'ts': ts,
      'nonce': nonce,
      'sig': _sign(action, deviceId, ts, nonce, extra),
      'app_version': appVersion,
    };

    try {
      final response = await _dio.post<dynamic>('/api/v1.php', data: payload);
      final data = response.data;
      if (data is Map) return data.cast<String, dynamic>();
      if (data is String && data.isNotEmpty) {
        final decoded = jsonDecode(data);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      }
      return null;
    } on DioException {
      return null; // Offline or unreachable; callers fall back to cache.
    } catch (_) {
      return null;
    }
  }

  /// Authoritative balance. [creditsUsed] lets the server take the higher of the
  /// two counts, so a reinstall cannot "forget" credits already spent.
  Future<CreditBalance?> syncBalance({required int creditsUsed}) async {
    final res = await _post('device.sync', body: {'credits_used': creditsUsed});
    if (res == null || res['ok'] != true) return null;
    return CreditBalance.fromMap(res);
  }

  /// Active tasks plus this device's claim state.
  Future<({List<RewardTask> tasks, CreditBalance balance})?> fetchTasks() async {
    final res = await _post('tasks.list');
    if (res == null || res['ok'] != true) return null;

    final raw = res['tasks'];
    final tasks = <RewardTask>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          tasks.add(RewardTask.fromMap(item.cast<String, dynamic>()));
        }
      }
    }

    return (tasks: tasks, balance: CreditBalance.fromMap(res));
  }

  /// Claims a task. [dwellSeconds] is how long the user was away; the server
  /// rejects anything under the task's configured minimum.
  Future<ClaimResult> claimTask(int taskId, {required int dwellSeconds}) async {
    final res = await _post(
      'tasks.claim',
      extra: '$taskId',
      body: {'task_id': taskId, 'dwell_secs': dwellSeconds},
    );

    if (res == null) {
      return const ClaimResult(ok: false, error: 'network');
    }
    if (res['ok'] != true) {
      return ClaimResult(ok: false, error: res['error'] as String? ?? 'unknown');
    }

    return ClaimResult(
      ok: true,
      awarded: (res['awarded'] as num?)?.toInt() ?? 0,
      balance: CreditBalance.fromMap(res),
    );
  }
}
