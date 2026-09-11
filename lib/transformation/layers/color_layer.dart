import 'dart:math';
import '../layer.dart';

class ColorLayer extends TransformationLayer {
  final Random _random = Random();
  double? customHueDegrees;
  double? customSaturation;

  ColorLayer({
    super.isEnabled = true,
    super.intensity = 0.5,
    this.customHueDegrees,
    this.customSaturation,
  });

  @override
  int get layerNumber => 6;

  @override
  String get name => "Color Processing & Grading";

  @override
  String get subtitle => "OLED chromatic tone grading & saturation tuning";

  @override
  String get description =>
      "Subtly enriches color depth and skin tones via controlled hue micro-rotations and saturation calibration.";

  @override
  bool validate(FilterContext context) {
    final h = customHueDegrees ?? 0.0;
    final s = customSaturation ?? 1.0;
    return h.abs() <= 15.0 && s >= 0.8 && s <= 1.2;
  }

  @override
  FilterResult apply(FilterContext context) {
    // Hue range: +-3 to 5 deg scaled by intensity
    final double maxHue = 3.0 + (intensity * 4.0); // 3.0 to 7.0 deg
    final double hue = customHueDegrees ??
        ((_random.nextDouble() * (2.0 * maxHue)) - maxHue);

    // Saturation range: 0.97 to 1.03 scaled by intensity
    final double satRange = 0.02 + (intensity * 0.03); // 0.02 to 0.05
    final double sat = customSaturation ??
        (1.0 + ((_random.nextDouble() * (2.0 * satRange)) - satRange));

    final double contrast = 1.0 + ((_random.nextDouble() * 0.04) - 0.02); // 0.98 to 1.02
    final String colorFilter =
        "hue=h=${hue.toStringAsFixed(2)}:s=${sat.toStringAsFixed(4)}";
    final String contrastFilter =
        "eq=contrast=${contrast.toStringAsFixed(3)}";

    return FilterResult(
      videoFilters: [colorFilter, contrastFilter],
      logMessage:
          "Layer 6 applied: Hue shift ${hue.toStringAsFixed(2)}°, Saturation ${sat.toStringAsFixed(3)}x, Contrast ${contrast.toStringAsFixed(3)}.",
    );
  }

  @override
  FilterResult fallback(FilterContext context) {
    return FilterResult(
      videoFilters: ["hue=s=1.01"],
      logMessage: "Layer 6 fallback: Slight baseline saturation enhancement.",
      isFallback: true,
    );
  }
}
