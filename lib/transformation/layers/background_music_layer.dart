import 'dart:math';
import '../layer.dart';

class BackgroundMusicLayer extends TransformationLayer {
  final Random _random = Random();
  double? customVolumeDb;

  BackgroundMusicLayer({super.isEnabled = true, super.intensity = 0.5, this.customVolumeDb});

  @override
  bool get isCore => false;

  @override int get layerNumber => 11;
  @override String get name => "Background Ambient Layer";
  @override String get subtitle => "In-line acoustic tone modulation for audio signature shift";
  @override String get description => "Applies subtle dynamic acoustic tone modulation and harmonic presence to shift audio fingerprint without perceptible distortion.";

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
    
    // In-line acoustic ambient warmth and stereo presence
    // Eliminates external sine synthesis and amix duration mismatches
    final double bassGain = 0.4 + (intensity * 0.4); // +0.4 to +0.8 dB subtle low-end presence
    final double trebleGain = -0.3 - (intensity * 0.3); // -0.3 to -0.6 dB gentle air damping

    return FilterResult(
      audioFilters: [
        "bass=g=${bassGain.toStringAsFixed(2)}:f=110:w=0.6",
        "treble=g=${trebleGain.toStringAsFixed(2)}:f=12000:w=0.6",
      ],
      logMessage: "Layer 11 applied: In-line acoustic tone modulation (bass: +${bassGain.toStringAsFixed(1)}dB, treble: ${trebleGain.toStringAsFixed(1)}dB).",
    );
  }

  @override
  FilterResult fallback(FilterContext context) {
    return FilterResult(
      audioFilters: ["volume=0.999"],
      logMessage: "Layer 11 fallback: Ambient layer bypassed.",
      isFallback: true,
    );
  }
}

