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

    // CRF 16-18 at ultrafast produced ~10 Mbit/s files; the extra bits cost write
    // time, gallery-copy time and upload time without visible benefit at these
    // transformation strengths. These values roughly halve the output size.
    // Vertical output fills a phone screen, so artefacts read much more harshly
    // than on a 16:9 card. Shorts get a tighter CRF for the same preset.
    final bool isVertical = context.targetHeight > context.targetWidth;
    final int crf = context.quality == 'high'
        ? (isVertical ? 18 : 20) + _random.nextInt(2)
        : (context.quality == 'fast'
            ? (isVertical ? 23 : 25)
            : (isVertical ? 20 : 22) + _random.nextInt(2));
    final int gop = 60 + _random.nextInt(61); // 60 to 120
    // B-frames are the most expensive part of the ultrafast preset's search;
    // pinning to 2 keeps compression while cutting encode time.
    const int bframes = 2;
    const String preset = "ultrafast";

    // Hardware path: mediacodec has no CRF, so it is driven by bitrate. If the
    // device rejects it, the engine's resilient fallback re-encodes with x264.
    if (context.preferHardwareEncoder) {
      final List<String> hwArgs = [
        "-c:v",
        "h264_mediacodec",
        "-b:v",
        "${context.hardwareBitrateKbps}k",
        "-pix_fmt",
        "yuv420p",
        "-g",
        gop.toString(),
        "-movflags",
        "+faststart",
        "-map_metadata",
        "-1",
        "-metadata",
        "encoder=$encoder",
        "-metadata",
        "creation_time=$timeStamp",
      ];
      if (context.hasAudio) {
        hwArgs.addAll(["-c:a", "aac", "-b:a", "192k"]);
      }
      return FilterResult(
        extraArgs: hwArgs,
        logMessage:
            "Layer 9 applied: Hardware H.264 (mediacodec) at ${context.hardwareBitrateKbps}kbps, GOP $gop.",
      );
    }

    List<String> args = [
      "-c:v",
      "libx264",
      "-preset",
      preset,
      "-crf",
      crf.toString(),
      "-pix_fmt",
      "yuv420p",
      "-g",
      gop.toString(),
      "-bf",
      bframes.toString(),
      "-map_metadata",
      "-1",
      "-metadata",
      "encoder=$encoder",
      "-metadata",
      "creation_time=$timeStamp",
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
        if (context.hasAudio) ...["-c:a", "aac", "-b:a", "192k"],
      ],
      logMessage: "Layer 9 fallback: Default H.264 profile applied.",
      isFallback: true,
    );
  }
}
