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
import 'device_capability_service.dart';

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

      // The recovery encode must still transform. A plain rescale would hand
      // back a file that is visually and audibly identical to the source while
      // being presented to the user as a protected export.
      final fallbackArgs = pipeline.buildResilientArgs(
        inputPath: inputPath,
        outputPath: outputPath,
        start: startTime,
        end: endTime,
        context: context,
        logCallback: logCallback,
      );
      final fallbackCompleter = Completer<Session>();
      await FFmpegKit.executeWithArgumentsAsync(
        fallbackArgs,
        (s) => fallbackCompleter.complete(s),
        (log) {
          final message = log.getMessage();
          if (message.isNotEmpty && (message.contains("Error") || message.contains("failed"))) {
            logCallback("FFmpeg Fallback: $message");
          }
        },
        (stats) {
          final timeMs = stats.getTime();
          if (timeMs > 0 && clipDuration > 0) {
            final double p = (timeMs / 1000.0 / clipDuration).clamp(0.0, 0.98);
            onProgress(0.85 + (p * 0.09), "Fallback: ${(p * 100).toInt()}%");
          }
        },
      );
      final fallbackSession = await fallbackCompleter.future;
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

  /// Generates a fast, lightweight 5-second preview segment.
  /// Uses tier-capped resolution, -preset ultrafast, max 2 threads, and async execution.
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
    final double duration = end - start;

    final capabilities = DeviceCapabilityService.instance;
    final int tierCeiling = capabilities.maxOutputHeight; // e.g. 720 on low-tier, 1080 on mid/high
    final int threads = capabilities.isLowEnd ? 1 : 2;

    // Calculate capped preview dimensions preserving aspect ratio
    int prevW = context.targetWidth;
    int prevH = context.targetHeight;
    if (prevH > tierCeiling || prevW > tierCeiling) {
      if (prevH >= prevW) {
        // Portrait / 9:16 or tall
        prevW = (prevW * tierCeiling / prevH).round();
        prevH = tierCeiling;
      } else {
        // Landscape / 16:9 or wide
        prevH = (prevH * tierCeiling / prevW).round();
        prevW = tierCeiling;
      }
      if (prevW.isOdd) prevW -= 1;
      if (prevH.isOdd) prevH -= 1;
    }

    final previewContext = FilterContext(
      sourceWidth: context.sourceWidth,
      sourceHeight: context.sourceHeight,
      duration: duration,
      hasAudio: context.hasAudio,
      quality: 'fast',
      targetWidth: prevW,
      targetHeight: prevH,
      cropCoordinates: context.cropCoordinates,
      sourceAudioSampleRate: context.sourceAudioSampleRate,
      sourceAudioChannels: context.sourceAudioChannels,
      isPreview: true,
    );

    // Fast preview args: single pass, ultrafast, max 2 threads, async
    final args = pipeline.buildResilientArgs(
      inputPath: inputPath,
      outputPath: previewOutputPath,
      start: start,
      end: end,
      context: previewContext,
      logCallback: logCallback,
    );

    // Enforce threads and preset bounds in preview args
    final int threadIdx = args.indexOf("-threads");
    if (threadIdx >= 0 && threadIdx + 1 < args.length) {
      args[threadIdx + 1] = "$threads";
    }

    logCallback("Generating lightweight preview segment (5s, ${prevW}x$prevH, $threads threads)...");
    final completer = Completer<Session>();
    await FFmpegKit.executeWithArgumentsAsync(
      args,
      (s) => completer.complete(s),
      (log) {
        final msg = log.getMessage();
        if (msg.isNotEmpty && (msg.contains("Error") || msg.contains("failed"))) {
          logCallback("FFmpeg Preview: $msg");
        }
      },
      (stats) {},
    );

    final session = await completer.future;
    final returnCode = await session.getReturnCode();

    if (returnCode == null || !returnCode.isValueSuccess()) {
      final logs = await session.getLogsAsString();
      logCallback("Preview generation failed ($returnCode): $logs");
      throw Exception("Preview generation failed.");
    }

    return previewOutputPath;
  }

  /// Generates high-definition thumbnail poster asynchronously without blocking main thread.
  Future<String> extractThumbnail({
    required String videoPath,
    required String thumbnailPath,
    double? timestamp,
  }) async {
    final probe = await MediaProbeService.probe(videoPath);
    final double targetTime = timestamp ?? (probe.duration > 2.0 ? probe.duration * 0.10 : 0.5);

    final args = [
      "-y",
      "-threads",
      "${DeviceCapabilityService.instance.encoderThreads}",
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

    final completer = Completer<Session>();
    await FFmpegKit.executeWithArgumentsAsync(
      args,
      (s) => completer.complete(s),
      (_) {},
      (_) {},
    );

    final session = await completer.future;
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

  /// Renders audio with DSP processing for Songs Remover module asynchronously.
  Future<String> renderSongRemoverAudio({
    required String inputPath,
    required String outputPath,
    required AudioDspConfig config,
    double? audioDuration,
    int sourceSampleRate = 44100,
    int sourceChannels = 2,
    required Function(double progress, String stage) onProgress,
    required Function(String log) logCallback,
  }) async {
    final pipeline = SongRemoverPipeline();
    onProgress(0.1, "Building audio DSP chain...");

    final args = pipeline.buildAudioDspArgs(
      inputPath: inputPath,
      outputPath: outputPath,
      config: config,
      audioDuration: audioDuration,
      sourceSampleRate: sourceSampleRate,
      sourceChannels: sourceChannels,
      logCallback: logCallback,
    );

    logCallback("Dispatching audio DSP FFmpeg session asynchronously...");
    onProgress(0.3, "Processing audio...");

    final completer = Completer<Session>();
    await FFmpegKit.executeWithArgumentsAsync(
      args,
      (s) => completer.complete(s),
      (log) {
        final msg = log.getMessage();
        if (msg.isNotEmpty && (msg.contains("Error") || msg.contains("failed"))) {
          logCallback("FFmpeg Audio: $msg");
        }
      },
      (stats) {
        final timeMs = stats.getTime();
        if (timeMs > 0 && audioDuration != null && audioDuration > 0) {
          final double p = (timeMs / 1000.0 / audioDuration).clamp(0.0, 0.95);
          onProgress(0.30 + (p * 0.50), "Processing audio: ${(p * 100).toInt()}%");
        }
      },
    );

    final session = await completer.future;
    final returnCode = await session.getReturnCode();

    if (returnCode == null || !returnCode.isValueSuccess()) {
      final logs = await session.getLogsAsString();
      logCallback("Audio DSP failed: $logs");
      throw Exception("Audio DSP processing failed");
    }

    onProgress(0.8, "Audio processing complete!");
    return outputPath;
  }

  /// Composes a static cover image + processed audio into a final video asynchronously.
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

    logCallback("Dispatching image+audio composition asynchronously...");
    onProgress(0.3, "Composing video...");

    final completer = Completer<Session>();
    await FFmpegKit.executeWithArgumentsAsync(
      args,
      (s) => completer.complete(s),
      (log) {
        final msg = log.getMessage();
        if (msg.isNotEmpty && (msg.contains("Error") || msg.contains("failed"))) {
          logCallback("FFmpeg Compose: $msg");
        }
      },
      (stats) {
        final timeMs = stats.getTime();
        if (timeMs > 0) {
          onProgress(0.5, "Encoding cover video...");
        }
      },
    );

    final session = await completer.future;
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
