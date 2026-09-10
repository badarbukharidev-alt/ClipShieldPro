import 'dart:math';
import '../layer.dart';

class GeometryLayer extends TransformationLayer {
  final Random _random = Random();
  int? customCropPixels;

  GeometryLayer({
    super.isEnabled = true,
    super.intensity = 0.5,
    this.customCropPixels,
  });

  @override
  int get layerNumber => 4;

  @override
  String get name => "Geometric Micro-Transformation";

  @override
  String get subtitle => "Sub-pixel canvas calibration & edge trimming";

  @override
  String get description =>
      "Applies subtle geometric offset trimming to clean edge compression artifacts and shift coordinate matrices.";

  @override
  bool validate(FilterContext context) {
    if (context.cropCoordinates == null) return false;
    final parts = context.cropCoordinates!.split(':');
    return parts.length == 4 && parts.every((p) => int.tryParse(p) != null);
  }

  @override
  FilterResult apply(FilterContext context) {
    if (context.cropCoordinates == null) {
      return fallback(context);
    }

    final parts = context.cropCoordinates!.split(':');
    int cropW = int.parse(parts[0]);
    int cropH = int.parse(parts[1]);
    int cropX = int.parse(parts[2]);
    int cropY = int.parse(parts[3]);

    final int px = customCropPixels ?? (_random.nextInt(3) + 1); // 1 to 3 px
    final edges = ['left', 'right', 'top', 'bottom'];
    final edge = edges[_random.nextInt(edges.length)];

    if (edge == 'left') {
      cropW -= px;
      cropX += px;
    } else if (edge == 'right') {
      cropW -= px;
    } else if (edge == 'top') {
      cropH -= px;
      cropY += px;
    } else {
      cropH -= px;
    }

    // Ensure even numbers for H.264 video encoding
    if (cropW % 2 != 0) cropW -= 1;
    if (cropH % 2 != 0) cropH -= 1;
    if (cropX % 2 != 0) cropX += 1;
    if (cropY % 2 != 0) cropY += 1;

    // Boundary clamp
    cropX = cropX.clamp(0, max(0, context.sourceWidth - cropW));
    cropY = cropY.clamp(0, max(0, context.sourceHeight - cropH));

    return FilterResult(
      videoFilters: ["crop=$cropW:$cropH:$cropX:$cropY"],
      logMessage:
          "Layer 4 applied: Micro-crop ($edge trimmed $px px) -> Crop: ${cropW}x$cropH at ($cropX, $cropY).",
    );
  }

  @override
  FilterResult fallback(FilterContext context) {
    if (context.cropCoordinates != null) {
      return FilterResult(
        videoFilters: ["crop=${context.cropCoordinates}"],
        logMessage: "Layer 4 fallback: Standard baseline crop box applied.",
        isFallback: true,
      );
    }
    return FilterResult(
      logMessage: "Layer 4 fallback: No crop filter required.",
      isFallback: true,
    );
  }
}
