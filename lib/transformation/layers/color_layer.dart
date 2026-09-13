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
    return h.abs() <= 20.0 && s >= 0.8 && s <= 1.2;
  }

  @override
  FilterResult apply(FilterContext context) {
    // Every value carries a guaranteed minimum magnitude so a render can never
    // come out as an accidental passthrough of the source.
    final double hue =
        customHueDegrees ?? signedJitter(_random, 4.0, 4.0 + (intensity * 5.0));
    final double sat = customSaturation ??
        (1.0 + signedJitter(_random, 0.03, 0.03 + (intensity * 0.05)));
    final double contrast =
        1.0 + signedJitter(_random, 0.03, 0.03 + (intensity * 0.03));

    // hue carries the saturation; contrast rides on eq so the pipeline can fuse
    // it with the gamma layer's eq into a single filter instance.
    final String hueFilter =
        "hue=h=${hue.toStringAsFixed(2)}:s=${sat.toStringAsFixed(4)}";
    final String contrastFilter =
        "eq=contrast=${contrast.toStringAsFixed(4)}";

    return FilterResult(
      videoFilters: [hueFilter, contrastFilter],
      logMessage:
          "Layer 6 applied: Hue shift ${hue.toStringAsFixed(2)}°, Saturation ${sat.toStringAsFixed(3)}x, Contrast ${contrast.toStringAsFixed(3)}.",
    );
  }

  @override
  FilterResult fallback(FilterContext context) {
    // Even the fallback must perturb: a neutral fallback would hand back an
    // untransformed frame.
    final double hue = signedJitter(_random, 4.0, 6.0);
    return FilterResult(
      videoFilters: [
        "hue=h=${hue.toStringAsFixed(2)}:s=1.03",
        "eq=contrast=1.03",
      ],
      logMessage:
          "Layer 6 fallback: Baseline chromatic shift (hue ${hue.toStringAsFixed(2)}°).",
      isFallback: true,
    );
  }
}
