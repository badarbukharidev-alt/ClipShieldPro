import '../layer.dart';

class ResamplingLayer extends TransformationLayer {
  int? forcedWidth;
  int? forcedHeight;

  ResamplingLayer({
    super.isEnabled = true,
    super.intensity = 0.5,
    this.forcedWidth,
    this.forcedHeight,
  });

  @override
  int get layerNumber => 5;

  @override
  String get name => "High-Fidelity Resampling";

  @override
  String get subtitle => "High-density bicubic adaptive canvas resampling";

  @override
  String get description =>
      "Re-interpolates pixel geometry into a crisp widescreen (16:9) or vertical (9:16) matrix optimized for high-resolution displays.";

  @override
  bool validate(FilterContext context) {
    final w = forcedWidth ?? context.targetWidth;
    final h = forcedHeight ?? context.targetHeight;
    return w > 0 && h > 0 && w % 2 == 0 && h % 2 == 0;
  }

  @override
  FilterResult apply(FilterContext context) {
    final int w = forcedWidth ?? context.targetWidth;
    final int h = forcedHeight ?? context.targetHeight;

    // Bicubic interpolation for crisp scaling without blurring. setsar=1 forces
    // square pixels so the display aspect ratio is exactly w:h -- without it the
    // micro-crop from layer 4 leaves a skewed SAR and a 16:9 source can be
    // presented as something other than 16:9.
    return FilterResult(
      videoFilters: ["scale=$w:$h:flags=bicubic", "setsar=1"],
      logMessage: "Layer 5 applied: High-fidelity bicubic resampling to ${w}x$h (square pixels).",
    );
  }

  @override
  FilterResult fallback(FilterContext context) {
    final int safeW = (context.targetWidth > 0 && context.targetWidth % 2 == 0)
        ? context.targetWidth
        : 720;
    final int safeH = (context.targetHeight > 0 && context.targetHeight % 2 == 0)
        ? context.targetHeight
        : 1280;

    return FilterResult(
      videoFilters: ["scale=$safeW:$safeH", "setsar=1"],
      logMessage: "Layer 5 fallback: Standard bilinear scale to ${safeW}x$safeH.",
      isFallback: true,
    );
  }
}
