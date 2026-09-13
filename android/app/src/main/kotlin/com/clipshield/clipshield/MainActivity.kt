package com.clipshield.clipshield

import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "com.clipshield/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Settings.Secure.ANDROID_ID survives clearing app data and
                    // uninstall/reinstall, and is scoped to the app's signing key.
                    // That persistence is what stops reward credits being farmed
                    // by wiping the app.
                    "getAndroidId" -> {
                        try {
                            @Suppress("HardwareIds")
                            val id = Settings.Secure.getString(
                                contentResolver,
                                Settings.Secure.ANDROID_ID
                            )
                            result.success(id)
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }

                    // Coarse hardware descriptor, recorded server-side purely as a
                    // secondary farming signal. Never used as an identity on its own.
                    "getDeviceFingerprint" -> {
                        try {
                            val parts = listOf(
                                Build.MANUFACTURER,
                                Build.MODEL,
                                Build.DEVICE,
                                Build.VERSION.SDK_INT.toString()
                            )
                            result.success(parts.joinToString("|"))
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
