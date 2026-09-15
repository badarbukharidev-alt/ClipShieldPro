import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:clipshield/services/gallery_export_service.dart';

/// Thumbnail downloads failed for a large share of videos, and the cause was a
/// single missing fallback.
///
/// YouTube only generates `maxresdefault.jpg` for videos uploaded above 720p.
/// For everything else that URL **404s** — verified against a real video:
///
///   jNQXAC9IVRw/maxresdefault.jpg -> 404 (1097 bytes of error page)
///   jNQXAC9IVRw/hqdefault.jpg     -> 200 (15921 bytes)
///
/// The old code asked for that one URL through a Dio client whose default
/// `validateStatus` throws on a 404, caught the exception, and reported
/// "thumbnail download failed" for a video whose thumbnail was sitting one rung
/// down.
void main() {
  group('candidates that cannot work are rejected without a request', () {
    test('an empty list', () async {
      expect(await GalleryExportService.downloadImage([], 'x.jpg'), isNull);
    });

    test('a list of blanks', () async {
      expect(
        await GalleryExportService.downloadImage(['', '   ', ''], 'x.jpg'),
        isNull,
      );
    });
  });

  test('every candidate failing returns null rather than throwing', () async {
    // Unroutable host: the point is that it returns cleanly instead of letting
    // a DioException escape into the UI.
    final saved = await GalleryExportService.downloadImage(
      [
        'https://invalid.invalid/maxresdefault.jpg',
        'https://invalid.invalid/hqdefault.jpg',
      ],
      'thumb.jpg',
    );

    expect(saved, isNull);
  });

  test('a 404 moves on to the next candidate instead of ending the attempt',
      () async {
    // The first URL is the real 404 case this bug was about; the second is a
    // real thumbnail on the same video. Skipped offline, since the assertion is
    // about network behaviour rather than logic.
    const dead = 'https://i.ytimg.com/vi/jNQXAC9IVRw/maxresdefault.jpg';
    const alive = 'https://i.ytimg.com/vi/jNQXAC9IVRw/hqdefault.jpg';

    if (!await _online()) return;

    final bytes = await GalleryExportService.fetchImageBytes([dead, alive]);

    expect(bytes, isNotNull,
        reason: 'a 404 on maxresdefault must not abandon the download');
    expect(bytes!.length, greaterThan(2048));

    // JPEG magic number, so a fetched error page cannot pass as an image.
    expect(bytes[0], 0xFF);
    expect(bytes[1], 0xD8);
  }, tags: ['network']);

  test('the 404 body is small enough to be rejected on its own', () async {
    if (!await _online()) return;

    // Verified: that URL answers 404 with about 1 KB of error page. Even if a
    // future client stopped treating 404 as a failure, the size floor catches
    // it rather than saving an error page as someone's thumbnail.
    final bytes = await GalleryExportService.fetchImageBytes(
        ['https://i.ytimg.com/vi/jNQXAC9IVRw/maxresdefault.jpg']);

    expect(bytes, isNull);
  }, tags: ['network']);

  test('displayLocation describes an image save as Pictures', () {
    expect(
      GalleryExportService.displayLocation(
          'content://media/external_primary/images/media/42'),
      'Pictures/ClipShield',
    );
  });
}

/// Network assertions are skipped rather than failed when offline.
Future<bool> _online() async {
  try {
    final result = await InternetAddress.lookup('i.ytimg.com');
    return result.isNotEmpty;
  } catch (_) {
    return false;
  }
}
