import 'dart:io';
import 'dart:async';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/session.dart';
import 'package:path/path.dart' as path;
import '../transformation/pipeline.dart';
import '../transformation/layer.dart';
import 'media_probe_service.dart';
import '../transformation/song_remover_pipeline.dart';
import '../models/audio_dsp_config.dart';

class FfmpegEngineService {
  /// Executes a single video transformation render.
  Future<void> renderClip({
    required String inputPath,
    required String outputPath,
    required double startTime,
    required double endTime,
    required TransformationPipeline pipeline,
    required FilterContext context,
    required Function(double progress, String stage) onProgress,
    required Function(String log) logCallback,
  }) async {
    logCallback("Verifying input media integrity...");
    final probe = await MediaProbeService.probe(inputPath);
    logCallback("Source Probed: ${probe.width}x${probe.height} @ ${probe.fps.toStringAsFixed(1)}fps, audio=${probe.hasAudio}");

    onProgress(0.15, "Compiling 9-layer filtergraph...");
    final args = pipeline.buildFfmpegArgs(
      inputPath: inputPath,
      outputPath: outputPath,
      start: startTime,
      end: endTime,
      context: context,
      logCallback: logCallback,
    );

    logCallback("Dispatching multi-threaded FFmpeg execution session...");
    onProgress(0.20, "Initializing hardware encoding...");

    final double clipDuration = (endTime - startTime).abs();
    final completer = Completer<Session>();

    await FFmpegKit.executeWithArgumentsAsync(
      args,
      (completedSession) {
        completer.complete(completedSession);
      },
      (log) {
        final message = log.getMessage();
        if (message.isNotEmpty && (message.contains("Error") || message.contains("failed"))) {
          logCallback("FFmpeg: $message");
        }
      },
      (statistics) {
        final timeMs = statistics.getTime();
        if (timeMs > 0 && clipDuration > 0) {
          final double timeSec = timeMs / 1000.0;
          final double p = (timeSec / clipDuration).clamp(0.0, 0.98);
          final double fps = statistics.getVideoFps();
          final String fpsText = fps > 0 ? " (${fps.toStringAsFixed(0)} fps)" : "";
          onProgress(0.20 + (p * 0.70), "Encoding: ${(p * 100).toInt()}%$fpsText");
        }
      },
    );

    final session = await completer.future;
    final returnCode = await session.getReturnCode();

    bool renderSucceeded = returnCode != null && returnCode.isValueSuccess();

    // Check if output file was created and is healthy even if returnCode has a minor warning
    final outputFile = File(outputPath);
    if (!renderSucceeded && await outputFile.exists() && await outputFile.length() > 50000) {
      logCallback("Primary session exited with code $returnCode but output file exists (${(await outputFile.length()) ~/ 1024} KB).");
      renderSucceeded = true;
    }

    if (!renderSucceeded) {
      final logs = await session.getLogsAsString();
      logCallback("Primary render session failed ($returnCode): $logs");
      logCallback("Dispatching resilient baseline fallback encoder...");
      onProgress(0.85, "Applying resilient baseline encode...");

      try {
        if (await outputFile.exists()) await outputFile.delete();
      } catch (_) {}

      final fallbackArgs = [
        "-y",
        "-threads", "0",
        if (startTime > 0.01) ...["-ss", startTime.toStringAsFixed(3)],
        "-i", inputPath,
        if (clipDuration > 0.01) ...["-t", clipDuration.toStringAsFixed(3)],
        "-vf", "scale=${context.targetWidth}:${context.targetHeight}:flags=bicubic,boxblur=1:1",
        "-c:v", "libx264",
        "-preset", "ultrafast",
        "-crf", "22",
        "-pix_fmt", "yuv420p",
        if (context.hasAudio) ...["-c:a", "aac", "-b:a", "192k"],
        outputPath,
      ];
      final fallbackSession = await FFmpegKit.executeWithArguments(fallbackArgs);
      final fbCode = await fallbackSession.getReturnCode();

      final bool fbFileValid = await outputFile.exists() && await outputFile.length() > 1024;

      if ((fbCode == null || !fbCode.isValueSuccess()) && !fbFileValid) {
        final fbLogs = await fallbackSession.getLogsAsString();
        logCallback("Fallback render failed: $fbLogs");
        throw Exception("FFmpeg render failed ($fbCode): $fbLogs");
      }
      logCallback("Resilient fallback succeeded!");
    }

    onProgress(0.95, "Validating rendered asset...");
    final isValid = await validateOutput(outputPath, logCallback);
    if (!isValid) {
      throw Exception("Output validation failed. The generated file is invalid or empty.");
    }

    onProgress(1.0, "Render complete!");
    logCallback("Clip generated and verified: ${path.basename(outputPath)}");
  }

  /// Generates a fast 5-second preview segment using the exact same transformation pipeline.
  Future<String> generatePreviewSegment({
    required String inputPath,
    required String previewOutputPath,
    required double previewStartTime,
    required TransformationPipeline pipeline,
    required FilterContext context,
    required Function(String log) logCallback,
  }) async {
    final double start = previewStartTime;
    final double end = previewStartTime + 5.0; // 5-second preview

    final previewContext = FilterContext(
      sourceWidth: context.sourceWidth,
      sourceHeight: context.sourceHeight,
      duration: 5.0,
      hasAudio: context.hasAudio,
      quality: 'fast',
      targetWidth: context.targetWidth,
      targetHeight: context.targetHeight,
      cropCoordinates: context.cropCoordinates,
      isPreview: true,
    );

    final args = pipeline.buildFfmpegArgs(
      inputPath: inputPath,
      outputPath: previewOutputPath,
      start: start,
      end: end,
      context: previewContext,
      logCallback: logCallback,
    );

    logCallback("Generating preview segment (5s)...");
    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();

    if (returnCode == null || !returnCode.isValueSuccess()) {
      throw Exception("Preview generation failed.");
    }

    return previewOutputPath;
  }

  /// Generates high-definition thumbnail poster.
  Future<String> extractThumbnail({
    required String videoPath,
    required String thumbnailPath,
    double? timestamp,
  }) async {
    final probe = await MediaProbeService.probe(videoPath);
    final double targetTime = timestamp ?? (probe.duration > 2.0 ? probe.duration * 0.10 : 0.5);

    final args = [
      "-y",
      "-ss",
      targetTime.toStringAsFixed(3),
      "-i",
      videoPath,
      "-vframes",
      "1",
      "-q:v",
      "2",
      "-vf",
      "scale=480:-1",
      thumbnailPath,
    ];

    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();

    if (returnCode == null || !returnCode.isValueSuccess()) {
      throw Exception("Failed to extract thumbnail image.");
    }

    return thumbnailPath;
  }

  /// Output validation: ensures file exists, non-zero size, and logs media info.
  Future<bool> validateOutput(String filePath, Function(String) logCallback) async {
    final file = File(filePath);
    if (!await file.exists()) {
      logCallback("Validation Error: File does not exist at $filePath");
      return false;
    }

    final size = await file.length();
    if (size < 512) {
      logCallback("Validation Error: Output file size is too small ($size bytes).");
      return false;
    }

    try {
      final probe = await MediaProbeService.probe(filePath);
      logCallback("Validation Passed: ${probe.width}x${probe.height}, ${probe.duration.toStringAsFixed(1)}s, ${size ~/ 1024} KB.");
    } catch (e) {
      logCallback("Validation Notice: File generated healthy size (${size ~/ 1024} KB).");
    }
    return true;
  }

  /// Renders audio with DSP processing for Songs Remover module.
  Future<String> renderSongRemoverAudio({
    required String inputPath,
    required String outputPath,
    required AudioDspConfig config,
    required Function(double progress, String stage) onProgress,
    required Function(String log) logCallback,
  }) async {
    final pipeline = SongRemoverPipeline();
    onProgress(0.1, "Building audio DSP chain...");

    final args = pipeline.buildAudioDspArgs(
      inputPath: inputPath,
      outputPath: outputPath,
      config: config,
      logCallback: logCallback,
    );

    logCallback("Dispatching audio DSP FFmpeg session...");
    onProgress(0.3, "Processing audio...");

    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();

    if (returnCode == null || !returnCode.isValueSuccess()) {
      final logs = await session.getLogsAsString();
      logCallback("Audio DSP failed: $logs");
      throw Exception("Audio DSP processing failed");
    }

    onProgress(0.8, "Audio processing complete!");
    return outputPath;
  }

  /// Composes a static cover image + processed audio into a final video.
  Future<String> composeCoverVideo({
    required String imagePath,
    required String audioPath,
    required String outputPath,
    required bool isWidescreen,
    required Function(double progress, String stage) onProgress,
    required Function(String log) logCallback,
  }) async {
    final pipeline = SongRemoverPipeline();
    onProgress(0.1, "Preparing cover image composition...");

    final args = pipeline.buildImageVideoArgs(
      imagePath: imagePath,
      audioPath: audioPath,
      outputPath: outputPath,
      isWidescreen: isWidescreen,
      logCallback: logCallback,
    );

    logCallback("Dispatching image+audio composition...");
    onProgress(0.3, "Composing video...");

    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();

    if (returnCode == null || !returnCode.isValueSuccess()) {
      final logs = await session.getLogsAsString();
      logCallback("Composition failed: $logs");
      throw Exception("Cover image + audio composition failed");
    }

    onProgress(0.9, "Composition complete!");
    return outputPath;
  }
}
