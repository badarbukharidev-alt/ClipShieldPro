import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Keeps the app's process alive while renders are running.
///
/// FFmpeg work happens on the main isolate. Without a foreground service
/// Android is free to kill that process as soon as the app leaves the screen,
/// which silently abandons a half-finished render. Holding a foreground service
/// for exactly as long as the queue is busy keeps the process (and therefore
/// the render) alive when the user switches away or closes the app.
///
/// No task callback is supplied on purpose: a callback would spawn a second
/// isolate that cannot see the queue. The service is here for process lifetime,
/// not to run the work itself.
class RenderForegroundService {
  RenderForegroundService._();
  static final RenderForegroundService instance = RenderForegroundService._();

  bool _isRunning = false;
  String _lastText = '';

  bool get isRunning => _isRunning;

  bool get _isSupported => Platform.isAndroid || Platform.isIOS;

  /// Whether Android will let this app keep working once it leaves the screen.
  ///
  /// A foreground service alone is not enough on the OEM skins that dominate in
  /// practice — Xiaomi, Oppo, Vivo and Samsung all kill background processes
  /// unless the app is exempt from battery optimisation. This is the single most
  /// common reason a long render dies on minimise.
  Future<bool> isBatteryOptimisationDisabled() async {
    if (!Platform.isAndroid) return true;
    try {
      return await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    } catch (_) {
      return true; // Unknown: do not nag on a platform that cannot answer.
    }
  }

  /// Sends the user to the system exemption prompt.
  Future<void> requestBatteryExemption() async {
    if (!Platform.isAndroid) return;
    try {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    } catch (_) {
      try {
        await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
      } catch (_) {}
    }
  }

  /// Whether the last start() call actually produced a running service, so the
  /// UI can tell the user when their render is unprotected instead of failing
  /// silently mid-job.
  Future<bool> isServiceRunning() async {
    if (!_isSupported) return false;
    try {
      return await FlutterForegroundTask.isRunningService;
    } catch (_) {
      return _isRunning;
    }
  }

  /// Called when the queue goes from idle to busy.
  Future<void> start({required String title, required String text}) async {
    if (!_isSupported || _isRunning) return;
    try {
      await FlutterForegroundTask.startService(
        notificationTitle: title,
        notificationText: text,
      );
      _isRunning = true;
      _lastText = text;
    } catch (_) {
      // A denied notification permission must never fail the render itself.
      _isRunning = false;
    }
  }

  /// Progress updates. Repeated identical text is skipped so the notification
  /// is not rewritten on every FFmpeg statistics callback.
  Future<void> update({required String title, required String text}) async {
    if (!_isSupported || !_isRunning || text == _lastText) return;
    _lastText = text;
    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    } catch (_) {
      // Losing a notification update is not worth interrupting the render.
    }
  }

  /// Called when the queue drains. Releases the process back to Android.
  Future<void> stop() async {
    if (!_isSupported || !_isRunning) return;
    _isRunning = false;
    _lastText = '';
    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {}
  }
}
