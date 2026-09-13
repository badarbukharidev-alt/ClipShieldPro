import '../models/app_modes.dart';
import 'ass_subtitle_builder.dart';
import 'layer.dart';
import 'layers/harmonic_audio_layer.dart';
import 'layers/parametric_eq_layer.dart';
import 'layers/spatial_audio_layer.dart';
import 'layers/geometry_layer.dart';
import 'layers/resampling_layer.dart';
import 'layers/color_layer.dart';
import 'layers/gamma_layer.dart';
import 'layers/audio_conditioning_layer.dart';
import 'layers/codec_normalization_layer.dart';
import 'layers/blur_layer.dart';
import 'layers/background_music_layer.dart';
import 'layers/reverb_layer.dart';

class TransformationPipeline {
  final HarmonicAudioLayer harmonicAudio = HarmonicAudioLayer();
  final ParametricEqLayer parametricEq = ParametricEqLayer();
  final SpatialAudioLayer spatialAudio = SpatialAudioLayer();
  final GeometryLayer geometry = GeometryLayer();
  final ResamplingLayer resampling = ResamplingLayer();
  final ColorLayer color = ColorLayer();
  final GammaLayer gamma = GammaLayer();
  final AudioConditioningLayer audioConditioning = AudioConditioningLayer();
  final CodecNormalizationLayer codecNormalization = CodecNormalizationLayer();
  final BlurLayer blur = BlurLayer();
  final BackgroundMusicLayer backgroundMusic = BackgroundMusicLayer();
  final ReverbLayer reverb = ReverbLayer();

  PipelinePreset _currentPreset = PipelinePreset.balanced;
  PipelinePreset get currentPreset => _currentPreset;

  double _globalIntensity = 0.5;
  double get globalIntensity => _globalIntensity;

  TransformationPipeline() {
    applyPreset(PipelinePreset.balanced);
  }

  List<TransformationLayer> get allLayers => [
        harmonicAudio,
        parametricEq,
        spatialAudio,
        geometry,
        resampling,
        color,
        gamma,
        audioConditioning,
        codecNormalization,
        blur,
        backgroundMusic,
        reverb,
      ];

  void applyPreset(PipelinePreset preset) {
    _currentPreset = preset;
    switch (preset) {
      case PipelinePreset.fast:
        _globalIntensity = 0.3;
        harmonicAudio.isEnabled = false;
        parametricEq.isEnabled = true;
        spatialAudio.isEnabled = false;
        geometry.isEnabled = true;
        resampling.isEnabled = true;
        color.isEnabled = true;
        gamma.isEnabled = false;
        audioConditioning.isEnabled = false;
        codecNormalization.isEnabled = true;
        blur.isEnabled = false;
        backgroundMusic.isEnabled = false;
        reverb.isEnabled = false;
        break;

      case PipelinePreset.balanced:
        _globalIntensity = 0.5;
        for (var layer in allLayers) {
          layer.isEnabled = true;
          layer.intensity = 0.5;
        }
        break;

      case PipelinePreset.advanced:
        _globalIntensity = 0.8;
        for (var layer in allLayers) {
          layer.isEnabled = true;
          layer.intensity = 0.8;
        }
        break;

      case PipelinePreset.custom:
        break;
    }
    setGlobalIntensity(_globalIntensity);
  }

  void setGlobalIntensity(double intensity) {
    _globalIntensity = intensity.clamp(0.0, 1.0);
    for (var layer in allLayers) {
      layer.intensity = _globalIntensity;
    }
  }

  bool validateAll(FilterContext context) {
    for (var layer in allLayers) {
      if (layer.isEnabled && !layer.validate(context)) {
        return false;
      }
    }
    return true;
  }

  /// Fuses consecutive `eq=` filter instances into one.
  ///
  /// The colour and gamma layers each emit their own `eq=`, which costs an extra
  /// full-frame pass per filter instance. Merging them is behaviourally
  /// identical (eq options are independent multipliers) and measurably faster on
  /// high-resolution sources.
  static List<String> fuseVideoFilters(List<String> filters) {
    final List<String> fused = [];
    final List<String> pendingEq = [];

    void flushEq() {
      if (pendingEq.isEmpty) return;
      final options = pendingEq
          .map((f) => f.substring(3)) // strip the leading "eq="
          .where((o) => o.isNotEmpty)
          .join(':');
      fused.add('eq=$options');
      pendingEq.clear();
    }

    for (final filter in filters) {
      if (filter.startsWith('eq=')) {
        pendingEq.add(filter);
      } else {
        flushEq();
        fused.add(filter);
      }
    }
    flushEq();
    return fused;
  }

  /// Builds a deliberately simple command that still performs a real
  /// transformation.
  ///
  /// This is the recovery path when the full filtergraph fails. It must never
  /// degrade into a plain re-encode: handing back a visually and audibly
  /// identical file labelled "protected" is worse than failing, because the user
  /// has no way to tell the difference. Every layer contributes its `fallback()`
  /// filters, which are conservative but never neutral.
  List<String> buildResilientArgs({
    required String inputPath,
    required String outputPath,
    required double start,
    required double end,
    required FilterContext context,
    required Function(String) logCallback,
  }) {
    final double clipDuration = end - start;

    List<String> vfList = [];
    List<String> afList = [];

    for (final layer in allLayers) {
      if (!layer.isEnabled) continue;
      try {
        final res = layer.fallback(context);
        vfList.addAll(res.videoFilters);
        afList.addAll(res.audioFilters);
      } catch (_) {
        // A layer that cannot even produce its fallback is simply skipped.
      }
    }

    vfList = fuseVideoFilters(vfList);

    // Captions are burned in after every other video filter, so the blur and
    // colour layers cannot soften or tint the text.
    final subs = context.subtitlePath;
    if (subs != null && subs.isNotEmpty) {
      vfList.add("subtitles='${AssSubtitleBuilder.escapeFilterPath(subs)}'");
      logCallback("Captions: burning in ${subs.split('/').last}");
    }

    if (vfList.isEmpty) {
      vfList = [
        "scale=${context.targetWidth}:${context.targetHeight}:flags=bicubic",
        "setsar=1",
        "hue=h=5:s=1.03",
        "eq=contrast=1.03:gamma=1.03",
      ];
    }

    final List<String> args = [
      "-y",
      "-threads",
      "0",
      if (start > 0.01) ...["-ss", start.toStringAsFixed(3)],
      if (clipDuration > 0.01) ...["-t", clipDuration.toStringAsFixed(3)],
      "-i",
      inputPath,
    ];

    final vfString = vfList.join(',');
    logCallback("Resilient video chain: $vfString");

    if (context.hasAudio && afList.isNotEmpty) {
      final afString =
          "aformat=sample_rates=44100:channel_layouts=stereo,${afList.join(',')}";
      logCallback("Resilient audio chain: $afString");
      args.addAll([
        "-filter_complex",
        "[0:v]$vfString[vout];[0:a]$afString[aout]",
        "-map",
        "[vout]",
        "-map",
        "[aout]",
      ]);
    } else {
      args.addAll([
        "-filter_complex",
        "[0:v]$vfString[vout]",
        "-map",
        "[vout]",
      ]);
    }

    args.addAll([
      "-c:v",
      "libx264",
      "-preset",
      "ultrafast",
      "-crf",
      "23",
      "-pix_fmt",
      "yuv420p",
      "-bf",
      "2",
      "-map_metadata",
      "-1",
      if (context.hasAudio) ...["-c:a", "aac", "-b:a", "192k"],
      outputPath,
    ]);

    return args;
  }

  /// Compiles the complete command arguments array for FFmpeg execution
  List<String> buildFfmpegArgs({
    required String inputPath,
    required String outputPath,
    required double start,
    required double end,
    required FilterContext context,
    required Function(String) logCallback,
  }) {
    final double clipDuration = end - start;

    List<String> vfList = [];
    List<String> afList = [];
    List<String> extraArgs = [];

    logCallback("--- Compiling Modular Transformation Pipeline ---");

    // Execute Layers 1-9 safely
    for (final layer in allLayers) {
      final res = layer.safeApply(context);
      if (res.videoFilters.isNotEmpty) {
        vfList.addAll(res.videoFilters);
      }
      if (res.audioFilters.isNotEmpty) {
        afList.addAll(res.audioFilters);
      }
      if (res.extraArgs.isNotEmpty) {
        extraArgs.addAll(res.extraArgs);
      }
      if (res.logMessage != null) {
        logCallback(res.logMessage!);
      }
    }

    List<String> args = [
      "-y",
      "-threads",
      "0",
    ];

    // Accurate seeking and duration limiting
    if (start > 0.01) {
      args.addAll(["-ss", start.toStringAsFixed(3)]);
    }
    if (clipDuration > 0.01) {
      args.addAll(["-t", clipDuration.toStringAsFixed(3)]);
    }

    args.addAll(["-i", inputPath]);

    vfList = fuseVideoFilters(vfList);
    if (vfList.isEmpty) {
      // An empty chain would compile to the invalid "[0:v][vout]" and, worse,
      // would mean nothing was transformed at all.
      vfList = ["scale=${context.targetWidth}:${context.targetHeight}:flags=bicubic", "setsar=1"];
      logCallback("No video layers produced filters; applied baseline resample.");
    }
    final vfString = vfList.join(',');
    logCallback("Video chain (${vfList.length} filters): $vfString");
    if (context.hasAudio) {
      logCallback("Audio chain (${afList.length} filters): ${afList.join(',')}");
    }

    if (context.hasAudio) {
      final afString = afList.isNotEmpty
          ? "aformat=sample_rates=44100:channel_layouts=stereo,${afList.join(',')}"
          : "aformat=sample_rates=44100:channel_layouts=stereo";

      final filterComplex =
          "[0:v]$vfString[vout];"
          "[0:a]$afString[aout]";

      args.addAll([
        "-filter_complex",
        filterComplex,
        "-map",
        "[vout]",
        "-map",
        "[aout]",
      ]);
    } else {
      args.addAll([
        "-filter_complex",
        "[0:v]$vfString[vout]",
        "-map",
        "[vout]",
      ]);
    }

    args.addAll(extraArgs);
    args.add(outputPath);

    return args;
  }
}
