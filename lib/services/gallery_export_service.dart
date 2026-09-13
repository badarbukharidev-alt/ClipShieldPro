import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Writes finished assets into public, user-visible ClipShield folders and asks
/// Android's MediaScanner to index them so they appear in Gallery / Files.
///
/// Everything the app produces lands under a `ClipShield` folder of the matching
/// public directory: videos in Movies, images in Pictures, text in Documents
/// (falling back to Download).
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

  static Future<void> _scan(String filePath) async {
    if (!Platform.isAndroid) return;
    try {
      await Process.run('am', [
        'broadcast',
        '-a',
        'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
        '-d',
        'file://$filePath',
      ]);
    } catch (_) {
      // MediaStore may still index it on its own schedule.
    }
  }

  static Future<String?> _copyInto(
    List<String> roots,
    String subfolder,
    String sourceFilePath, {
    String? customFileName,
  }) async {
    try {
      final sourceFile = File(sourceFilePath);
      if (!await sourceFile.exists()) return null;

      final fileName = customFileName ?? path.basename(sourceFilePath);
      final dir = await _resolveDir(roots) ?? await _fallbackDir(subfolder);
      final targetPath = path.join(dir.path, fileName);

      await sourceFile.copy(targetPath);
      await _scan(targetPath);
      return targetPath;
    } catch (_) {
      return null;
    }
  }

  /// Copies a rendered video into Movies/ClipShield.
  static Future<String?> exportToPublicGallery(
    String sourceFilePath, {
    String? customFileName,
  }) {
    return _copyInto(_movieRoots, 'Videos', sourceFilePath,
        customFileName: customFileName);
  }

  /// Copies an image into Pictures/ClipShield.
  static Future<String?> exportImageToGallery(
    String sourceFilePath, {
    String? customFileName,
  }) {
    return _copyInto(_pictureRoots, 'Images', sourceFilePath,
        customFileName: customFileName);
  }

  /// Writes text (description, keywords, transcript) into Documents/ClipShield.
  static Future<String?> saveTextFile(String contents, String fileName) async {
    try {
      final dir = await _resolveDir(_documentRoots) ?? await _fallbackDir('Text');
      final file = File(path.join(dir.path, fileName));
      await file.writeAsString(contents);
      await _scan(file.path);
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

      final dir = await _resolveDir(_pictureRoots) ?? await _fallbackDir('Images');
      final file = File(path.join(dir.path, fileName));
      await file.writeAsBytes(bytes);
      await _scan(file.path);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Human-readable location for the snackbar after a save.
  static String displayLocation(String savedPath) {
    final normalized = savedPath.replaceAll('\\', '/');
    const marker = '/storage/emulated/0/';
    if (normalized.startsWith(marker)) {
      return normalized.substring(marker.length);
    }
    return path.basename(savedPath);
  }
}
