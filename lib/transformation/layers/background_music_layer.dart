import 'dart:math';
import '../layer.dart';

class BackgroundMusicLayer extends TransformationLayer {
  final Random _random = Random();
  double? customVolumeDb;

  BackgroundMusicLayer({super.isEnabled = true, super.intensity = 0.5, this.customVolumeDb});

  @override int get layerNumber => 11;
  @override String get name => "Background Ambient Layer";
  @override String get subtitle => "Ultra-low volume ambient tone for audio signature shift";
  @override String get description => "Generates a subtle ambient background tone at -35dB to -28dB to shift audio fingerprint without being perceptible.";

  @override
  bool validate(FilterContext context) {
    if (!context.hasAudio) return false;
    final db = customVolumeDb ?? -32.0;
    return db <= -20.0;
  }

  int getAmbientFrequency() => 200 + _random.nextInt(600);

  double getAmbientAmplitude() {
    final double db = customVolumeDb ?? (-35.0 + (intensity * 7.0));
    return pow(10.0, db / 20.0).toDouble();
  }

  @override
  FilterResult apply(FilterContext context) {
    if (!context.hasAudio) {
      return FilterResult(logMessage: "Layer 11: No audio stream. Skipped.");
    }
    final int freq = getAmbientFrequency();
    final double db = customVolumeDb ?? (-35.0 + (intensity * 7.0));
    final double amp = getAmbientAmplitude();

    return FilterResult(
      logMessage: "Layer 11 applied: Ambient tone ${freq}Hz at ${db.toStringAsFixed(1)}dB (amp: ${amp.toStringAsExponential(2)}).",
    );
  }

  @override
  FilterResult fallback(FilterContext context) {
    return FilterResult(
      logMessage: "Layer 11 fallback: Ambient layer bypassed.",
      isFallback: true,
    );
  }
}
