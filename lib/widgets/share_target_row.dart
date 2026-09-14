import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../services/media_store_service.dart';
import '../theme/app_theme.dart';

/// One app a finished clip can be sent to.
class ShareTarget {
  final String label;
  final IconData icon;
  final Color color;

  /// Android package names, tried in order. TikTok in particular ships under
  /// two different ones depending on the region the phone was sold in.
  final List<String> packages;

  const ShareTarget({
    required this.label,
    required this.icon,
    required this.color,
    required this.packages,
  });
}

/// The brand marks come from Font Awesome, not from Material's generic
/// look-alikes: a green speech bubble is not the WhatsApp logo, and users pick
/// these out by shape and colour rather than by reading the label.
const List<ShareTarget> kShareTargets = [
  ShareTarget(
    label: 'WhatsApp',
    icon: FontAwesomeIcons.whatsapp,
    color: Color(0xFF25D366),
    packages: ['com.whatsapp', 'com.whatsapp.w4b'],
  ),
  ShareTarget(
    label: 'Instagram',
    icon: FontAwesomeIcons.instagram,
    color: Color(0xFFE1306C),
    packages: ['com.instagram.android'],
  ),
  ShareTarget(
    label: 'YouTube',
    icon: FontAwesomeIcons.youtube,
    color: Color(0xFFFF0000),
    packages: ['com.google.android.youtube'],
  ),
  ShareTarget(
    label: 'TikTok',
    icon: FontAwesomeIcons.tiktok,
    color: Color(0xFF010101),
    packages: ['com.zhiliaoapp.musically', 'com.ss.android.ugc.trill'],
  ),
];

/// Row of share destinations under a finished render.
///
/// Each one sends straight to that app rather than opening the system chooser,
/// which is what "share to WhatsApp" is supposed to mean. An app that is not
/// installed is said so by name — the previous version wired every icon to the
/// same generic chooser, so tapping Instagram and tapping WhatsApp did exactly
/// the same thing.
class ShareTargetRow extends StatelessWidget {
  /// Files to send. Per-app sharing takes the first one, because Android's
  /// ACTION_SEND to a named app is single-file; "More" sends them all.
  final List<String> filePaths;
  final String mimeType;
  final String text;

  const ShareTargetRow({
    super.key,
    required this.filePaths,
    this.mimeType = 'video/mp4',
    this.text = 'Made with ClipShield Pro',
  });

  List<String> get _existing =>
      filePaths.where((p) => File(p).existsSync()).toList();

  /// Turns a reason code from the platform channel into something a user can
  /// act on. Falling back to the system chooser is the right move for anything
  /// that is our fault rather than theirs: the file is fine, only the direct
  /// route failed, and a chooser still gets the job done.
  Future<void> _shareTo(BuildContext context, ShareTarget target) async {
    final files = _existing;
    if (files.isEmpty) {
      _say(context, 'That file is no longer on the device.');
      return;
    }

    final media = MediaStoreService.instance;

    for (final package in target.packages) {
      if (!await media.isInstalled(package)) continue;

      final result = await media.shareTo(
        path: files.first,
        mimeType: mimeType,
        text: text,
        packageName: package,
      );
      if (result == 'ok') return;
      if (!context.mounted) return;

      switch (result) {
        case 'type_refused':
          _say(context, '${target.label} will not take this file type.');
          return;

        case 'missing_file':
          _say(context, 'That file is no longer on the device.');
          return;

        // Everything below is a fault on our side, not the target app's, so
        // the share still goes through — just via the chooser.
        default:
          await _shareAnywhere(context);
          return;
      }
    }

    if (context.mounted) {
      _say(context, '${target.label} is not installed on this phone.');
    }
  }

  Future<void> _shareAnywhere(BuildContext context) async {
    final files = _existing;
    if (files.isEmpty) {
      _say(context, 'That file is no longer on the device.');
      return;
    }

    await Share.shareXFiles(files.map(XFile.new).toList(), text: text);
  }

  static void _say(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.ink),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          for (final target in kShareTargets)
            Expanded(
              child: _ShareButton(
                icon: target.icon,
                label: target.label,
                color: target.color,
                onTap: () => _shareTo(context, target),
              ),
            ),
          Expanded(
            child: _ShareButton(
              icon: Icons.more_horiz_rounded,
              label: 'More',
              color: AppColors.ink,
              onTap: () => _shareAnywhere(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
