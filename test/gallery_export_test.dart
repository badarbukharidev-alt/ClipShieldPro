import 'package:flutter_test/flutter_test.dart';

import 'package:clipshield/services/gallery_export_service.dart';

/// The gallery save used to fail silently on every phone running Android 10 or
/// newer: it wrote into /storage/emulated/0/Movies, which scoped storage
/// rejects, then broadcast MEDIA_SCANNER_SCAN_FILE, which apps have not been
/// allowed to send for years. Both failures were caught and swallowed, so a
/// render reported "saved" and appeared in no gallery.
///
/// The save itself now happens in Kotlin through MediaStore and cannot be
/// exercised here. What is testable is the reporting: a content:// URI has to
/// be turned into somewhere a person can actually look.
void main() {
  group('telling the user where a file went', () {
    test('a video URI reports the Movies folder', () {
      expect(
        GalleryExportService.displayLocation(
            'content://media/external_primary/video/media/1234'),
        'Movies/ClipShield',
      );
    });

    test('an image URI reports the Pictures folder', () {
      expect(
        GalleryExportService.displayLocation(
            'content://media/external_primary/images/media/99'),
        'Pictures/ClipShield',
      );
    });

    test('an audio URI reports the Music folder', () {
      expect(
        GalleryExportService.displayLocation(
            'content://media/external_primary/audio/media/7'),
        'Music/ClipShield',
      );
    });

    test('an unrecognised URI still names the folder, never the raw URI', () {
      final shown = GalleryExportService.displayLocation(
          'content://media/external_primary/downloads/1');

      expect(shown, 'ClipShield');
      expect(shown, isNot(contains('content://')),
          reason: 'a content URI means nothing to a user');
    });

    test('a legacy file path is shown relative to internal storage', () {
      expect(
        GalleryExportService.displayLocation(
            '/storage/emulated/0/Movies/ClipShield/clip.mp4'),
        'Movies/ClipShield/clip.mp4',
      );
    });

    test('a path outside internal storage falls back to the file name', () {
      expect(
        GalleryExportService.displayLocation('/data/user/0/app/files/clip.mp4'),
        'clip.mp4',
      );
    });
  });
}
