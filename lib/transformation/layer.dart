import 'dart:math';

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

  /// Ask for the device's hardware H.264 encoder. Software x264 on a phone is
  /// the dominant cost for long sources; mediacodec is several times faster.
  /// Support varies by device, so the caller must be able to fall back.
  final bool preferHardwareEncoder;

  /// Target bitrate used when hardware encoding, which has no CRF equivalent.
  final int hardwareBitrateKbps;

  /// Absolute path to a generated .ass file to burn in, or null for no
  /// captions. Applied last in the chain so the blur layer cannot soften text.
  final String? subtitlePath;

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
    this.preferHardwareEncoder = false,
    this.hardwareBitrateKbps = 8000,
    this.subtitlePath,
  });
}

/// Returns a random value whose magnitude is at least [minMagnitude] and at most
/// [maxMagnitude], with a random sign.
///
/// Layers must never draw a perturbation straight from a zero-centred uniform
/// range: such a draw regularly lands near zero, producing a render that is
/// effectively identical to the source. Every transformation gets a guaranteed
/// floor so no output is ever an accidental passthrough.
double signedJitter(Random random, double minMagnitude, double maxMagnitude) {
  final double lo = minMagnitude.abs();
  final double hi = maxMagnitude.abs() < lo ? lo : maxMagnitude.abs();
  final double magnitude = lo + (random.nextDouble() * (hi - lo));
  return random.nextBool() ? magnitude : -magnitude;
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
