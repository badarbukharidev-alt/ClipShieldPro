import 'dart:math';
import '../layer.dart';

class HarmonicAudioLayer extends TransformationLayer {
  final Random _random = Random();
  double? customSemitones;

  HarmonicAudioLayer({
    super.isEnabled = true,
    super.intensity = 0.5,
    this.customSemitones,
  });

  @override
  int get layerNumber => 1;

  @override
  String get name => "Harmonic Audio Modulation";

  @override
  String get subtitle => "Controlled pitch modulation preserving speech tempo";

  @override
  String get description =>
      "Micro-shifts fundamental acoustic frequencies while compensating with atempo to keep speech natural.";

  @override
  bool validate(FilterContext context) {
    if (!context.hasAudio) return false;
    final semitones = customSemitones ?? ((intensity * 2.0) - 1.0) * 1.5;
    return semitones.abs() <= 4.0;
  }

  @override
  FilterResult apply(FilterContext context) {
    if (!context.hasAudio) {
      return FilterResult(logMessage: "Layer 1: No audio stream detected. Skipped.");
    }

    final double semitones = customSemitones ??
        ((_random.nextDouble() * 2.0 - 1.0) * (0.5 + intensity * 1.0)); // bounded +- 1.5
    final double factor = pow(2.0, semitones / 12.0).toDouble();

    final String rateFilter =
        "asetrate=r=44100*${factor.toStringAsFixed(5)},aformat=sample_rates=44100,atempo=${(1.0 / factor).toStringAsFixed(5)}";

    return FilterResult(
      audioFilters: [rateFilter],
      logMessage:
          "Layer 1 applied: Pitch shifted by ${semitones.toStringAsFixed(2)} semitones (rate factor: ${factor.toStringAsFixed(3)}).",
    );
  }

  @override
  FilterResult fallback(FilterContext context) {
    return FilterResult(
      audioFilters: ["aformat=sample_rates=44100"],
      logMessage: "Layer 1 fallback: Neutral audio resampling applied.",
      isFallback: true,
    );
  }
}
