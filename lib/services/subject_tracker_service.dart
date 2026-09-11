import 'dart:io';
import 'dart:math';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/app_modes.dart';

class SubjectTrackerService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: false,
      enableLandmarks: false,
      enableTracking: false,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  /// Analyzes a video segment to detect subject faces and compute the smoothed 9:16 crop window.
  /// Returns "cropW:cropH:cropX:cropY"
  Future<String> calculateOptimalCrop({
    required String videoPath,
    required double startTime,
    required double endTime,
    required int sourceWidth,
    required int sourceHeight,
    AspectRatioOption aspectOption = AspectRatioOption.vertical916,
    required Function(String) logCallback,
  }) async {
    // 1. Calculate Target Crop Dimensions
    int cropW, cropH;
    final double targetRatio = aspectOption.ratio; // e.g. 9/16 = 0.5625

    if (sourceWidth > sourceHeight) {
      // Landscape source (16:9)
      cropH = sourceHeight;
      cropW = (sourceHeight * targetRatio).round();
      if (cropW % 2 != 0) cropW += 1;
    } else {
      // Portrait or square source
      cropW = sourceWidth;
      cropH = (sourceWidth / targetRatio).round();
      if (cropH % 2 != 0) cropH += 1;
      if (cropH > sourceHeight) {
        cropH = sourceHeight;
        cropW = (sourceHeight * targetRatio).round();
        if (cropW % 2 != 0) cropW += 1;
      }
    }

    final int defaultX = ((sourceWidth - cropW) / 2).round().clamp(0, max(0, sourceWidth - cropW));
    final int defaultY = ((sourceHeight - cropH) / 2).round().clamp(0, max(0, sourceHeight - cropH));

    if (sourceWidth == cropW && sourceHeight == cropH) {
      logCallback("Source already matches target aspect ratio. Centered viewport.");
      return "$cropW:$cropH:0:0";
    }

    logCallback("Dynamic Viewport target: ${cropW}x$cropH (Default Center: $defaultX, $defaultY)");

    final tempDir = await getTemporaryDirectory();
    final sampleDir = Directory(path.join(tempDir.path, "subject_samples_${DateTime.now().millisecondsSinceEpoch}"));
    await sampleDir.create(recursive: true);

    try {
      // 2. High-Speed Temporal Frame Sampling (3 key frames: 20%, 50%, 80%)
      const int sampleCount = 3;
      final double duration = max(1.0, endTime - startTime);
      final double interval = duration / (sampleCount + 1);

      List<double> xPositions = [];
      List<double> yPositions = [];

      const double scaledWidth = 480.0;
      final double scaleRatio = sourceWidth / scaledWidth;
      final int scaledHeight = (sourceHeight / scaleRatio).round();

      logCallback("Fast subject centroid tracking ($sampleCount samples)...");

      for (int i = 0; i < sampleCount; i++) {
        final double t = startTime + (i * interval);
        final String framePath = path.join(sampleDir.path, "frame_$i.jpg");

        final String extractCmd =
            "-y -ss ${t.toStringAsFixed(3)} -i \"$videoPath\" -vframes 1 -vf \"scale=${scaledWidth.toInt()}:$scaledHeight\" -q:v 3 \"$framePath\"";

        final session = await FFmpegKit.execute(extractCmd);
        final returnCode = await session.getReturnCode();

        if (returnCode != null && returnCode.isValueSuccess()) {
          final file = File(framePath);
          if (await file.exists()) {
            final inputImage = InputImage.fromFilePath(framePath);
            final faces = await _faceDetector.processImage(inputImage);

            if (faces.isNotEmpty) {
              // Focus on largest face in frame
              faces.sort((a, b) =>
                  (b.boundingBox.width * b.boundingBox.height)
                      .compareTo(a.boundingBox.width * a.boundingBox.height));
              final primaryFace = faces.first;
              final double centerX = primaryFace.boundingBox.left + (primaryFace.boundingBox.width / 2.0);
              final double centerY = primaryFace.boundingBox.top + (primaryFace.boundingBox.height / 2.0);

              xPositions.add(centerX * scaleRatio);
              yPositions.add(centerY * scaleRatio);
            }
          }
        }
      }

      int optX = defaultX;
      int optY = defaultY;

      // 3. Statistical Median Centroid Aggregation (avoids jitter and outliers)
      if (sourceWidth > cropW && xPositions.isNotEmpty) {
        xPositions.sort();
        final double medianX = xPositions[xPositions.length ~/ 2];
        optX = (medianX - (cropW / 2.0)).round();
        optX = optX.clamp(0, sourceWidth - cropW);
        if (optX % 2 != 0) optX += 1;
      }

      if (sourceHeight > cropH && yPositions.isNotEmpty) {
        yPositions.sort();
        final double medianY = yPositions[yPositions.length ~/ 2];
        optY = (medianY - (cropH / 2.0)).round();
        optY = optY.clamp(0, sourceHeight - cropH);
        if (optY % 2 != 0) optY += 1;
      }

      logCallback("Centroid tracking completed. Subject identified in ${xPositions.length}/$sampleCount frames.");
      logCallback("Clamped Reframing Coordinates: $cropW:$cropH:$optX:$optY");

      return "$cropW:$cropH:$optX:$optY";
    } catch (e) {
      logCallback("Notice: Subject tracking fallback to default center ($e).");
      return "$cropW:$cropH:$defaultX:$defaultY";
    } finally {
      try {
        if (await sampleDir.exists()) {
          await sampleDir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  void dispose() {
    _faceDetector.close();
  }
}
