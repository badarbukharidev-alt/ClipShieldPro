import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';

class MediaProbeInfo {
  final double duration;
  final int width;
  final int height;
  final bool hasAudio;
  final double fps;
  final String format;

  MediaProbeInfo({
    required this.duration,
    required this.width,
    required this.height,
    required this.hasAudio,
    this.fps = 30.0,
    this.format = "mp4",
  });

  bool get isLandscape => width > height;
  bool get isPortrait => height >= width;
  double get aspectRatio => width / (height > 0 ? height : 1);
}

class MediaProbeService {
  /// Probes video file to inspect duration, dimensions, frame rate, and audio stream existence.
  static Future<MediaProbeInfo> probe(String filePath) async {
    final session = await FFprobeKit.getMediaInformation(filePath);
    final info = session.getMediaInformation();

    if (info == null) {
      throw Exception("Failed to probe media file: $filePath");
    }

    final duration = double.tryParse(info.getDuration() ?? "") ?? 0.0;
    int width = 0;
    int height = 0;
    bool hasAudio = false;
    double fps = 30.0;

    final streams = info.getStreams();
    for (var stream in streams) {
      final type = stream.getType();
      if (type == "video") {
        width = stream.getWidth() ?? width;
        height = stream.getHeight() ?? height;
        final rFrameRate = stream.getRealFrameRate();
        if (rFrameRate != null && rFrameRate.contains('/')) {
          final parts = rFrameRate.split('/');
          final num = double.tryParse(parts[0]) ?? 30.0;
          final den = double.tryParse(parts[1]) ?? 1.0;
          fps = den > 0 ? (num / den) : 30.0;
        }
      } else if (type == "audio") {
        hasAudio = true;
      }
    }

    return MediaProbeInfo(
      duration: duration,
      width: width > 0 ? width : 1280,
      height: height > 0 ? height : 720,
      hasAudio: hasAudio,
      fps: fps,
      format: info.getFormat() ?? "mp4",
    );
  }
}
