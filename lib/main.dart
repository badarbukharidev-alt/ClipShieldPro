import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'screens/splash_screen.dart';
import 'services/license_service.dart';
import 'services/build_identity.dart';
import 'services/device_capability_service.dart';
import 'services/remote_config_service.dart';
import 'services/update_service.dart';
import 'services/render_job_service.dart';
import 'theme/app_theme.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Intercept Flutter framework build / rendering errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('ClipShield caught FlutterError: ${details.exceptionAsString()}');
    };

    // 2. Intercept uncaught platform errors (prevents crash on all Android OEM skins)
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      debugPrint('ClipShield caught PlatformDispatcher error: $error\n$stack');
      return true; // Handled so Android OS does not terminate the app process
    };

    // 3. Fallback widget in case any screen encounters a layout assertion or rendering fault
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: AppColors.bg,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accentTangerine.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppColors.accentTangerine,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "ClipShield Pro",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Display recovered successfully. Please continue using the app.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mut,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    };

    // 4. Defensively initialize each subsystem so a failure in any single service
    // NEVER prevents the app from launching.
    try {
      await BuildIdentity.load();
    } catch (e) {
      debugPrint('BuildIdentity.load failed: $e');
    }

    try {
      await DeviceCapabilityService.instance.load();
    } catch (e) {
      debugPrint('DeviceCapabilityService.load failed: $e');
    }

    try {
      DeviceCapabilityService.instance.applyImageCacheLimit();
    } catch (e) {
      debugPrint('applyImageCacheLimit failed: $e');
    }

    try {
      await RemoteConfigService.instance.load();
    } catch (e) {
      debugPrint('RemoteConfigService.load failed: $e');
    }

    try {
      await UpdateService.instance.init();
    } catch (e) {
      debugPrint('UpdateService.init failed: $e');
    }

    try {
      await LicenseService.instance.init();
    } catch (e) {
      debugPrint('LicenseService.init failed: $e');
    }

    try {
      await RenderJobService.instance.reconcileInterruptedJobs();
    } catch (e) {
      debugPrint('reconcileInterruptedJobs failed: $e');
    }

    try {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.card,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
    } catch (e) {
      debugPrint('SystemChrome overlay style error: $e');
    }

    try {
      _initForegroundTask();
    } catch (e) {
      debugPrint('_initForegroundTask error: $e');
    }

    runApp(const ClipShieldProApp());
  }, (Object error, StackTrace stack) {
    debugPrint('ClipShield caught top-level zone error: $error\n$stack');
  });
}

void _initForegroundTask() {
  try {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'clipshield_render_channel',
        channelName: 'ClipShield Render Engine',
        channelDescription: 'Maintains on-device video rendering and audio DSP processing in the background.',
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
        iconData: const NotificationIconData(
          resType: ResourceType.drawable,
          resPrefix: ResourcePrefix.ic,
          name: 'notification',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  } catch (e) {
    debugPrint('Foreground task initialization exception: $e');
  }
}

class ClipShieldProApp extends StatelessWidget {
  const ClipShieldProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClipShield Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
