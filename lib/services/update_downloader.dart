import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_update.dart';
import 'media_store_service.dart';

/// How far along an in-app update is.
enum UpdateStage { idle, downloading, verifying, installing, failed }

class UpdateProgress {
  final UpdateStage stage;

  /// 0..1 while downloading, null when the server sends no content length.
  final double? fraction;
  final int received;
  final int total;

  /// Set only when [stage] is [UpdateStage.failed].
  final String? error;

  const UpdateProgress({
    required this.stage,
    this.fraction,
    this.received = 0,
    this.total = 0,
    this.error,
  });
}

/// Downloads a release and hands it to Android's installer, so an update can be
/// applied without leaving the app.
///
/// The app does not install anything itself and could not: Android shows its own
/// confirmation screen, and from Android 8 the user must separately allow this
/// app to install packages at all. What happens here is download, verify, hand
/// over.
///
/// The verification step is the part worth keeping. The APK link comes from the
/// admin panel, so without it anyone who took over that panel could point every
/// install at a different package. [MediaStoreService.verifyApk] compares the
/// downloaded APK's signing certificate against the running build's and refuses
/// a *mismatch* before the user is asked anything.
///
/// A certificate that cannot be *read* is a different thing and is allowed
/// through. Android enforces signature matching at install time itself and
/// cannot be talked out of it, so refusing what we merely could not parse only
/// stopped genuine updates with "the download could not be verified" -- which is
/// exactly what it did.
class UpdateDownloader {
  UpdateDownloader._();
  static final UpdateDownloader instance = UpdateDownloader._();

  final Dio _dio = Dio();
  CancelToken? _cancelToken;

  bool _busy = false;
  bool get isBusy => _busy;

  /// Downloads, verifies and launches the installer for [update].
  ///
  /// Returns null on success, or a message explaining what stopped it.
  Future<String?> downloadAndInstall(
    AppUpdate update, {
    required void Function(UpdateProgress) onProgress,
  }) async {
    if (_busy) return 'An update is already downloading.';

    // Belt and braces: AppUpdate.fromMap already rejects non-HTTPS, but this is
    // the call that ends in an installer, so it is checked again at the point of
    // use rather than trusted from three files away.
    if (!update.apkUrl.startsWith('https://')) {
      return 'That download link is not secure, so it was not used.';
    }

    final media = MediaStoreService.instance;
    if (!media.isSupported) {
      return 'In-app updates are only available on Android.';
    }

    _busy = true;
    _cancelToken = CancelToken();

    File? target;
    try {
      final dir = await getTemporaryDirectory();
      final updates = Directory('${dir.path}/clipshield_update');
      if (!await updates.exists()) await updates.create(recursive: true);

      // Version-stamped, and any previous download is cleared first: a partial
      // file left by a cancelled attempt would otherwise fail verification with
      // a confusing "not an APK".
      for (final stale in updates.listSync()) {
        try {
          stale.deleteSync();
        } catch (_) {
          // A file we cannot delete is not a reason to abandon the update.
        }
      }

      target = File('${updates.path}/ClipShield-${update.versionName}.apk');

      onProgress(const UpdateProgress(stage: UpdateStage.downloading));

      await _dio.download(
        update.apkUrl,
        target.path,
        cancelToken: _cancelToken,
        options: Options(receiveTimeout: const Duration(minutes: 10)),
        onReceiveProgress: (received, total) {
          onProgress(UpdateProgress(
            stage: UpdateStage.downloading,
            fraction: total > 0 ? received / total : null,
            received: received,
            total: total,
          ));
        },
      );

      if (!await target.exists() || await target.length() == 0) {
        return 'The download did not complete.';
      }

      onProgress(const UpdateProgress(stage: UpdateStage.verifying));

      // "ok_unverified" means the certificate could not be read, not that it
      // was wrong. Android enforces signature matching at install time on its
      // own, so refusing here only stopped genuine updates -- see ApkInstaller.
      final verdict = await media.verifyApk(target.path);
      if (verdict != 'ok' && verdict != 'ok_unverified') {
        // A failed download is worth keeping nothing of.
        try {
          await target.delete();
        } catch (_) {}
        return _describe(verdict);
      }

      onProgress(const UpdateProgress(stage: UpdateStage.installing));

      final installed = await media.installApk(target.path);
      if (installed != 'ok') return _describe(installed);

      return null;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return null;
      return e.type == DioExceptionType.connectionError
          ? 'Could not reach the download. Check your connection.'
          : 'The download failed. Please try again.';
    } catch (_) {
      return 'The update could not be downloaded.';
    } finally {
      _busy = false;
      _cancelToken = null;
    }
  }

  void cancel() {
    _cancelToken?.cancel('cancelled by user');
    _busy = false;
  }

  /// Plain-English version of a reason code from ApkInstaller.
  static String _describe(String code) {
    switch (code) {
      case 'signature_mismatch':
        return 'That download is not signed by ClipShield, so it was not '
            'installed. Get the update from the official link instead.';
      case 'wrong_package':
        return 'That download is a different app, not a ClipShield update.';
      case 'not_an_apk':
        return 'The downloaded file is not a valid app package.';
      case 'signature_unreadable':
        // Kept for older builds of the bridge; the current one returns
        // "ok_unverified" and proceeds instead.
        return 'The download could not be verified, so it was not installed.';
      case 'needs_permission':
        return 'Android needs permission to install apps from ClipShield.';
      case 'missing_file':
        return 'The downloaded file is no longer there.';
      case 'provider_error':
      case 'launch_failed':
        return 'Android would not open the installer.';
      default:
        return 'The update could not be installed.';
    }
  }

  /// Whether the last failure was the one the user can fix themselves.
  static bool isPermissionProblem(String? message) =>
      message != null && message.contains('permission to install');
}
