import 'dart:math';
import '../layer.dart';

class BlurLayer extends TransformationLayer {
  final Random _random = Random();
  double? customSigma;

  BlurLayer({super.isEnabled = true, super.intensity = 0.5, this.customSigma});

  @override int get layerNumber => 10;
  @override String get name => "Gaussian Blur Defense";
  @override String get subtitle => "Sub-pixel Gaussian softening for fingerprint disruption";
  @override String get description => "Applies very subtle Gaussian blur (sigma 0.3–0.8) to shift pixel-level visual fingerprints without visible quality loss.";

  @override
  bool validate(FilterContext context) {
    final s = customSigma ?? 0.5;
    return s >= 0.1 && s <= 2.0;
  }

  @override
  FilterResult apply(FilterContext context) {
    final double minSigma = 0.3 + (intensity * 0.1);
    final double maxSigma = 0.5 + (intensity * 0.3);
    final double sigma = customSigma ?? (minSigma + _random.nextDouble() * (maxSigma - minSigma));

    return FilterResult(
      videoFilters: ["gblur=sigma=${sigma.toStringAsFixed(2)}"],
      logMessage: "Layer 10 applied: Gaussian blur sigma=${sigma.toStringAsFixed(2)} for pixel fingerprint disruption.",
    );
  }

  @override
  FilterResult fallback(FilterContext context) {
    return FilterResult(
      videoFilters: ["gblur=sigma=0.3"],
      logMessage: "Layer 10 fallback: Minimal blur applied.",
      isFallback: true,
    );
  }
}
