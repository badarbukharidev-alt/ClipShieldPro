package com.clipshield.clipshield

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
import java.security.MessageDigest

/**
 * Hands a downloaded APK to Android's package installer.
 *
 * This app does not install anything itself and cannot: it asks the system
 * installer, which shows its own confirmation screen. What this class adds on
 * top is the check the system will not do for you.
 *
 * ## Why the signature check matters
 *
 * The APK link comes from the admin panel. Without verification, anyone who
 * compromised that panel could point every install at a different APK, and the
 * only thing standing between the user and running it would be a dialog saying
 * "ClipShield wants to install an app". Comparing the downloaded APK's signing
 * certificate against the running app's means a substituted package is rejected
 * before the user is ever asked.
 *
 * It is also what makes the install an *update* rather than a failure: Android
 * refuses to replace an installed app with one signed by a different key, so an
 * unsigned or differently-signed APK would fail at the end of a long download
 * with an unhelpful error. Better to say so up front.
 */
object ApkInstaller {

    /**
     * SHA-256 of the first signing certificate of an installed package, or null
     * if it cannot be read.
     */
    private fun installedSignature(context: Context): String? = try {
        val pm = context.packageManager
        val certificate: ByteArray? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            @Suppress("DEPRECATION")
            val info = pm.getPackageInfo(
                context.packageName,
                PackageManager.GET_SIGNING_CERTIFICATES
            )
            info.signingInfo?.apkContentsSigners?.firstOrNull()?.toByteArray()
        } else {
            @Suppress("DEPRECATION", "PackageManagerGetSignatures")
            val info = pm.getPackageInfo(context.packageName, PackageManager.GET_SIGNATURES)
            @Suppress("DEPRECATION")
            info.signatures?.firstOrNull()?.toByteArray()
        }

        certificate?.let { sha256(it) }
    } catch (e: Exception) {
        null
    }

    /** SHA-256 of the first signing certificate of an APK file on disk. */
    private fun apkSignature(context: Context, apkPath: String): String? = try {
        val pm = context.packageManager
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES
        }

        val info = pm.getPackageArchiveInfo(apkPath, flags)
        val certificate: ByteArray? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info?.signingInfo?.apkContentsSigners?.firstOrNull()?.toByteArray()
        } else {
            @Suppress("DEPRECATION")
            info?.signatures?.firstOrNull()?.toByteArray()
        }

        certificate?.let { sha256(it) }
    } catch (e: Exception) {
        null
    }

    private fun sha256(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes)
            .joinToString("") { "%02x".format(it) }

    /**
     * Checks a downloaded APK before it is offered to the installer.
     *
     * Returns "ok", or a reason code. Note that a *newer* version is not checked
     * here -- UpdateService already did that against the panel's version code,
     * and the APK's own manifest is the authority the installer uses anyway.
     */
    fun verify(context: Context, apkPath: String): String {
        val file = File(apkPath)
        if (!file.exists() || file.length() == 0L) return "missing_file"

        val pm = context.packageManager
        val info = pm.getPackageArchiveInfo(apkPath, 0) ?: return "not_an_apk"

        // A package name mismatch means this is a different app entirely, not an
        // update -- the install would either fail or, worse, succeed as a second
        // app pretending to be this one.
        if (info.packageName != context.packageName) return "wrong_package"

        val ours = installedSignature(context) ?: return "signature_unreadable"
        val theirs = apkSignature(context, apkPath) ?: return "signature_unreadable"

        return if (ours == theirs) "ok" else "signature_mismatch"
    }

    /**
     * Whether this app may ask to install packages.
     *
     * From Android 8 this is a per-app setting the user grants in system
     * Settings; it is not a runtime permission and cannot be requested with a
     * dialog.
     */
    fun canRequestInstalls(context: Context): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.packageManager.canRequestPackageInstalls()
        } else {
            true
        }

    /** Opens the system screen where that permission is granted. */
    fun openInstallPermissionSettings(context: Context): Boolean = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:${context.packageName}")
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            true
        } else {
            false
        }
    } catch (e: Exception) {
        false
    }

    /**
     * Verifies, then hands the APK to the system installer. Returns "ok" when
     * the installer was launched -- not when the install completed, which is the
     * user's decision on a screen we do not control.
     */
    fun install(context: Context, apkPath: String): String {
        val verdict = verify(context, apkPath)
        if (verdict != "ok") return verdict

        if (!canRequestInstalls(context)) return "needs_permission"

        val uri: Uri = try {
            FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                File(apkPath)
            )
        } catch (e: Exception) {
            return "provider_error"
        }

        return try {
            context.startActivity(
                Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
            "ok"
        } catch (e: Exception) {
            "launch_failed"
        }
    }
}
