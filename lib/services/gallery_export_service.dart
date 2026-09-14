import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'media_store_service.dart';

/// Publishes finished assets so they are visible in Gallery, Photos and Files.
///
/// Everything lands under a `ClipShield` folder of the matching collection:
/// videos in Movies, images in Pictures, text in Documents.
///
/// Media goes through MediaStore rather than a file copy. The previous version
/// wrote straight into /storage/emulated/0/Movies and broadcast
/// MEDIA_SCANNER_SCAN_FILE, and on any phone running Android 10 or newer
/// **neither step worked**: scoped storage rejects the write on API 30+, and
/// that broadcast has not been available to apps for years. The failure was
/// silent -- the copy fell back to app-private storage, so a render "saved"
/// successfully and then appeared in no gallery on earth.
///
/// Plain text still uses a file write, because Documents is not a media
/// collection and a .txt file has nothing to index.
class GalleryExportService {
  static const String _folderName = 'ClipShield';

  static const List<String> _movieRoots = [
    '/storage/emulated/0/Movies',
    '/storage/emulated/0/DCIM',
  ];
  static const List<String> _pictureRoots = [
    '/storage/emulated/0/Pictures',
    '/storage/emulated/0/DCIM',
  ];
  static const List<String> _documentRoots = [
    '/storage/emulated/0/Documents',
    '/storage/emulated/0/Download',
  ];

  /// Resolves the first writable `<root>/ClipShield` directory, creating it if
  /// needed. Returns null when none of the candidates can be written to.
  static Future<Directory?> _resolveDir(List<String> roots) async {
    for (final root in roots) {
      try {
        final dir = Directory(path.join(root, _folderName));
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Private app-storage fallback, so a save never silently produces nothing.
  static Future<Directory> _fallbackDir(String subfolder) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(base.path, '${_folderName}_$subfolder'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Last-resort copy for platforms with no MediaStore, so a save never
  /// silently produces nothing. Not visible in a gallery, and does not pretend
  /// to be.
  static Future<String?> _copyIntoFallback(
    List<String> roots,
    String subfolder,
    String sourceFilePath,
    String fileName,
  ) async {
    try {
      final sourceFile = File(sourceFilePath);
      if (!await sourceFile.exists()) return null;

      final dir = await _resolveDir(roots) ?? await _fallbackDir(subfolder);
      final targetPath = path.join(dir.path, fileName);
      await sourceFile.copy(targetPath);
      return targetPath;
    } catch (_) {
      return null;
    }
  }

  /// Publishes a rendered video to Movies/ClipShield.
  static Future<String?> exportToPublicGallery(
    String sourceFilePath, {
    String? customFileName,
  }) async {
    final fileName = customFileName ?? path.basename(sourceFilePath);
    final saved = await MediaStoreService.instance
        .saveVideo(sourceFilePath, fileName, mimeType: _videoMime(fileName));
    if (saved != null) return saved;

    return _copyIntoFallback(_movieRoots, 'Videos', sourceFilePath, fileName);
  }

  /// Publishes an image to Pictures/ClipShield.
  static Future<String?> exportImageToGallery(
    String sourceFilePath, {
    String? customFileName,
  }) async {
    final fileName = customFileName ?? path.basename(sourceFilePath);
    final saved = await MediaStoreService.instance
        .saveImage(sourceFilePath, fileName, mimeType: _imageMime(fileName));
    if (saved != null) return saved;

    return _copyIntoFallback(_pictureRoots, 'Images', sourceFilePath, fileName);
  }

  /// Publishes an audio file to Music/ClipShield.
  static Future<String?> exportAudioToGallery(
    String sourceFilePath, {
    String? customFileName,
  }) async {
    final fileName = customFileName ?? path.basename(sourceFilePath);
    final saved = await MediaStoreService.instance
        .saveAudio(sourceFilePath, fileName, mimeType: _audioMime(fileName));
    if (saved != null) return saved;

    return _copyIntoFallback(_documentRoots, 'Audio', sourceFilePath, fileName);
  }

  static String _videoMime(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    if (ext == '.mkv') return 'video/x-matroska';
    if (ext == '.webm') return 'video/webm';
    if (ext == '.mov') return 'video/quicktime';
    return 'video/mp4';
  }

  static String _imageMime(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    if (ext == '.png') return 'image/png';
    if (ext == '.webp') return 'image/webp';
    return 'image/jpeg';
  }

  static String _audioMime(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    if (ext == '.m4a' || ext == '.aac') return 'audio/mp4';
    if (ext == '.wav') return 'audio/wav';
    if (ext == '.opus' || ext == '.ogg') return 'audio/ogg';
    return 'audio/mpeg';
  }

  /// Writes text (description, keywords, transcript) into Documents/ClipShield.
  static Future<String?> saveTextFile(String contents, String fileName) async {
    try {
      final dir = await _resolveDir(_documentRoots) ?? await _fallbackDir('Text');
      final file = File(path.join(dir.path, fileName));
      await file.writeAsString(contents);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Downloads a remote image (a YouTube thumbnail) straight into
  /// Pictures/ClipShield.
  static Future<String?> downloadImage(String url, String fileName) async {
    if (url.isEmpty) return null;
    try {
      final response = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (response.statusCode != 200 || bytes == null || bytes.isEmpty) {
        return null;
      }

      // Staged in app-private storage first, then published through
      // MediaStore. Writing it straight into Pictures/ fails silently on
      // Android 10+, which is why downloaded thumbnails never appeared.
      final staging = await _fallbackDir('Staging');
      final staged = File(path.join(staging.path, fileName));
      await staged.writeAsBytes(bytes);

      final published =
          await exportImageToGallery(staged.path, customFileName: fileName);
      try {
        await staged.delete();
      } catch (_) {
        // A leftover staging copy is harmless.
      }

      return published;
    } catch (_) {
      return null;
    }
  }

  /// Human-readable location for the snackbar after a save.
  ///
  /// A MediaStore save returns a content:// URI, which says nothing useful to
  /// a user, so the folder it was filed under is reported instead.
  static String displayLocation(String savedPath) {
    if (savedPath.startsWith('content://')) {
      if (savedPath.contains('/video')) return 'Movies/$_folderName';
      if (savedPath.contains('/images')) return 'Pictures/$_folderName';
      if (savedPath.contains('/audio')) return 'Music/$_folderName';
      return _folderName;
    }

    final normalized = savedPath.replaceAll('\\', '/');
    const marker = '/storage/emulated/0/';
    if (normalized.startsWith(marker)) {
      return normalized.substring(marker.length);
    }
    return path.basename(savedPath);
  }
}
