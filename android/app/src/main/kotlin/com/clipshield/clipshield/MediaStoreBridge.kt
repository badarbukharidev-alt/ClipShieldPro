package com.clipshield.clipshield

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileInputStream

/**
 * Publishes finished files to the device's shared media collections, and shares
 * them to a named app.
 *
 * Why this exists: from Android 10 onward an app cannot simply write a file into
 * /storage/emulated/0/Movies and expect it to appear. Scoped storage blocks the
 * write outright on API 30+, and the old
 * MEDIA_SCANNER_SCAN_FILE broadcast has been unavailable to apps for years, so
 * the Dart-side copy was landing in app-private storage where nothing but the
 * app itself could see it. Inserting through MediaStore is the supported route,
 * and it is what makes the file visible in Gallery, Photos and Files.
 */
object MediaStoreBridge {

    private const val FOLDER = "ClipShield"

    /**
     * Copies [sourcePath] into the shared video collection under Movies/ClipShield.
     * Returns the content:// URI as a string, or null if it could not be saved.
     */
    fun saveVideo(context: Context, sourcePath: String, fileName: String, mimeType: String): String? =
        save(
            context,
            sourcePath,
            fileName,
            mimeType,
            MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
            Environment.DIRECTORY_MOVIES
        )

    /** Copies [sourcePath] into the shared image collection under Pictures/ClipShield. */
    fun saveImage(context: Context, sourcePath: String, fileName: String, mimeType: String): String? =
        save(
            context,
            sourcePath,
            fileName,
            mimeType,
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
            Environment.DIRECTORY_PICTURES
        )

    /** Copies [sourcePath] into the shared audio collection under Music/ClipShield. */
    fun saveAudio(context: Context, sourcePath: String, fileName: String, mimeType: String): String? =
        save(
            context,
            sourcePath,
            fileName,
            mimeType,
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
            Environment.DIRECTORY_MUSIC
        )

    private fun save(
        context: Context,
        sourcePath: String,
        fileName: String,
        mimeType: String,
        collection: Uri,
        legacyDirectory: String
    ): String? {
        val source = File(sourcePath)
        if (!source.exists() || source.length() == 0L) return null

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            insertViaMediaStore(context, source, fileName, mimeType, collection, legacyDirectory)
        } else {
            writeLegacyFile(context, source, fileName, legacyDirectory)
        }
    }

    /**
     * API 29+. IS_PENDING keeps the row hidden from other apps until the bytes
     * are fully written, so a gallery never shows a half-copied video.
     */
    private fun insertViaMediaStore(
        context: Context,
        source: File,
        fileName: String,
        mimeType: String,
        collection: Uri,
        legacyDirectory: String
    ): String? {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, "$legacyDirectory/$FOLDER")
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val uri = resolver.insert(collection, values) ?: return null

        try {
            resolver.openOutputStream(uri)?.use { out ->
                FileInputStream(source).use { input ->
                    input.copyTo(out, DEFAULT_BUFFER_SIZE)
                }
            } ?: run {
                resolver.delete(uri, null, null)
                return null
            }
        } catch (e: Exception) {
            // A partially written row is worse than none: it shows up as a
            // corrupt item the user has to delete by hand.
            resolver.delete(uri, null, null)
            return null
        }

        values.clear()
        values.put(MediaStore.MediaColumns.IS_PENDING, 0)
        resolver.update(uri, values, null, null)

        return uri.toString()
    }

    /**
     * API 24-28, where a direct write still works. MediaScannerConnection is the
     * supported way to index it -- the `am broadcast` trick has not been
     * available to apps for a long time.
     */
    private fun writeLegacyFile(
        context: Context,
        source: File,
        fileName: String,
        legacyDirectory: String
    ): String? {
        return try {
            val dir = File(Environment.getExternalStoragePublicDirectory(legacyDirectory), FOLDER)
            if (!dir.exists() && !dir.mkdirs()) return null

            val target = File(dir, fileName)
            source.copyTo(target, overwrite = true)

            MediaScannerConnection.scanFile(context, arrayOf(target.absolutePath), null, null)
            target.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    // -----------------------------------------------------------------------
    // Sharing
    // -----------------------------------------------------------------------

    fun isPackageInstalled(context: Context, packageName: String): Boolean {
        return try {
            context.packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Sends [filePath] to a specific app.
     *
     * Returns "ok", or a reason code the Dart side turns into a message. A bare
     * boolean was a mistake: every distinct failure -- missing file, unresolvable
     * provider path, app not installed, app refuses the type -- arrived as the
     * same "false", and the one that actually happened (a FileProvider root that
     * did not cover app_flutter/) took a source dig to find rather than a glance
     * at a message.
     *
     * The file is handed over as a FileProvider content:// URI: a file:// URI
     * has thrown FileUriExposedException since Android 7, and the receiving app
     * could not read our private directory anyway.
     */
    fun shareToPackage(
        context: Context,
        filePath: String,
        mimeType: String,
        text: String?,
        packageName: String?
    ): String {
        val file = File(filePath)
        if (!file.exists()) return "missing_file"

        val uri: Uri = try {
            FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        } catch (e: IllegalArgumentException) {
            // "Failed to find configured root" -- a path outside file_paths.xml.
            return "provider_path"
        } catch (e: Exception) {
            return "provider_error"
        }

        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            if (!text.isNullOrEmpty()) putExtra(Intent.EXTRA_TEXT, text)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (!packageName.isNullOrEmpty()) setPackage(packageName)
        }

        if (intent.resolveActivity(context.packageManager) == null) {
            return if (packageName.isNullOrEmpty()) "no_handler" else "type_refused"
        }

        return try {
            if (packageName.isNullOrEmpty()) {
                context.startActivity(Intent.createChooser(intent, "Share").apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                })
            } else {
                context.startActivity(intent)
            }
            "ok"
        } catch (e: Exception) {
            "launch_failed"
        }
    }
}
