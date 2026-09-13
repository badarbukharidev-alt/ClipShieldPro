import 'dart:math';
import '../layer.dart';

class SpatialAudioLayer extends TransformationLayer {
  final Random _random = Random();
  int? customLeftDelayMs;
  int? customRightDelayMs;

  SpatialAudioLayer({
    super.isEnabled = true,
    super.intensity = 0.5,
    this.customLeftDelayMs,
    this.customRightDelayMs,
  });

  @override
  int get layerNumber => 3;

  @override
  String get name => "Stereo / Spatial Audio";

  @override
  String get subtitle => "Micro-phase stereo decorrelation & spatial widening";

  @override
  String get description =>
      "Expands stereo spatial soundstage with controlled micro-delay offsets without causing acoustic phase cancellation.";

  @override
  bool validate(FilterContext context) {
    if (!context.hasAudio) return false;
    final l = customLeftDelayMs ?? 30;
    final r = customRightDelayMs ?? 30;
    return l >= 0 && l <= 100 && r >= 0 && r <= 100;
  }

  @override
  FilterResult apply(FilterContext context) {
    if (!context.hasAudio) {
      return FilterResult(logMessage: "Layer 3: No audio stream detected. Skipped.");
    }

    // Delay range scaled by intensity: 15ms to 45ms
    final int minDelay = (15 * intensity).round().clamp(10, 25);
    final int maxDelay = (35 + (25 * intensity)).round().clamp(25, 60);

    final int lDelay = customLeftDelayMs ??
        (minDelay + _random.nextInt(max(1, maxDelay - minDelay)));
    final int rDelay = customRightDelayMs ??
        (minDelay + _random.nextInt(max(1, maxDelay - minDelay)));

    return FilterResult(
      audioFilters: [
        "adelay=$lDelay|$rDelay",
      ],
      logMessage:
          "Layer 3 applied: Spatial delay L: ${lDelay}ms, R: ${rDelay}ms.",
    );
  }

  @override
  FilterResult fallback(FilterContext context) {
    return FilterResult(
      audioFilters: ["aformat=channel_layouts=stereo"],
      logMessage: "Layer 3 fallback: Standard stereo pass-through.",
      isFallback: true,
    );
  }
}
