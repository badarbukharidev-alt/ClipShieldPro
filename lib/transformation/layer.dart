class FilterContext {
  final int sourceWidth;
  final int sourceHeight;
  final double duration;
  final bool hasAudio;
  final String quality; // 'high', 'balanced', 'fast'
  final int targetWidth;
  final int targetHeight;
  final String? cropCoordinates; // "w:h:x:y"
  final bool isPreview;

  FilterContext({
    required this.sourceWidth,
    required this.sourceHeight,
    required this.duration,
    required this.hasAudio,
    required this.quality,
    required this.targetWidth,
    required this.targetHeight,
    this.cropCoordinates,
    this.isPreview = false,
  });
}

class FilterResult {
  final List<String> videoFilters;
  final List<String> audioFilters;
  final List<String> extraArgs;
  final String? logMessage;
  final bool isFallback;

  FilterResult({
    List<String>? videoFilters,
    List<String>? audioFilters,
    List<String>? extraArgs,
    this.logMessage,
    this.isFallback = false,
  })  : videoFilters = videoFilters ?? [],
        audioFilters = audioFilters ?? [],
        extraArgs = extraArgs ?? [];
}

abstract class TransformationLayer {
  int get layerNumber;
  String get name;
  String get subtitle;
  String get description;
  bool isEnabled;
  double intensity; // 0.0 to 1.0 (default 0.5)

  TransformationLayer({
    this.isEnabled = true,
    this.intensity = 0.5,
  });

  /// Validates layer configuration before rendering.
  bool validate(FilterContext context);

  /// Executes the layer logic to generate FFmpeg filters.
  FilterResult apply(FilterContext context);

  /// Safe fallback configuration if apply fails or configuration is invalid.
  FilterResult fallback(FilterContext context);

  /// Safely executes layer with error containment.
  FilterResult safeApply(FilterContext context) {
    if (!isEnabled) {
      return FilterResult(logMessage: "Layer $layerNumber ($name) disabled by user.");
    }
    try {
      if (!validate(context)) {
        return fallback(context);
      }
      return apply(context);
    } catch (e) {
      return fallback(context);
    }
  }
}
