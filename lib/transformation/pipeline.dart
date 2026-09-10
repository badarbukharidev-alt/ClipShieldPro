import '../models/app_modes.dart';
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
      "-ss",
      start.toStringAsFixed(3),
      "-to",
      end.toStringAsFixed(3),
      "-i",
      inputPath,
    ];

    final vfString = vfList.join(',');
    final bool useAudioConditioning =
        audioConditioning.isEnabled && context.hasAudio;

    if (context.hasAudio) {
      final afString = afList.isNotEmpty
          ? "aformat=sample_rates=44100:channel_layouts=stereo,${afList.join(',')}"
          : "aformat=sample_rates=44100:channel_layouts=stereo";

      if (useAudioConditioning) {
        final double noiseAmp = audioConditioning.getNoiseAmplitude();
        final filterComplex =
            "[0:v]$vfString[vout];"
            "[0:a]$afString[aprocessed];"
            "anoisesrc=d=${(clipDuration + 5.0).toInt()}:c=white:a=${noiseAmp.toStringAsFixed(10)},aformat=sample_rates=44100:channel_layouts=stereo[n];"
            "[aprocessed][n]amix=inputs=2:duration=first:weights=1 1[aout]";

        args.addAll([
          "-filter_complex",
          filterComplex,
          "-map",
          "[vout]",
          "-map",
          "[aout]",
        ]);
      } else {
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
      }
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
