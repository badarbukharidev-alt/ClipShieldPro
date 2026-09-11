import '../layer.dart';

class BlurLayer extends TransformationLayer {
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
    return FilterResult(
      videoFilters: ["boxblur=1:1"],
      logMessage: "Layer 10 applied: Fast boxblur for pixel fingerprint disruption.",
    );
  }

  @override
  FilterResult fallback(FilterContext context) {
    return FilterResult(
      videoFilters: ["boxblur=1:1"],
      logMessage: "Layer 10 fallback: Minimal blur applied.",
      isFallback: true,
    );
  }
}
