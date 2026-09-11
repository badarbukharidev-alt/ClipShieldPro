import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/app_modes.dart';
import '../models/clip_model.dart';
import '../models/project_model.dart';
import '../services/ffmpeg_engine_service.dart';
import '../services/media_probe_service.dart';
import '../services/project_storage_service.dart';
import '../services/subject_tracker_service.dart';
import '../transformation/layer.dart';
import '../transformation/pipeline.dart';
import '../theme/app_theme.dart';
import '../services/license_service.dart';
import '../services/render_job_service.dart';
import '../services/gallery_export_service.dart';
import 'activation_dialog.dart';
import 'results_screen.dart';

class ProcessingScreen extends StatefulWidget {
  final ProjectItem project;
  final String sourceVideoPath;
  final MediaProbeInfo probeInfo;
  final List<ClipItem> clipsToRender;
  final TransformationPipeline pipeline;
  final AspectRatioOption aspectRatio;
  final bool enableSubjectTracking;
  final String quality;

  const ProcessingScreen({
    super.key,
    required this.project,
    required this.sourceVideoPath,
    required this.probeInfo,
    required this.clipsToRender,
    required this.pipeline,
    required this.aspectRatio,
    required this.enableSubjectTracking,
    this.quality = 'balanced',
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  final FfmpegEngineService _ffmpegService = FfmpegEngineService();
  final SubjectTrackerService _trackerService = SubjectTrackerService();

  double _totalProgress = 0.0;
  String _currentStepLabel = "Starting render session...";
  int _currentClipIndex = 0;
  final List<String> _logs = [];
  bool _isCanceled = false;

  List<String> get _pipelineSteps => widget.project.mode == AppMode.transformAndProtect
      ? const [
          "Analyzing source media",
          "Applying audio transformations",
          "Geometric perturbation layer",
          "Color & gamma defense layer",
          "Blur & ambient layers",
          "Encoding protected output",
        ]
      : widget.project.mode == AppMode.songRemover
          ? const [
              "Extracting audio stream",
              "Applying DSP transformations",
              "Processing output mode",
              "Compositing cover image",
              "Encoding final output",
              "Generating thumbnail",
            ]
          : const [
          "Probing & source verification",
          "Aspect reframing & boundary clamping",
          "Facial centroid subject tracking",
          "Parametric equalization & pitch modulation",
          "Applying chromatic & geometric layers",
          "H.264 transcoding & thumbnail export",
        ];

  @override
  void initState() {
    super.initState();
    _executeRenderPipeline();
  }

  @override
  void dispose() {
    _trackerService.dispose();
    super.dispose();
  }

  void _addLog(String msg) {
    setState(() {
      _logs.add(msg);
      _currentStepLabel = msg;
    });
  }

  Future<void> _executeRenderPipeline() async {
    final List<String> renderedPaths = [];
    try {
      // Verify license / trial render permission
      final canRender = LicenseService.instance.canRender();
      if (!canRender) {
        if (!mounted) return;
        final activated = await ActivationDialog.show(context);
        if (!mounted) return;
        if (!activated) {
          Navigator.pop(context);
          return;
        }
      }

      RenderJobService.instance.startJob(projectId: widget.project.id, title: widget.project.title);

      // Persist project immediately so it is registered in history
      widget.project.status = 'rendering';
      await ProjectStorageService.saveProject(widget.project);

      final appDir = await getApplicationDocumentsDirectory();
      final outputDir = Directory(path.join(appDir.path, "ClipShield_Rendered"));
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      final int totalClips = widget.clipsToRender.length;

      final bool isWidescreenMode = widget.project.mode == AppMode.transformAndProtect ||
          widget.aspectRatio == AspectRatioOption.original169;

      for (int i = 0; i < totalClips; i++) {
        if (_isCanceled) {
          RenderJobService.instance.cancelJob();
          return;
        }

        if (mounted) {
          setState(() {
            _currentClipIndex = i;
          });
        }

        final clip = widget.clipsToRender[i];
        final double baseWeight = i / totalClips;
        final double clipWeight = 1.0 / totalClips;

        _addLog("Processing Clip ${i + 1}/$totalClips: ${clip.title}");

        // 1. Calculate Crop Coordinates
        String cropCoords;
        if (isWidescreenMode) {
          // Strictly preserve full widescreen 16:9 canvas with ZERO face tracking
          cropCoords = "${widget.probeInfo.width}:${widget.probeInfo.height}:0:0";
        } else if (widget.enableSubjectTracking) {
          cropCoords = await _trackerService.calculateOptimalCrop(
            videoPath: widget.sourceVideoPath,
            startTime: clip.startTime,
            endTime: clip.endTime,
            sourceWidth: widget.probeInfo.width,
            sourceHeight: widget.probeInfo.height,
            aspectOption: widget.aspectRatio,
            logCallback: _addLog,
          );
        } else {
          final targetW = (widget.probeInfo.height * widget.aspectRatio.ratio).round();
          final defaultX = ((widget.probeInfo.width - targetW) / 2).round().clamp(0, widget.probeInfo.width - targetW);
          cropCoords = "$targetW:${widget.probeInfo.height}:$defaultX:0";
        }
        clip.cropCoordinates = cropCoords;

        // 2. Build Filter Context
        final int outW;
        final int outH;
        if (isWidescreenMode) {
          outW = widget.quality == 'high' ? 1920 : 1280;
          outH = widget.quality == 'high' ? 1080 : 720;
        } else {
          outW = widget.quality == 'high' ? 1080 : 720;
          outH = widget.quality == 'high' ? 1920 : 1280;
        }

        final filterContext = FilterContext(
          sourceWidth: widget.probeInfo.width,
          sourceHeight: widget.probeInfo.height,
          duration: clip.durationSeconds,
          hasAudio: widget.probeInfo.hasAudio,
          quality: widget.quality,
          targetWidth: outW,
          targetHeight: outH,
          cropCoordinates: cropCoords,
          isPreview: false,
        );

        // 3. Render Output
        final outName = "ClipShield_${DateTime.now().millisecondsSinceEpoch}_${i + 1}.mp4";
        final outPath = path.join(outputDir.path, outName);

        await _ffmpegService.renderClip(
          inputPath: widget.sourceVideoPath,
          outputPath: outPath,
          startTime: clip.startTime,
          endTime: clip.endTime,
          pipeline: widget.pipeline,
          context: filterContext,
          onProgress: (p, stage) {
            if (!_isCanceled) {
              final double overallProgress = baseWeight + (p * clipWeight);
              RenderJobService.instance.updateProgress(overallProgress, stage);
              if (mounted) {
                setState(() {
                  _totalProgress = overallProgress;
                });
              }
            }
          },
          logCallback: _addLog,
        );

        // 4. Extract Thumbnail
        final thumbName = "thumb_${DateTime.now().millisecondsSinceEpoch}_${i + 1}.jpg";
        final thumbPath = path.join(outputDir.path, thumbName);
        try {
          await _ffmpegService.extractThumbnail(videoPath: outPath, thumbnailPath: thumbPath);
          clip.thumbnailPath = thumbPath;
        } catch (_) {}

        clip.outputPath = outPath;
        clip.isRendered = true;
        renderedPaths.add(outPath);

        // Auto-export directly to Android device gallery
        try {
          await GalleryExportService.exportToPublicGallery(outPath);
        } catch (_) {}
      }

      if (_isCanceled) {
        RenderJobService.instance.cancelJob();
        return;
      }

      if (mounted) setState(() => _totalProgress = 1.0);

      // Save project to storage
      widget.project.status = 'done';
      widget.project.outputPaths = renderedPaths;
      if (renderedPaths.isNotEmpty && widget.clipsToRender.first.thumbnailPath != null) {
        widget.project.thumbnailPath = widget.clipsToRender.first.thumbnailPath;
      }
      await ProjectStorageService.saveProject(widget.project);
      await LicenseService.instance.consumeTrial();

      RenderJobService.instance.completeJob(renderedPaths);

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(
            project: widget.project,
            renderedClips: widget.clipsToRender,
          ),
        ),
      );
    } catch (e) {
      RenderJobService.instance.failJob(e.toString());

      // If at least one clip was successfully rendered, rescue and show results!
      if (renderedPaths.isNotEmpty) {
        widget.project.status = 'done';
        widget.project.outputPaths = renderedPaths;
        if (widget.clipsToRender.first.thumbnailPath != null) {
          widget.project.thumbnailPath = widget.clipsToRender.first.thumbnailPath;
        }
        try {
          await ProjectStorageService.saveProject(widget.project);
        } catch (_) {}

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResultsScreen(
              project: widget.project,
              renderedClips: widget.clipsToRender.where((c) => c.isRendered).toList(),
            ),
          ),
        );
        return;
      }

      // Save failed status so project is still visible and debuggable
      try {
        widget.project.status = 'failed';
        await ProjectStorageService.saveProject(widget.project);
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text("Render failed: $e")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int pct = (_totalProgress * 100).toInt().clamp(0, 100);
    final int activeStepIdx = (_totalProgress * _pipelineSteps.length).toInt().clamp(0, _pipelineSteps.length - 1);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final bool? shouldBackground = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.card,
            title: const Text("Run in Background?", style: TextStyle(color: AppColors.ink)),
            content: const Text("You can let this render in the background and continue using the app.", style: TextStyle(color: AppColors.mut)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel Render", style: TextStyle(color: AppColors.error)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Run in Background", style: TextStyle(color: AppColors.accentTangerine)),
              ),
            ],
          ),
        );
        if (!context.mounted) return;
        if (shouldBackground == true) {
          Navigator.pop(context); // Pop back to home
        } else if (shouldBackground == false) {
          _isCanceled = true;
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.ink),
            onPressed: () => Navigator.maybePop(context),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.minimize, color: AppColors.accentTangerine, size: 18),
              label: const Text("Run in Background", style: TextStyle(color: AppColors.accentTangerine)),
              onPressed: () => Navigator.maybePop(context),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
            child: Column(
              children: [
                const Text(
                  "Rendering Your Media",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Clip ${_currentClipIndex + 1} of ${widget.clipsToRender.length} · on-device media engine",
                  style: const TextStyle(fontSize: 13.5, color: AppColors.mut),
                ),
                const SizedBox(height: 28),

                // Animated Rendering Canvas
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentTangerine.withOpacity(0.18),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E1E28), Color(0xFF14141E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ambient radial glow
                      Positioned.fill(
                        child: Center(
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.accentTangerine.withOpacity(0.25),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Circular Progress Ring
                      SizedBox(
                        width: 96,
                        height: 96,
                        child: CircularProgressIndicator(
                          value: _totalProgress > 0 ? _totalProgress : null,
                          strokeWidth: 6,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentTangerine),
                        ),
                      ),
                      // Inner Percent Text & Chip
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "$pct%",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentTangerine.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "ON-DEVICE DSP",
                              style: TextStyle(
                                color: AppColors.accentTangerine,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 6 Pipeline Steps Card
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.line),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListView.builder(
                      itemCount: _pipelineSteps.length,
                      itemBuilder: (context, index) {
                        final bool isDone = index < activeStepIdx;
                        final bool isActive = index == activeStepIdx;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDone
                                      ? AppColors.accentTangerine
                                      : (isActive ? AppColors.softTangerine : AppColors.line.withOpacity(0.3)),
                                ),
                                child: isDone
                                    ? const Icon(Icons.check, size: 15, color: Colors.white)
                                    : (isActive
                                        ? const Center(
                                            child: SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.accentTangerine,
                                              ),
                                            ),
                                          )
                                        : null),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _pipelineSteps[index],
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDone || isActive ? AppColors.ink : AppColors.mut,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  _currentStepLabel,
                  style: const TextStyle(fontSize: 12, color: AppColors.mut, fontStyle: FontStyle.italic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),

                // Cancel button
                OutlinedButton(
                  onPressed: () {
                    _isCanceled = true;
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text("Cancel"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
