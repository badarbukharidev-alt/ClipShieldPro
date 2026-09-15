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
 *
 * That last point cuts both ways, and it is why an *unreadable* certificate no
 * longer blocks the install. The package manager enforces signature matching
 * itself and cannot be talked out of it; this check exists to fail early and
 * legibly, not because it is the only thing standing in the way. Refusing what
 * we merely could not read stopped genuine updates with "the download could not
 * be verified". A signature that reads fine and does not match is still refused.
 */
object ApkInstaller {

    /**
     * Every signing certificate we can read out of a PackageInfo, as SHA-256
     * hashes.
     *
     * Deliberately tries more than one accessor. `getPackageArchiveInfo` with
     * GET_SIGNING_CERTIFICATES returns a null `signingInfo` on a good number of
     * devices -- archives have always been better served by the deprecated
     * GET_SIGNATURES -- and reading only the modern one is what made
     * verification fail on a perfectly genuine download.
     *
     * Returns an empty set when nothing could be read, which the caller treats
     * as "unknown" rather than "wrong".
     */
    private fun signaturesOf(info: android.content.pm.PackageInfo?): Set<String> {
        if (info == null) return emptySet()

        val out = mutableSetOf<String>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = info.signingInfo
            if (signingInfo != null) {
                // apkContentsSigners is the current key; the history covers a
                // package whose signing key has been rotated. Collecting both
                // means a rotation does not read as a mismatch.
                signingInfo.apkContentsSigners?.forEach { out.add(sha256(it.toByteArray())) }
                if (!signingInfo.hasMultipleSigners()) {
                    signingInfo.signingCertificateHistory?.forEach {
                        out.add(sha256(it.toByteArray()))
                    }
                }
            }
        }

        @Suppress("DEPRECATION")
        info.signatures?.forEach { out.add(sha256(it.toByteArray())) }

        return out
    }

    /** Signing certificates of the running app. */
    private fun installedSignatures(context: Context): Set<String> = try {
        val pm = context.packageManager
        val out = mutableSetOf<String>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            out += signaturesOf(
                pm.getPackageInfo(context.packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            )
        }

        @Suppress("DEPRECATION", "PackageManagerGetSignatures")
        val legacy = pm.getPackageInfo(context.packageName, PackageManager.GET_SIGNATURES)
        out += signaturesOf(legacy)

        out
    } catch (e: Exception) {
        emptySet()
    }

    /** Signing certificates of an APK file on disk. */
    private fun apkSignatures(context: Context, apkPath: String): Set<String> = try {
        val pm = context.packageManager
        val out = mutableSetOf<String>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            out += signaturesOf(
                pm.getPackageArchiveInfo(apkPath, PackageManager.GET_SIGNING_CERTIFICATES)
            )
        }

        // GET_SIGNATURES is deprecated but remains the accessor that actually
        // works for archives on most versions.
        @Suppress("DEPRECATION", "PackageManagerGetSignatures")
        val legacy = pm.getPackageArchiveInfo(apkPath, PackageManager.GET_SIGNATURES)
        out += signaturesOf(legacy)

        out
    } catch (e: Exception) {
        emptySet()
    }

    private fun sha256(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes)
            .joinToString("") { "%02x".format(it) }

    /**
     * Checks a downloaded APK before it is offered to the installer.
     *
     * Returns "ok", "ok_unverified", or a reason code.
     *
     * ## Why "unreadable" is not a refusal
     *
     * It used to be, and that was wrong: a download that could not be *read*
     * was blocked as though it had been caught being *wrong*, which stopped
     * genuine updates dead with "the download could not be verified".
     *
     * Android already refuses to replace an installed app with one signed by a
     * different key -- that is enforced by the package manager, not by us, and
     * it cannot be talked out of it. This check exists to fail *early and
     * legibly* rather than after a long download, and to catch a substituted
     * package before the user is asked to confirm anything. When the
     * certificate genuinely cannot be read, the right move is to let the
     * install proceed and let the OS enforce what it was always going to
     * enforce.
     *
     * A signature that reads fine and does not match is still refused outright.
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

        val ours = installedSignatures(context)
        val theirs = apkSignatures(context, apkPath)

        if (ours.isEmpty() || theirs.isEmpty()) return "ok_unverified"

        return if (ours.intersect(theirs).isNotEmpty()) "ok" else "signature_mismatch"
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
        if (verdict != "ok" && verdict != "ok_unverified") return verdict

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
