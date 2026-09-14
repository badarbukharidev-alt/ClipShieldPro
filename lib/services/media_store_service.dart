import 'dart:io';

import 'package:flutter/services.dart';

/// Thin Dart side of the `com.clipshield/media` channel.
///
/// Everything here has to be native. From Android 10 an app cannot publish a
/// file to the gallery by writing it into /storage/emulated/0/Movies — scoped
/// storage blocks the write outright on API 30+ — and targeting a share at one
/// specific app means building an explicit Intent, which Flutter's share plugin
/// deliberately does not do.
class MediaStoreService {
  MediaStoreService._();
  static final MediaStoreService instance = MediaStoreService._();

  static const MethodChannel _channel = MethodChannel('com.clipshield/media');

  /// True on platforms where the channel exists at all. Keeps callers from
  /// awaiting a round trip that can only fail on desktop or in tests.
  bool get isSupported => Platform.isAndroid;

  Future<String?> _invoke(String method, Map<String, dynamic> args) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<String>(method, args);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Publishes a video to Movies/ClipShield. Returns the MediaStore URI (or the
  /// file path on API 28 and below), or null if it could not be saved.
  Future<String?> saveVideo(String path, String fileName,
          {String mimeType = 'video/mp4'}) =>
      _invoke('saveVideo', {'path': path, 'name': fileName, 'mimeType': mimeType});

  /// Publishes an image to Pictures/ClipShield.
  Future<String?> saveImage(String path, String fileName,
          {String mimeType = 'image/jpeg'}) =>
      _invoke('saveImage', {'path': path, 'name': fileName, 'mimeType': mimeType});

  /// Publishes an audio file to Music/ClipShield.
  Future<String?> saveAudio(String path, String fileName,
          {String mimeType = 'audio/mpeg'}) =>
      _invoke('saveAudio', {'path': path, 'name': fileName, 'mimeType': mimeType});

  /// Whether a given app is on the device. Only answers truthfully for packages
  /// declared in the manifest's `<queries>` block — Android 11 hides the rest.
  Future<bool> isInstalled(String packageName) async {
    if (!isSupported) return false;
    try {
      final result =
          await _channel.invokeMethod<bool>('isInstalled', {'package': packageName});
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Sends a file to one named app. A null [packageName] opens the system
  /// chooser instead.
  ///
  /// Returns false when the target cannot take it — not installed, or it does
  /// not accept this type — so the caller can name the app rather than opening
  /// a chooser the user did not ask for.
  Future<bool> shareTo({
    required String path,
    required String mimeType,
    String? text,
    String? packageName,
  }) async {
    if (!isSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('shareTo', {
        'path': path,
        'mimeType': mimeType,
        'text': text,
        'package': packageName,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
