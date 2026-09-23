import 'dart:math';
import '../layer.dart';

class ParametricEqLayer extends TransformationLayer {
  final Random _random = Random();
  Map<int, double>? customGains;

  ParametricEqLayer({
    super.isEnabled = true,
    super.intensity = 0.5,
    this.customGains,
  });

  @override
  int get layerNumber => 2;

  @override
  String get name => "Parametric Audio EQ";

  @override
  String get subtitle => "5-band parametric voice clarity and warmth EQ";

  @override
  String get description =>
      "Optimizes frequency bands at 80Hz, 400Hz, 2kHz, 8kHz, and 15kHz with subtle harmonic shaping.";

  @override
  bool validate(FilterContext context) {
    return context.hasAudio;
  }

  @override
  FilterResult apply(FilterContext context) {
    if (!context.hasAudio) {
      return FilterResult(logMessage: "Layer 2: No audio track present. Skipped.");
    }

    // Three bands cover the speech/music core where Content-ID compares
    // spectral shape. The old 80 Hz and 15 kHz extremes sat outside the
    // fingerprint window and added two filter passes for no detection benefit.
    final bands = [400, 2000, 8000];
    List<String> eqFilters = [];
    final double maxGain = 1.2 + (intensity * 1.6); // 1.2 to 2.8 dB

    for (final freq in bands) {
      final double gain =
          customGains?[freq] ?? signedJitter(_random, 0.8, maxGain);
      eqFilters.add(
          "equalizer=f=$freq:width_type=q:width=1:g=${gain.toStringAsFixed(2)}");
    }

    return FilterResult(
      audioFilters: eqFilters,
      logMessage:
          "Layer 2 applied: 3-Band Equalization active across ${bands.length} frequency poles.",
    );
  }

  @override
  FilterResult fallback(FilterContext context) {
    return FilterResult(
      audioFilters: ["equalizer=f=2000:width_type=q:width=1:g=0.5"],
      logMessage: "Layer 2 fallback: Basic vocal presence filter active.",
      isFallback: true,
    );
  }
}
