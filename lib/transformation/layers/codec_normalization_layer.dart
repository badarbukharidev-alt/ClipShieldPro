import 'dart:math';
import '../layer.dart';

class CodecNormalizationLayer extends TransformationLayer {
  final Random _random = Random();
  String? customEncoderTag;

  CodecNormalizationLayer({
    super.isEnabled = true,
    super.intensity = 0.5,
    this.customEncoderTag,
  });

  @override
  int get layerNumber => 9;

  @override
  String get name => "Container & Codec Normalization";

  @override
  String get subtitle => "NLE bitstream profiling, metadata purge & FastStart";

  @override
  String get description =>
      "Purges legacy file metadata, normalizes GOP compression structures, and places MP4 FastStart headers.";

  @override
  bool validate(FilterContext context) {
    return true;
  }

  @override
  FilterResult apply(FilterContext context) {
    final encoders = [
      "Adobe Premiere Pro 2024 (v24.2)",
      "DaVinci Resolve Studio 19.0",
      "Final Cut Pro 10.7",
      "CapCut Desktop Pro v3.8",
      "Apple Compressor 4.7"
    ];
    final String encoder =
        customEncoderTag ?? encoders[_random.nextInt(encoders.length)];

    final int year = 2023 + _random.nextInt(3);
    final int month = 1 + _random.nextInt(12);
    final int day = 1 + _random.nextInt(28);
    final int hour = _random.nextInt(24);
    final int min = _random.nextInt(60);
    final int sec = _random.nextInt(60);
    final String timeStamp =
        "${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}T${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}Z";

    final int crf = context.quality == 'high'
        ? 16 + _random.nextInt(3)
        : (context.quality == 'fast' ? 22 : 18 + _random.nextInt(3));
    final int gop = 60 + _random.nextInt(61); // 60 to 120
    final int bframes = 2 + _random.nextInt(3); // 2 to 4
    final int refs = 3 + _random.nextInt(3); // 3 to 5
    const String preset = "ultrafast";

    List<String> args = [
      "-c:v",
      "libx264",
      "-preset",
      preset,
      "-threads",
      "0",
      "-crf",
      crf.toString(),
      "-pix_fmt",
      "yuv420p",
      "-x264-params",
      "keyint=$gop:min-keyint=${gop ~/ 2}:bframes=$bframes:ref=$refs",
      "-map_metadata",
      "-1",
      "-metadata",
      "encoder=$encoder",
      "-metadata",
      "creation_time=$timeStamp",
      "-movflags",
      "+faststart",
    ];

    if (context.hasAudio) {
      final audioBitrate = context.quality == 'high' ? "320k" : "192k";
      args.addAll(["-c:a", "aac", "-b:a", audioBitrate]);
    }

    return FilterResult(
      extraArgs: args,
      logMessage:
          "Layer 9 applied: Metadata purged. Container normalized with $encoder profile (CRF $crf, GOP $gop, preset $preset).",
    );
  }

  @override
  FilterResult fallback(FilterContext context) {
    return FilterResult(
      extraArgs: [
        "-c:v",
        "libx264",
        "-preset",
        "ultrafast",
        "-threads",
        "0",
        "-crf",
        "20",
        "-pix_fmt",
        "yuv420p",
        "-movflags",
        "+faststart",
        if (context.hasAudio) ...["-c:a", "aac", "-b:a", "192k"],
      ],
      logMessage: "Layer 9 fallback: Default H.264 profile applied.",
      isFallback: true,
    );
  }
}
