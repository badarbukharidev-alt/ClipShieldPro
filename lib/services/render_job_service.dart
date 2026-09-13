import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/app_modes.dart';
import '../models/audio_dsp_config.dart';
import '../models/clip_model.dart';
import '../models/project_model.dart';
import '../transformation/layer.dart';
import '../transformation/pipeline.dart';
import 'ffmpeg_engine_service.dart';
import 'gallery_export_service.dart';
import 'license_service.dart';
import 'media_probe_service.dart';
import 'project_storage_service.dart';
import 'subject_tracker_service.dart';

/// Canonical lifecycle of a render job. This is the single source of truth for
/// both the live UI and the persisted [ProjectItem.status].
enum RenderJobStatus { queued, rendering, completed, failed, canceled }

extension RenderJobStatusExt on RenderJobStatus {
  /// Value persisted on [ProjectItem.status].
  String get projectStatus {
    switch (this) {
      case RenderJobStatus.queued:
        return ProjectStatus.queued;
      case RenderJobStatus.rendering:
        return ProjectStatus.rendering;
      case RenderJobStatus.completed:
        return ProjectStatus.done;
      case RenderJobStatus.failed:
        return ProjectStatus.failed;
      case RenderJobStatus.canceled:
        return ProjectStatus.canceled;
    }
  }

  bool get isTerminal =>
      this == RenderJobStatus.completed ||
      this == RenderJobStatus.failed ||
      this == RenderJobStatus.canceled;

  bool get isActive => this == RenderJobStatus.queued || this == RenderJobStatus.rendering;
}

@immutable
class RenderJobState {
  final String projectId;
  final String title;
  final RenderJobStatus status;
  final double progress;
  final String currentStage;
  final int totalClips;
  final int renderedClips;
  final String? error;
  final List<String> outputPaths;
  final DateTime updatedAt;

  const RenderJobState._({
    required this.projectId,
    required this.title,
    required this.status,
    required this.progress,
    required this.currentStage,
    required this.totalClips,
    required this.renderedClips,
    required this.error,
    required this.outputPaths,
    required this.updatedAt,
  });

  factory RenderJobState.queued({
    required String projectId,
    required String title,
    required int totalClips,
  }) {
    return RenderJobState._(
      projectId: projectId,
      title: title,
      status: RenderJobStatus.queued,
      progress: 0.0,
      currentStage: 'Queued',
      totalClips: totalClips,
      renderedClips: 0,
      error: null,
      outputPaths: const [],
      updatedAt: DateTime.now(),
    );
  }

  RenderJobState copyWith({
    RenderJobStatus? status,
    double? progress,
    String? currentStage,
    int? renderedClips,
    String? error,
    List<String>? outputPaths,
  }) {
    return RenderJobState._(
      projectId: projectId,
      title: title,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      currentStage: currentStage ?? this.currentStage,
      totalClips: totalClips,
      renderedClips: renderedClips ?? this.renderedClips,
      error: error ?? this.error,
      outputPaths: outputPaths ?? this.outputPaths,
      updatedAt: DateTime.now(),
    );
  }

  bool get isCompleted => status == RenderJobStatus.completed;
  bool get isFailed => status == RenderJobStatus.failed;
  bool get isCanceled => status == RenderJobStatus.canceled;
  bool get isActive => status.isActive;

  int get progressPercent => (progress * 100).round().clamp(0, 100);

  String get statusLabel {
    switch (status) {
      case RenderJobStatus.queued:
        return 'Queued';
      case RenderJobStatus.rendering:
        return 'Rendering';
      case RenderJobStatus.completed:
        return 'Completed';
      case RenderJobStatus.failed:
        return 'Failed';
      case RenderJobStatus.canceled:
        return 'Canceled';
    }
  }
}

/// Everything the engine needs to render one project, captured at submit time
/// so the job is completely independent of any widget lifecycle.
class _RenderJobRequest {
  final ProjectItem project;
  final String sourceVideoPath;
  final MediaProbeInfo probeInfo;
  final List<ClipItem> clipsToRender;
  final TransformationPipeline pipeline;
  final AspectRatioOption aspectRatio;
  final bool enableSubjectTracking;
  final String quality;

  _RenderJobRequest({
    required this.project,
    required this.sourceVideoPath,
    required this.probeInfo,
    required this.clipsToRender,
    required this.pipeline,
    required this.aspectRatio,
    required this.enableSubjectTracking,
    required this.quality,
  });
}

/// Background render queue. Jobs are submitted from the UI, persisted through
/// [ProjectStorageService] on every state transition, and executed off the
/// widget tree so navigating away never interrupts or restarts a render.
class RenderJobService {
  RenderJobService._privateConstructor();
  static final RenderJobService instance = RenderJobService._privateConstructor();

  final FfmpegEngineService _ffmpegService = FfmpegEngineService();

  /// All jobs known this session, keyed by projectId. Emits a new map on every
  /// transition so listeners rebuild.
  final ValueNotifier<Map<String, RenderJobState>> jobs = ValueNotifier(const {});

  /// The job currently queued or rendering (drives the home-screen banner).
  final ValueNotifier<RenderJobState?> activeJob = ValueNotifier(null);

  final List<_RenderJobRequest> _queue = [];
  final Set<String> _cancelRequests = {};
  final Map<String, List<String>> _logs = {};
  bool _isPumping = false;
  String? _runningProjectId;

  RenderJobState? jobFor(String projectId) => jobs.value[projectId];

  /// Called once at startup. A project persisted as queued/rendering with no
  /// live job can only be a job that died with a previous process, so it is
  /// resolved here rather than being left to look busy forever.
  Future<void> reconcileInterruptedJobs() async {
    final projects = await ProjectStorageService.loadProjects();
    for (final p in projects) {
      if (!p.isRenderingOrQueued) continue;
      if (jobs.value.containsKey(p.id)) continue;
      // Only a project whose every clip already has a verified artifact may be
      // promoted to done; anything short of that was interrupted.
      final bool allDone = p.clips.isNotEmpty &&
          p.clips.every((c) => c.isRendered && c.outputPath != null) &&
          p.outputPaths.length == p.clips.length;
      if (allDone) {
        p.status = ProjectStatus.done;
        p.settings['renderError'] = null;
      } else {
        p.status = ProjectStatus.failed;
        p.settings['renderError'] =
            'Render was interrupted before it finished (${p.outputPaths.length} of ${p.clipsCount} clips produced).';
      }
      try {
        await ProjectStorageService.saveProject(p);
      } catch (_) {}
    }
  }

  List<String> logsFor(String projectId) => List.unmodifiable(_logs[projectId] ?? const <String>[]);

  /// Submits a project for rendering. The project is persisted immediately with
  /// the *selected* clips only, so Projects History shows it right away with a
  /// truthful clip count and a truthful status.
  Future<String> submit({
    required ProjectItem project,
    required String sourceVideoPath,
    required MediaProbeInfo probeInfo,
    required List<ClipItem> clipsToRender,
    required TransformationPipeline pipeline,
    required AspectRatioOption aspectRatio,
    required bool enableSubjectTracking,
    String quality = 'balanced',
  }) async {
    // Only the clips actually being rendered belong to this job's project.
    final selected = clipsToRender
        .map((c) => ClipItem.fromMap(c.toMap())
          ..isSelected = true
          ..outputPath = null
          ..thumbnailPath = null
          ..isRendered = false)
        .toList();

    project.clips = selected;
    project.outputPaths = [];
    project.thumbnailPath = null;
    project.aspectRatio = aspectRatio;
    project.settings['renderError'] = null;
    project.status = ProjectStatus.queued;
    await ProjectStorageService.saveProject(project);

    _cancelRequests.remove(project.id);
    _logs[project.id] = <String>['Job queued with ${selected.length} clip(s).'];
    _emit(RenderJobState.queued(
      projectId: project.id,
      title: project.title,
      totalClips: selected.length,
    ));

    _queue.add(_RenderJobRequest(
      project: project,
      sourceVideoPath: sourceVideoPath,
      probeInfo: probeInfo,
      clipsToRender: selected,
      pipeline: pipeline,
      aspectRatio: aspectRatio,
      enableSubjectTracking: enableSubjectTracking,
      quality: quality,
    ));

    unawaited(_pump());
    return project.id;
  }

  /// Requests cancellation. A queued job is dropped; a running job stops at the
  /// next checkpoint and its in-flight FFmpeg session is killed.
  Future<void> cancel(String projectId) async {
    _cancelRequests.add(projectId);
    _queue.removeWhere((r) => r.project.id == projectId);

    final current = jobs.value[projectId];
    if (current == null || current.status.isTerminal) return;

    if (_runningProjectId == projectId) {
      _log(projectId, 'Cancellation requested - stopping encoder.');
      try {
        await FFmpegKit.cancel();
      } catch (_) {}
      return; // _runJob finalizes the canceled state.
    }

    await _finalize(
      projectId,
      current.copyWith(status: RenderJobStatus.canceled, currentStage: 'Canceled'),
    );
  }

  /// Drops a terminal job from the live map. The persisted project is untouched.
  void dismiss(String projectId) {
    if (jobs.value[projectId]?.status.isTerminal != true) return;
    jobs.value = Map<String, RenderJobState>.from(jobs.value)..remove(projectId);
    _recomputeActive();
  }

  // ---------------------------------------------------------------- internals

  void _emit(RenderJobState state) {
    jobs.value = Map<String, RenderJobState>.from(jobs.value)..[state.projectId] = state;
    _recomputeActive();
  }

  void _recomputeActive() {
    final running = _runningProjectId == null ? null : jobs.value[_runningProjectId];
    if (running != null && running.isActive) {
      activeJob.value = running;
      return;
    }
    RenderJobState? next;
    for (final job in jobs.value.values) {
      if (!job.isActive) continue;
      if (next == null || job.updatedAt.isBefore(next.updatedAt)) next = job;
    }
    activeJob.value = next;
  }

  void _log(String projectId, String message) {
    final list = _logs.putIfAbsent(projectId, () => <String>[]);
    list.add(message);
    if (list.length > 400) list.removeRange(0, list.length - 400);
  }

  Future<void> _pump() async {
    if (_isPumping) return;
    _isPumping = true;
    try {
      while (_queue.isNotEmpty) {
        final request = _queue.removeAt(0);
        final projectId = request.project.id;
        final queuedState = jobs.value[projectId] ??
            RenderJobState.queued(
              projectId: projectId,
              title: request.project.title,
              totalClips: request.clipsToRender.length,
            );

        if (_cancelRequests.contains(projectId)) {
          await _finalize(
            projectId,
            queuedState.copyWith(status: RenderJobStatus.canceled, currentStage: 'Canceled'),
            project: request.project,
          );
          continue;
        }

        _runningProjectId = projectId;
        try {
          await _runJob(request);
        } catch (e) {
          _log(projectId, 'Job failed: $e');
          await _finalize(
            projectId,
            (jobs.value[projectId] ?? queuedState).copyWith(
              status: RenderJobStatus.failed,
              currentStage: 'Failed',
              error: e.toString(),
            ),
            project: request.project,
          );
        } finally {
          _runningProjectId = null;
        }
      }
    } finally {
      _isPumping = false;
      _recomputeActive();
    }
  }

  /// Output geometry for widescreen / copyright-remover renders.
  ///
  /// The source aspect ratio is preserved exactly and the result is only ever
  /// downscaled to fit the quality ceiling, so a 16:9 input always produces a
  /// 16:9 output and can never be reframed into a vertical canvas. Blindly
  /// forcing 1920x1080 would stretch any source that is not already 16:9.
  static (int, int) widescreenOutputSize(MediaProbeInfo probe, String quality) {
    final int maxW = quality == 'high' ? 1920 : 1280;
    final int maxH = quality == 'high' ? 1080 : 720;
    final int srcW = probe.width > 0 ? probe.width : maxW;
    final int srcH = probe.height > 0 ? probe.height : maxH;

    final double fit = math.min(maxW / srcW, maxH / srcH);
    final double scale = fit > 1.0 ? 1.0 : fit; // never upscale past the source

    int w = (srcW * scale).round();
    int h = (srcH * scale).round();
    if (w.isOdd) w -= 1; // H.264 requires even dimensions
    if (h.isOdd) h -= 1;
    return (math.max(w, 2), math.max(h, 2));
  }

  Future<void> _runJob(_RenderJobRequest request) async {
    if (request.project.mode == AppMode.songRemover) {
      return _runSongRemoverJob(request);
    }

    final project = request.project;
    final projectId = project.id;
    final tracker = SubjectTrackerService();
    final List<String> renderedPaths = [];
    final List<String> clipErrors = [];
    String? firstThumbnail;

    RenderJobState state = jobs.value[projectId]!;
    void update(RenderJobState next) {
      state = next;
      _emit(next);
    }

    update(state.copyWith(
      status: RenderJobStatus.rendering,
      currentStage: 'Preparing render session',
      progress: 0.0,
    ));
    project.status = ProjectStatus.rendering;
    await ProjectStorageService.saveProject(project);

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final outputDir = Directory(path.join(appDir.path, 'ClipShield_Rendered'));
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      final clips = request.clipsToRender;
      final int totalClips = clips.length;
      final bool isWidescreenMode = project.mode == AppMode.transformAndProtect ||
          request.aspectRatio == AspectRatioOption.original169;

      for (int i = 0; i < totalClips; i++) {
        if (_cancelRequests.contains(projectId)) break;

        final clip = clips[i];
        final double baseWeight = i / totalClips;
        final double clipWeight = 1.0 / totalClips;

        _log(projectId, 'Processing clip ${i + 1}/$totalClips: ${clip.title}');
        if (isWidescreenMode) {
          _log(projectId,
              'Widescreen mode: preserving source aspect ${request.probeInfo.width}x${request.probeInfo.height}.');
        }
        update(state.copyWith(
          progress: baseWeight,
          currentStage: 'Clip ${i + 1} of $totalClips - preparing',
        ));

        // 1. Crop coordinates
        String cropCoords;
        if (isWidescreenMode) {
          cropCoords = '${request.probeInfo.width}:${request.probeInfo.height}:0:0';
        } else if (request.enableSubjectTracking) {
          cropCoords = await tracker.calculateOptimalCrop(
            videoPath: request.sourceVideoPath,
            startTime: clip.startTime,
            endTime: clip.endTime,
            sourceWidth: request.probeInfo.width,
            sourceHeight: request.probeInfo.height,
            aspectOption: request.aspectRatio,
            logCallback: (m) => _log(projectId, m),
          );
        } else {
          final targetW = (request.probeInfo.height * request.aspectRatio.ratio).round();
          final defaultX = ((request.probeInfo.width - targetW) / 2)
              .round()
              .clamp(0, request.probeInfo.width - targetW);
          cropCoords = '$targetW:${request.probeInfo.height}:$defaultX:0';
        }
        clip.cropCoordinates = cropCoords;

        // 2. Output geometry
        final int outW;
        final int outH;
        if (isWidescreenMode) {
          final size = widescreenOutputSize(request.probeInfo, request.quality);
          outW = size.$1;
          outH = size.$2;
        } else {
          outW = request.quality == 'high' ? 1080 : 720;
          outH = request.quality == 'high' ? 1920 : 1280;
        }

        final filterContext = FilterContext(
          sourceWidth: request.probeInfo.width,
          sourceHeight: request.probeInfo.height,
          duration: clip.durationSeconds,
          hasAudio: request.probeInfo.hasAudio,
          quality: request.quality,
          targetWidth: outW,
          targetHeight: outH,
          cropCoordinates: cropCoords,
          isPreview: false,
        );

        // 3. Render
        final outName = 'ClipShield_${DateTime.now().millisecondsSinceEpoch}_${i + 1}.mp4';
        final outPath = path.join(outputDir.path, outName);

        try {
          await _ffmpegService.renderClip(
            inputPath: request.sourceVideoPath,
            outputPath: outPath,
            startTime: clip.startTime,
            endTime: clip.endTime,
            pipeline: request.pipeline,
            context: filterContext,
            onProgress: (p, stage) {
              if (_cancelRequests.contains(projectId)) return;
              update(state.copyWith(
                progress: (baseWeight + (p * clipWeight)).clamp(0.0, 0.99),
                currentStage: 'Clip ${i + 1} of $totalClips - $stage',
              ));
            },
            logCallback: (m) => _log(projectId, m),
          );
        } catch (clipErr) {
          clipErrors.add('Clip ${i + 1}: $clipErr');
          _log(projectId, 'Clip ${i + 1} render error: $clipErr');
        }

        if (_cancelRequests.contains(projectId)) break;

        // 4. Only an artifact that exists on disk counts as rendered.
        final outputFile = File(outPath);
        if (await outputFile.exists() && await outputFile.length() > 1024) {
          clip.outputPath = outPath;
          clip.isRendered = true;
          renderedPaths.add(outPath);

          final thumbName = 'thumb_${DateTime.now().millisecondsSinceEpoch}_${i + 1}.jpg';
          final thumbPath = path.join(outputDir.path, thumbName);
          try {
            await _ffmpegService.extractThumbnail(videoPath: outPath, thumbnailPath: thumbPath);
            clip.thumbnailPath = thumbPath;
            firstThumbnail ??= thumbPath;
          } catch (_) {}

          try {
            await GalleryExportService.exportToPublicGallery(outPath);
          } catch (_) {}
        } else {
          clip.isRendered = false;
          clipErrors.add('Clip ${i + 1}: no output file was produced');
          _log(projectId, 'Clip ${i + 1} produced no usable output.');
        }

        // Persist partial progress so history survives an app restart.
        project.clips = clips;
        project.outputPaths = List.of(renderedPaths);
        project.thumbnailPath = firstThumbnail;
        await ProjectStorageService.saveProject(project);

        update(state.copyWith(
          renderedClips: renderedPaths.length,
          outputPaths: List.of(renderedPaths),
        ));
      }

      if (_cancelRequests.contains(projectId)) {
        await _finalize(
          projectId,
          state.copyWith(
            status: RenderJobStatus.canceled,
            currentStage: 'Canceled',
            outputPaths: List.of(renderedPaths),
          ),
          project: project,
        );
        return;
      }

      // A job is complete only when every requested clip produced a file.
      final bool allRendered = totalClips > 0 && renderedPaths.length == totalClips;
      if (allRendered) {
        await LicenseService.instance.consumeTrial();
        await _finalize(
          projectId,
          state.copyWith(
            status: RenderJobStatus.completed,
            progress: 1.0,
            currentStage: 'Completed',
            renderedClips: renderedPaths.length,
            outputPaths: List.of(renderedPaths),
          ),
          project: project,
        );
      } else {
        await _finalize(
          projectId,
          state.copyWith(
            status: RenderJobStatus.failed,
            currentStage: 'Failed',
            renderedClips: renderedPaths.length,
            outputPaths: List.of(renderedPaths),
            error: clipErrors.isEmpty
                ? 'Render produced ${renderedPaths.length} of $totalClips clips.'
                : clipErrors.join('\n'),
          ),
          project: project,
        );
      }
    } finally {
      tracker.dispose();
    }
  }

  Future<void> _runSongRemoverJob(_RenderJobRequest request) async {
    final project = request.project;
    final projectId = project.id;
    final ts = DateTime.now().millisecondsSinceEpoch;
    
    RenderJobState state = jobs.value[projectId]!;
    void update(RenderJobState next) {
      state = next;
      _emit(next);
    }
    
    update(state.copyWith(
      status: RenderJobStatus.rendering,
      currentStage: 'Preparing render session',
      progress: 0.0,
    ));
    project.status = ProjectStatus.rendering;
    await ProjectStorageService.saveProject(project);
    
    try {
      final config = AudioDspConfig.fromMap(project.settings['dspConfig'] ?? {});
      final String? coverImagePath = project.settings['coverImagePath'];
      final bool isWidescreen = project.settings['isWidescreen'] ?? true;
      
      final appDir = await getApplicationDocumentsDirectory();
      final outputDir = Directory(path.join(appDir.path, 'ClipShield_Songs'));
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }
      
      final audioPath = path.join(outputDir.path, 'processed_audio_$ts.m4a');
      final videoPath = path.join(outputDir.path, 'ClipShield_Song_$ts.mp4');
      final thumbPath = path.join(outputDir.path, 'thumb_$ts.jpg');
      
      update(state.copyWith(progress: 0.1, currentStage: 'Processing audio'));
      await _ffmpegService.renderSongRemoverAudio(
        inputPath: request.sourceVideoPath,
        outputPath: audioPath,
        config: config,
        audioDuration: request.probeInfo.duration,
        sourceSampleRate: request.probeInfo.audioSampleRate,
        sourceChannels: request.probeInfo.audioChannels,
        onProgress: (p, s) {
          if (_cancelRequests.contains(projectId)) return;
          update(state.copyWith(progress: 0.1 + (p * 0.4), currentStage: 'Processing audio'));
        },
        logCallback: (m) => _log(projectId, m),
      );
      
      if (_cancelRequests.contains(projectId)) throw Exception("Canceled");
      
      update(state.copyWith(progress: 0.5, currentStage: 'Composing video'));
      await _ffmpegService.composeCoverVideo(
        imagePath: coverImagePath!,
        audioPath: audioPath,
        outputPath: videoPath,
        isWidescreen: isWidescreen,
        onProgress: (p, s) {
          if (_cancelRequests.contains(projectId)) return;
          update(state.copyWith(progress: 0.5 + (p * 0.4), currentStage: 'Composing video'));
        },
        logCallback: (m) => _log(projectId, m),
      );
      
      if (_cancelRequests.contains(projectId)) throw Exception("Canceled");
      
      update(state.copyWith(progress: 0.9, currentStage: 'Extracting thumbnail'));
      try {
        await _ffmpegService.extractThumbnail(videoPath: videoPath, thumbnailPath: thumbPath);
      } catch (_) {}
      
      final composed = File(videoPath);
      if (!await composed.exists() || await composed.length() <= 1024) {
        throw Exception("Encoder produced no usable output file.");
      }
      
      update(state.copyWith(progress: 0.95, currentStage: 'Exporting to gallery'));
      try {
        await GalleryExportService.exportToPublicGallery(videoPath);
      } catch (_) {}
      
      final clip = request.clipsToRender.first;
      clip.outputPath = videoPath;
      clip.thumbnailPath = thumbPath;
      clip.isRendered = true;
      
      project.clips = [clip];
      project.outputPaths = [videoPath];
      project.thumbnailPath = thumbPath;
      
      await LicenseService.instance.consumeTrial();
      await _finalize(
        projectId,
        state.copyWith(
          status: RenderJobStatus.completed,
          progress: 1.0,
          currentStage: 'Completed',
          renderedClips: 1,
          outputPaths: [videoPath],
        ),
        project: project,
      );
    } catch (e) {
      if (_cancelRequests.contains(projectId)) {
        await _finalize(
          projectId,
          state.copyWith(status: RenderJobStatus.canceled, currentStage: 'Canceled', error: null),
          project: project,
        );
      } else {
        await _finalize(
          projectId,
          state.copyWith(status: RenderJobStatus.failed, currentStage: 'Failed', error: e.toString()),
          project: project,
        );
      }
    }
  }

  /// Writes the terminal state to both the live map and persistent storage, so
  /// the UI and disk can never disagree about whether a project is ready.
  Future<void> _finalize(String projectId, RenderJobState state, {ProjectItem? project}) async {
    final target = project ?? await _loadProject(projectId);
    if (target != null) {
      target.status = state.status.projectStatus;
      target.outputPaths = List.of(state.outputPaths);
      target.settings['renderError'] =
          state.status == RenderJobStatus.completed ? null : state.error;
      try {
        await ProjectStorageService.saveProject(target);
      } catch (_) {}
    }
    _cancelRequests.remove(projectId);
    _emit(state);
  }

  Future<ProjectItem?> _loadProject(String projectId) async {
    final all = await ProjectStorageService.loadProjects();
    for (final p in all) {
      if (p.id == projectId) return p;
    }
    return null;
  }
}
