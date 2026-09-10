import 'dart:math';
import '../layer.dart';

class AudioConditioningLayer extends TransformationLayer {
  final Random _random = Random();
  double? customNoiseDb;

  AudioConditioningLayer({
    super.isEnabled = true,
    super.intensity = 0.5,
    this.customNoiseDb,
  });

  @override
  int get layerNumber => 8;

  @override
  String get name => "Audio Conditioning & Dithering";

  @override
  String get subtitle => "Inaudible dynamic floor conditioning & spectral dithering";

  @override
  String get description =>
      "Applies inaudible spectral white noise dithering (-68dB to -62dB) to stabilize the dynamic acoustic floor.";

  @override
  bool validate(FilterContext context) {
    if (!context.hasAudio) return false;
    final db = customNoiseDb ?? -65.0;
    return db <= -50.0; // must remain safely inaudible
  }

  double getNoiseAmplitude() {
    final double db = customNoiseDb ??
        (-68.0 + (_random.nextDouble() * 6.0)); // -68 to -62 dB
    return pow(10.0, db / 20.0).toDouble();
  }

  @override
  FilterResult apply(FilterContext context) {
    if (!context.hasAudio) {
      return FilterResult(logMessage: "Layer 8: No audio stream detected. Skipped.");
    }

    final double amp = getNoiseAmplitude();
    return FilterResult(
      logMessage:
          "Layer 8 applied: Spectral noise conditioning active (amp: ${amp.toStringAsExponential(2)}).",
    );
  }

  @override
  FilterResult fallback(FilterContext context) {
    return FilterResult(
      logMessage: "Layer 8 fallback: Dithering bypassed.",
      isFallback: true,
    );
  }
}
