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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Panel-owned settings (currently the support contact) load before anything
  // can read them, so no screen ever renders the fallback number briefly and
  // then swaps it.
  // Which build this is -- house, or a particular reseller's. Must precede any
  // API call: the code is what the server keys off to decide whose support
  // number and whose update to return.
  await BuildIdentity.load();

  // Read what this phone can cope with before anything sizes itself. The
  // render pipeline, the image cache and subject tracking all key off it.
  await DeviceCapabilityService.instance.load();
  DeviceCapabilityService.instance.applyImageCacheLimit();

  await RemoteConfigService.instance.load();

  // Reads the running build's versionCode and any release cached from a
  // previous sync, so an offline launch still knows an update exists.
  await UpdateService.instance.init();

  // Initialize offline cryptographic licensing engine
  await LicenseService.instance.init();

  // Resolve any job that was killed with a previous process so no project is
  // left permanently stuck showing "rendering".
  await RenderJobService.instance.reconcileInterruptedJobs();

  // Set system navigation and status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.card,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  _initForegroundTask();

  runApp(const ClipShieldProApp());
}

void _initForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'clipshield_render_channel',
      channelName: 'ClipShield Render Engine',
      channelDescription: 'Maintains on-device video rendering and audio DSP processing in the background.',
      channelImportance: NotificationChannelImportance.DEFAULT,
      priority: NotificationPriority.DEFAULT,
      iconData: const NotificationIconData(
        resType: ResourceType.mipmap,
        resPrefix: ResourcePrefix.ic,
        name: 'launcher',
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
