import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_update.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

/// Offers the release the admin panel is advertising.
///
/// "Update now" opens the APK link in the browser and hands off to Android's
/// installer. The app never downloads or installs anything itself — see the
/// note on [UpdateService] for why that extra tap is deliberate.
class UpdateDialog extends StatefulWidget {
  final AppUpdate update;

  const UpdateDialog({super.key, required this.update});

  /// Shows the dialog if one is not already up. Returns once it closes.
  ///
  /// A mandatory update is not dismissible: no barrier tap, no back button.
  static Future<void> show(BuildContext context, AppUpdate update) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !update.mandatory,
      builder: (_) => UpdateDialog(update: update),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _opening = false;

  Future<void> _openDownload() async {
    setState(() => _opening = true);
    try {
      final uri = Uri.parse(widget.update.apkUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text("Could not open the download link:\n${widget.update.apkUrl}"),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text("Could not open the download link."),
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;

    return PopScope(
      canPop: !update.mandatory,
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

                if (update.notes.isNotEmpty) ...[
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

                const SizedBox(height: 18),
                Text(
                  update.mandatory
                      ? "This version is no longer supported. Install the update to keep using ClipShield."
                      : "The download opens in your browser. Android will ask before installing it.",
                  style: const TextStyle(fontSize: 12.5, color: AppColors.mut, height: 1.4),
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _opening ? null : _openDownload,
                    icon: _opening
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download_rounded, size: 19),
                    label: Text(
                      _opening ? "Opening..." : "Update now",
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
                ),

                if (!update.mandatory) ...[
                  const SizedBox(height: 8),
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
