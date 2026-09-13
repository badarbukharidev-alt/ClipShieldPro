import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_modes.dart';
import '../models/project_model.dart';
import '../models/source_metadata.dart';
import '../services/downloader_service.dart';
import '../services/highlight_detector_service.dart';
import '../services/media_probe_service.dart';
import '../services/project_storage_service.dart';
import '../theme/app_theme.dart';
import 'clips_screen.dart';

class AnalysisScreen extends StatefulWidget {
  final AppMode mode;
  final SourceType sourceType;
  final String source;

  /// Metadata already resolved on the dashboard, carried through so the results
  /// screen can offer the title, description and keywords without refetching.
  final SourceMetadata? metadata;

  const AnalysisScreen({
    super.key,
    required this.mode,
    required this.sourceType,
    required this.source,
    this.metadata,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final DownloaderService _downloader = DownloaderService();
  final HighlightDetectorService _detector = HighlightDetectorService();

  double _progress = 0.0;
  String _statusMessage = "Initializing media probe...";
  int _currentStepIndex = 0;
  bool _isCanceled = false;

  final List<String> _stepLabels = [
    "Scanning footage & stream tracks",
    "Extracting transcripts & captions",
    "AI hook detection & moment scoring",
    "Validating clips & ranking viral candidates",
  ];

  @override
  void initState() {
    super.initState();
    _startAnalysisPipeline();
  }

  @override
  void dispose() {
    _downloader.dispose();
    super.dispose();
  }

  Future<void> _startAnalysisPipeline() async {
    try {
      String localVideoPath = widget.source;
      final tempDir = await getTemporaryDirectory();
      final downloadDir = "${tempDir.path}/clipshield_source";

      // Step 0: Ingestion / Download
      setState(() {
        _currentStepIndex = 0;
        _progress = 0.15;
        _statusMessage = "Analyzing media source...";
      });

      if (widget.sourceType == SourceType.youtubeUrl) {
        setState(() => _statusMessage = "Fetching remote stream metadata...");
        localVideoPath = await _downloader.downloadVideo(
          url: widget.source,
          downloadDir: downloadDir,
          quality: 'balanced',
          progressCallback: (p, msg) {
            if (!_isCanceled) {
              setState(() {
                _progress = 0.15 + (p * 0.35);
                _statusMessage = msg;
              });
            }
          },
        );
      }

      if (_isCanceled) return;

      // Step 1: Media Probing & Transcript
      setState(() {
        _currentStepIndex = 1;
        _progress = 0.55;
        _statusMessage = "Probing video dimensions & audio presence...";
      });

      final probeInfo = await MediaProbeService.probe(localVideoPath);
      String? transcript;

      if (widget.sourceType == SourceType.youtubeUrl) {
        transcript = await _downloader.fetchSubtitles(widget.source, (msg) {
          if (!_isCanceled) setState(() => _statusMessage = msg);
        });
      }

      if (_isCanceled) return;

      // Step 2: AI Moment Detection
      setState(() {
        _currentStepIndex = 2;
        _progress = 0.75;
        _statusMessage = "AI analyzing narrative inflection points...";
      });

      final geminiKey = await ProjectStorageService.getGeminiApiKey();
      final openRouterKey = await ProjectStorageService.getOpenRouterApiKey();
      final groqKey = await ProjectStorageService.getGroqApiKey();
      final cerebrasKey = await ProjectStorageService.getCerebrasApiKey();
      final selectedProvider = await ProjectStorageService.getSelectedAiProvider();

      final detectedClips = await _detector.analyzeTranscriptAndDetectHighlights(
        totalDuration: probeInfo.duration,
        transcript: transcript,
        targetClipCount: 5,
        preferredDuration: 45.0,
        provider: selectedProvider,
        geminiApiKey: geminiKey,
        openRouterApiKey: openRouterKey,
        groqApiKey: groqKey,
        cerebrasApiKey: cerebrasKey,
        logCallback: (msg) {
          if (!_isCanceled) setState(() => _statusMessage = msg);
        },
      );

      if (_isCanceled) return;

      // Step 3: Final ranking & compilation
      setState(() {
        _currentStepIndex = 3;
        _progress = 1.0;
        _statusMessage = "Clips prepared successfully!";
      });

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      final project = ProjectItem(
        id: "proj_${DateTime.now().millisecondsSinceEpoch}",
        mode: widget.mode,
        title: widget.sourceType == SourceType.youtubeUrl
            ? "YouTube ClipShield Project"
            : widget.source.split('/').last.split('\\').last,
        sourceUrlOrPath: localVideoPath,
        sourceType: widget.sourceType,
        clips: detectedClips,
        status: ProjectStatus.draft,
      );
      if (widget.metadata != null) {
        project.settings['sourceMeta'] = widget.metadata!.toMap();
        project.title = widget.metadata!.title;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ClipsScreen(
            project: project,
            sourceVideoPath: localVideoPath,
            probeInfo: probeInfo,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text("Analysis failed: $e"),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int pct = (_progress * 100).toInt();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                "Analyzing Your Video",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Finding the moments most likely to pop",
                style: TextStyle(fontSize: 14, color: AppColors.mut),
              ),
              const SizedBox(height: 36),

              // Rotating circular percentage widget
              Center(
                child: SizedBox(
                  width: 190,
                  height: 190,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 170,
                        height: 170,
                        child: CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 12,
                          backgroundColor: AppColors.softTangerine,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentTangerine),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                "$pct",
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              const Text(
                                "%",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.mut,
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            "processing",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mut,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // 4 Steps Card
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.line),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: List.generate(_stepLabels.length, (index) {
                    final bool isDone = index < _currentStepIndex;
                    final bool isActive = index == _currentStepIndex;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDone
                                  ? AppColors.accentTangerine
                                  : (isActive ? AppColors.softTangerine : AppColors.line.withOpacity(0.3)),
                            ),
                            child: isDone
                                ? const Icon(Icons.check, size: 16, color: Colors.white)
                                : (isActive
                                    ? Center(
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.accentTangerine,
                                          ),
                                        ),
                                      )
                                    : null),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              _stepLabels[index],
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
                  }),
                ),
              ),

              const SizedBox(height: 16),
              Text(
                _statusMessage,
                style: const TextStyle(fontSize: 12, color: AppColors.mut, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const Spacer(),

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
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
