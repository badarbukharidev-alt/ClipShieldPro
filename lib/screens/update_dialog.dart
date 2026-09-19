import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_update.dart';
import '../services/media_store_service.dart';
import '../services/update_downloader.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

/// Offers the release the admin panel is advertising, and installs it in place.
///
/// The download happens here; the install itself is Android's. The app verifies
/// the APK's signature against the running build before handing it over, so a
/// substituted package is refused before the user is ever asked to confirm one
/// — see [UpdateDownloader].
class UpdateDialog extends StatefulWidget {
  final AppUpdate update;

  const UpdateDialog({super.key, required this.update});

  /// Shows the dialog if one is not already up. Returns once it closes.
  ///
  /// A mandatory update is not dismissible: no barrier tap, no back button.
  static Future<void> show(BuildContext context, AppUpdate update) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !update.mandatory,
      builder: (_) => UpdateDialog(update: update),
    );
    if (!update.mandatory) {
      await UpdateService.instance.skipCurrent();
    }
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog>
    with WidgetsBindingObserver {
  UpdateProgress _progress = const UpdateProgress(stage: UpdateStage.idle);
  String? _error;
  bool _needsInstallPermission = false;

  /// True between sending the user to Settings and their coming back, so the
  /// dialog knows to re-check the permission on resume rather than leaving a
  /// stale "needs permission" state on a button that would now work.
  bool _awaitingPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_awaitingPermission) return;
    _recheckPermission();
  }

  /// Re-reads the install permission after a trip to Settings. Granting it
  /// clears the error so the next tap on Update goes straight to downloading,
  /// instead of reporting a permission that is no longer missing.
  Future<void> _recheckPermission() async {
    final granted = await MediaStoreService.instance.canInstallPackages();
    if (!mounted) return;

    setState(() {
      _awaitingPermission = false;
      if (granted) {
        _needsInstallPermission = false;
        _error = null;
      } else {
        _error = 'ClipShield still cannot install apps. Turn on "Allow from '
            'this source", then tap Update again.';
      }
    });
  }

  bool get _isWorking =>
      _progress.stage == UpdateStage.downloading ||
      _progress.stage == UpdateStage.verifying ||
      _progress.stage == UpdateStage.installing;

  Future<void> _update() async {
    setState(() {
      _error = null;
      _needsInstallPermission = false;
    });

    // Checked before the download rather than after: a user who has to visit
    // Settings should not first wait through 180 MB.
    //
    // And the trip to Settings happens on this tap, not the next one. Reporting
    // the problem and making the user press a second button was one tap of pure
    // ceremony -- there is nothing else they could have wanted from "Update".
    final media = MediaStoreService.instance;
    if (media.isSupported && !await media.canInstallPackages()) {
      if (!mounted) return;

      final opened = await media.openInstallSettings();
      if (!mounted) return;

      setState(() {
        _awaitingPermission = opened;
        _needsInstallPermission = !opened;
        _error = opened
            ? 'Turn on "Allow from this source", then come back and tap Update.'
            : 'Android needs permission to install apps from ClipShield.';
      });
      return;
    }

    final failure = await UpdateDownloader.instance.downloadAndInstall(
      widget.update,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (!mounted) return;

    if (failure == null) {
      // The system installer is now in front; record skip for this version so
      // returning to the app never re-prompts for what was just installed.
      await UpdateService.instance.skipCurrent();
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() {
      _progress = const UpdateProgress(stage: UpdateStage.failed);
      _error = failure;
      _needsInstallPermission = UpdateDownloader.isPermissionProblem(failure);
    });
  }

  /// Only reached when opening Settings failed outright, which on Android 8+
  /// should not happen.
  Future<void> _openInstallSettings() async {
    final opened = await MediaStoreService.instance.openInstallSettings();
    if (!mounted) return;

    setState(() {
      _awaitingPermission = opened;
      _error = opened
          ? 'Turn on "Allow from this source", then come back and tap Update.'
          : 'Open Settings > Apps > ClipShield > Install unknown apps, and '
              'allow it from there.';
    });
  }

  /// Fallback for anyone who would rather not install in place.
  Future<void> _openInBrowser() async {
    try {
      await launchUrl(Uri.parse(widget.update.apkUrl),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the download link.');
      }
    }
  }

  String get _statusLine {
    switch (_progress.stage) {
      case UpdateStage.downloading:
        if (_progress.total > 0) {
          final done = (_progress.received / (1024 * 1024)).toStringAsFixed(1);
          final all = (_progress.total / (1024 * 1024)).toStringAsFixed(1);
          return 'Downloading $done MB of $all MB';
        }
        return 'Downloading...';
      case UpdateStage.verifying:
        return 'Checking the download is genuine...';
      case UpdateStage.installing:
        return 'Opening the installer...';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    final canDismiss = !update.mandatory && !_isWorking;

    return PopScope(
      canPop: canDismiss,
      child: Dialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.softTangerine,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.system_update_rounded,
                          color: AppColors.accentTangerine, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            update.mandatory ? "Update required" : "Update available",
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Version ${update.versionName}",
                            style: const TextStyle(fontSize: 13, color: AppColors.mut),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (update.notes.isNotEmpty && !_isWorking) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      update.notes,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.ink,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],

                if (_isWorking) ...[
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progress.stage == UpdateStage.downloading
                          ? _progress.fraction
                          : null,
                      minHeight: 8,
                      backgroundColor: AppColors.bg,
                      valueColor: const AlwaysStoppedAnimation(AppColors.accentTangerine),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _statusLine,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.mut),
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],

                if (!_isWorking && _error == null) ...[
                  const SizedBox(height: 18),
                  Text(
                    update.mandatory
                        ? "This version is no longer supported. Install the update to keep using ClipShield."
                        : "The update installs inside the app. Android will ask you to confirm.",
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.mut, height: 1.4),
                  ),
                ],

                const SizedBox(height: 20),

                if (_needsInstallPermission)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openInstallSettings,
                      icon: const Icon(Icons.settings_rounded, size: 19),
                      label: const Text(
                        "Allow installs",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentTangerine,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isWorking ? null : _update,
                      icon: _isWorking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.download_rounded, size: 19),
                      label: Text(
                        _isWorking
                            ? "Updating..."
                            : (_error != null ? "Try again" : "Update now"),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentTangerine,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.line,
                        disabledForegroundColor: AppColors.mut,
                        minimumSize: const Size.fromHeight(52),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),

                if (_error != null && !_isWorking) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _openInBrowser,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.mut,
                        minimumSize: const Size.fromHeight(40),
                      ),
                      child: const Text(
                        "Download in browser instead",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],

                if (!update.mandatory && !_isWorking) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () async {
                        await UpdateService.instance.skipCurrent();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.mut,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: const Text(
                        "Later",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
