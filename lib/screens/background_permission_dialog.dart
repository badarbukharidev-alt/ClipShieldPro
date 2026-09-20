import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/project_storage_service.dart';
import '../services/render_foreground_service.dart';
import '../theme/app_theme.dart';

/// Asks for a battery-optimisation exemption before the first long render.
///
/// A foreground service keeps the process alive on stock Android, but the OEM
/// skins most users are actually on — Xiaomi, Oppo, Vivo, Samsung — kill
/// background work anyway unless the app is exempt. Without this, a 40-minute
/// render reliably dies the moment the user switches apps.
class BackgroundPermissionDialog {
  static const String _keyAsked = 'clipshield_asked_battery_exemption';

  /// Shows the prompt when it is needed and has not already been declined.
  ///
  /// Never blocks a render: if the user says no, the job still runs, it is just
  /// vulnerable to being killed.
  static Future<void> maybeShow(BuildContext context) async {
    final isBgEnabled = await ProjectStorageService.getBackgroundRenderingEnabled();
    if (!isBgEnabled) return;

    final service = RenderForegroundService.instance;

    if (await service.isBatteryOptimisationDisabled()) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyAsked) == true) return;

    if (!context.mounted) return;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.battery_saver, color: AppColors.accentTangerine, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Keep rendering in the background',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: const Text(
          'Android stops this app from working when you switch away, which cancels '
          'long renders part-way through.\n\n'
          'Allow ClipShield to run without battery restrictions so your videos '
          'finish even when the app is closed.',
          style: TextStyle(color: AppColors.mut, fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now', style: TextStyle(color: AppColors.mut)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentTangerine,
              foregroundColor: Colors.white,
            ),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    // Only remember an outright refusal. If they accepted but the system prompt
    // did not stick, asking again next time is the helpful behaviour.
    if (accepted == true) {
      await service.requestBatteryExemption();
    } else {
      await prefs.setBool(_keyAsked, true);
    }
  }

  /// Clears the "do not ask again" flag, for a Settings-screen retry.
  static Future<void> resetPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAsked);
  }
}
