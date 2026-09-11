import 'dart:io';

class GalleryExportService {
  static Future<String?> exportToPublicGallery(String sourceFilePath, {String? customFileName}) async {
    try {
      if (!Platform.isAndroid) {
        // Fallback for non-Android platforms, just return source for now
        return sourceFilePath;
      }

      final fileName = customFileName ?? sourceFilePath.split(Platform.pathSeparator).last;
      
      final moviesDir = Directory('/storage/emulated/0/Movies/ClipShield');
      final dcimDir = Directory('/storage/emulated/0/DCIM/ClipShield');
      
      Directory targetDir = moviesDir;
      
      if (!moviesDir.existsSync()) {
        try {
          moviesDir.createSync(recursive: true);
        } catch (e) {
          targetDir = dcimDir;
          if (!dcimDir.existsSync()) {
            dcimDir.createSync(recursive: true);
          }
        }
      }

      final targetPath = '${targetDir.path}${Platform.pathSeparator}$fileName';
      
      final sourceFile = File(sourceFilePath);
      if (!sourceFile.existsSync()) {
        return null;
      }

      await sourceFile.copy(targetPath);

      // Trigger MediaScanner
      try {
        await Process.run('am', [
          'broadcast',
          '-a',
          'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
          '-d',
          'file://$targetPath'
        ]);
      } catch (e) {
        // Ignore scanner failure, media store might still index it
      }

      return targetPath;
    } catch (e) {
      // Gracefully return original source on failure (e.g. permission restriction)
      return sourceFilePath;
    }
  }
}
