import 'dart:math';
import '../layer.dart';

class GammaLayer extends TransformationLayer {
  final Random _random = Random();
  double? customGamma;

  GammaLayer({
    super.isEnabled = true,
    super.intensity = 0.5,
    this.customGamma,
  });

  @override
  int get layerNumber => 7;

  @override
  String get name => "Gamma / Mid-Tone Processing";

  @override
  String get subtitle => "Shadow detail calibration & contrast luminance";

  @override
  String get description =>
      "Calibrates dynamic range and mid-tone gamma to prevent clipping in high-contrast scenes.";

  @override
  bool validate(FilterContext context) {
    final g = customGamma ?? 1.0;
    return g >= 0.8 && g <= 1.2;
  }

  @override
  FilterResult apply(FilterContext context) {
    final double maxDelta = 0.01 + (intensity * 0.02); // 0.01 to 0.03
    final double gamma = customGamma ??
        (1.0 + ((_random.nextDouble() * (2.0 * maxDelta)) - maxDelta));

    final String gammaFilter = "eq=gamma=${gamma.toStringAsFixed(4)}";

    return FilterResult(
      videoFilters: [gammaFilter],
      logMessage:
          "Layer 7 applied: Dynamic mid-tone gamma calibrated to ${gamma.toStringAsFixed(3)}.",
    );
  }

  @override
  FilterResult fallback(FilterContext context) {
    return FilterResult(
      videoFilters: ["eq=gamma=1.0"],
      logMessage: "Layer 7 fallback: Neutral gamma curve.",
      isFallback: true,
    );
  }
}
