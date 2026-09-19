package com.clipshield.clipshield

import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "com.clipshield/device"
    private val mediaChannelName = "com.clipshield/media"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            val message = throwable.message ?: ""
            val stack = android.util.Log.getStackTraceString(throwable)
            if (stack.contains("flutter_foreground_task") ||
                throwable is android.app.ForegroundServiceStartNotAllowedException ||
                message.contains("ForegroundService") ||
                message.contains("MissingForegroundServiceTypeException") ||
                message.contains("Bad notification for startForeground")
            ) {
                android.util.Log.w("MainActivity", "Safely absorbed foreground task exception to protect app stability", throwable)
            } else {
                defaultHandler?.uncaughtException(thread, throwable)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        registerMediaChannel(flutterEngine)

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

                    // What this phone can cope with, so the render pipeline
                    // can size itself to the device rather than to whatever the
                    // developer happened to be holding.
                    "getCapabilities" -> {
                        try {
                            result.success(DeviceCapability.describe(applicationContext))
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Saving to the gallery and sharing to a named app. Both have to be native:
     * scoped storage only lets an app publish media through MediaStore, and
     * targeting one app means building an explicit Intent rather than opening a
     * chooser.
     */
    private fun registerMediaChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaChannelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "saveVideo" -> result.success(
                            MediaStoreBridge.saveVideo(
                                applicationContext,
                                call.argument<String>("path") ?: "",
                                call.argument<String>("name") ?: "",
                                call.argument<String>("mimeType") ?: "video/mp4"
                            )
                        )

                        "saveImage" -> result.success(
                            MediaStoreBridge.saveImage(
                                applicationContext,
                                call.argument<String>("path") ?: "",
                                call.argument<String>("name") ?: "",
                                call.argument<String>("mimeType") ?: "image/jpeg"
                            )
                        )

                        "saveAudio" -> result.success(
                            MediaStoreBridge.saveAudio(
                                applicationContext,
                                call.argument<String>("path") ?: "",
                                call.argument<String>("name") ?: "",
                                call.argument<String>("mimeType") ?: "audio/mpeg"
                            )
                        )

                        "isInstalled" -> result.success(
                            MediaStoreBridge.isPackageInstalled(
                                applicationContext,
                                call.argument<String>("package") ?: ""
                            )
                        )

                        "shareTo" -> result.success(
                            MediaStoreBridge.shareToPackage(
                                this,
                                call.argument<String>("path") ?: "",
                                call.argument<String>("mimeType") ?: "video/mp4",
                                call.argument<String>("text"),
                                call.argument<String>("package")
                            )
                        )

                        // Updating in place. The app never installs anything
                        // itself; it verifies the download and hands it to the
                        // system installer, which asks the user on its own
                        // screen.
                        "verifyApk" -> result.success(
                            ApkInstaller.verify(
                                applicationContext,
                                call.argument<String>("path") ?: ""
                            )
                        )

                        "installApk" -> result.success(
                            ApkInstaller.install(this, call.argument<String>("path") ?: "")
                        )

                        "canInstallPackages" -> result.success(
                            ApkInstaller.canRequestInstalls(applicationContext)
                        )

                        "openInstallSettings" -> result.success(
                            ApkInstaller.openInstallPermissionSettings(this)
                        )

                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    // A failed save or share must never take the app down; the
                    // Dart side falls back to the system chooser.
                    result.success(null)
                }
            }
    }
}
