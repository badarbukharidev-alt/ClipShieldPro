import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_modes.dart';
import '../models/clip_model.dart';
import '../models/project_model.dart';
import '../models/source_metadata.dart';
import '../services/downloader_service.dart';
import '../services/license_service.dart';
import '../services/media_probe_service.dart';
import '../services/render_job_service.dart';
import '../transformation/layer.dart';
import '../transformation/pipeline.dart';
import '../theme/app_theme.dart';
import '../widgets/source_acquire_view.dart';
import 'activation_dialog.dart';
import 'processing_screen.dart';

class TransformPipelineScreen extends StatefulWidget {
  final String sourceVideoPathOrUrl;
  final SourceType sourceType;

  /// Preset chosen on the dashboard, so the choice the user already made is not
  /// asked for a second time.
  final PipelinePreset initialPreset;

  /// Metadata already resolved on the dashboard, carried through so the results
  /// screen can offer the title, description and keywords without refetching.
  final SourceMetadata? metadata;

  const TransformPipelineScreen({
    super.key,
    required this.sourceVideoPathOrUrl,
    required this.sourceType,
    this.initialPreset = PipelinePreset.balanced,
    this.metadata,
  });

  @override
  State<TransformPipelineScreen> createState() => _TransformPipelineScreenState();
}

class _TransformPipelineScreenState extends State<TransformPipelineScreen> {
  final TransformationPipeline _pipeline = TransformationPipeline();
  final DownloaderService _downloader = DownloaderService();

  MediaProbeInfo? _probeInfo;
  String? _localVideoPath;
  bool _isLoading = true;
  String _loadingMessage = "Inspecting media streams...";

  late PipelinePreset _selectedPreset = widget.initialPreset;
  double _globalIntensity = 0.5;
  final AspectRatioOption _aspectRatio = AspectRatioOption.original169;
  double? _acquireProgress;

  /// The twelve layers and the intensity slider are collapsed by default. The
  /// preset already sets them correctly, and confronting someone with twelve
  /// switches the moment their download finishes is how a one-tap action turns
  /// into a configuration screen.
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    // Honour the preset picked on the dashboard, including its layer config.
    _pipeline.applyPreset(widget.initialPreset);
    _globalIntensity = _pipeline.globalIntensity;
    _initializeSource();
  }

  @override
  void dispose() {
    _downloader.dispose();
    super.dispose();
  }

  Future<void> _initializeSource() async {
    try {
      if (widget.sourceType == SourceType.youtubeUrl) {
        setState(() => _loadingMessage = "Downloading source stream...");
        final tempDir = await getTemporaryDirectory();
        final downloadDir = "${tempDir.path}/clipshield_transform_source";
        _localVideoPath = await _downloader.downloadVideo(
          url: widget.sourceVideoPathOrUrl,
          downloadDir: downloadDir,
          quality: 'balanced',
          progressCallback: (p, msg) {
            if (!mounted) return;
            setState(() {
              _loadingMessage = msg;
              _acquireProgress = p;
            });
          },
        );
      } else {
        _localVideoPath = widget.sourceVideoPathOrUrl;
      }

      if (!mounted) return;
      setState(() {
        _loadingMessage = "Probing video tracks...";
        _acquireProgress = 0.95;
      });
      _probeInfo = await MediaProbeService.probe(_localVideoPath!);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text("Failed to initialize media: $e")),
      );
      Navigator.pop(context);
    }
  }

  void _onPresetChanged(PipelinePreset preset) {
    setState(() {
      _selectedPreset = preset;
      _pipeline.applyPreset(preset);
      _globalIntensity = _pipeline.globalIntensity;
    });
  }

  void _onIntensityChanged(double val) {
    setState(() {
      _globalIntensity = val;
      _pipeline.setGlobalIntensity(val);
      _selectedPreset = PipelinePreset.custom;
    });
  }

  bool _isSubmitting = false;

  Future<void> _startFullRender() async {
    if (_localVideoPath == null || _probeInfo == null || _isSubmitting) return;

    // License is checked before the job is queued, not mid-render.
    if (!LicenseService.instance.canRender()) {
      final activated = await ActivationDialog.show(context);
      if (!mounted || !activated) return;
    }

    setState(() => _isSubmitting = true);

    final clip = ClipItem(
      id: "transform_clip_${DateTime.now().millisecondsSinceEpoch}",
      title: "Materially Transformed Asset",
      duration: "${_probeInfo!.duration.toInt()}s",
      startTime: 0.0,
      endTime: _probeInfo!.duration,
      score: 95,
      tag: "Shielded",
      cropCoordinates: "${_probeInfo!.width}:${_probeInfo!.height}:0:0",
    );

    final project = ProjectItem(
      id: "transform_proj_${DateTime.now().millisecondsSinceEpoch}",
      mode: AppMode.transformAndProtect,
      title: widget.sourceType == SourceType.youtubeUrl
          ? "Protected Stream Export"
          : _localVideoPath!.split('/').last.split('\\').last,
      sourceUrlOrPath: _localVideoPath!,
      sourceType: widget.sourceType,
      clips: [clip],
      preset: _selectedPreset,
      aspectRatio: _aspectRatio,
    );
    if (widget.metadata != null) {
      project.settings['sourceMeta'] = widget.metadata!.toMap();
      project.title = widget.metadata!.title;
    }

    final projectId = await RenderJobService.instance.submit(
      project: project,
      sourceVideoPath: _localVideoPath!,
      probeInfo: _probeInfo!,
      clipsToRender: [clip],
      pipeline: _pipeline,
      aspectRatio: _aspectRatio,
      enableSubjectTracking: false,
      quality: _selectedPreset == PipelinePreset.advanced ? 'high' : 'balanced',
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProcessingScreen(
          projectId: projectId,
          mode: project.mode,
          title: project.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SourceAcquireView(
        title: widget.sourceType == SourceType.youtubeUrl
            ? "Fetching Source Stream"
            : "Preparing Source",
        stageMessage: _loadingMessage,
        progress: widget.sourceType == SourceType.youtubeUrl ? _acquireProgress : null,
        metadata: widget.metadata,
        accent: AppColors.accentGrape,
        onCancel: () => Navigator.maybePop(context),
      );
    }

    final layers = _pipeline.allLayers;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text("Long Video Copyright Remover", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Preset Selector: FAST, BALANCED, ADVANCED
                  const Text(
                    "PROCESSING PRESET",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.mut, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildPresetChip(PipelinePreset.fast, "FAST", "Speed Priority"),
                      const SizedBox(width: 8),
                      _buildPresetChip(PipelinePreset.balanced, "BALANCED", "Recommended"),
                      const SizedBox(width: 8),
                      _buildPresetChip(PipelinePreset.advanced, "ADVANCED", "Deep Filtergraph"),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Advanced disclosure. Everything below is optional: the
                  // preset already configured it.
                  _buildAdvancedToggle(layers),

                  if (_showAdvanced) ...[
                    const SizedBox(height: 14),
                    // Global Intensity Card
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.line),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.tune, color: AppColors.accentGrape, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    "Transformation Intensity",
                                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                                  ),
                                ],
                              ),
                              Text(
                                "${(_globalIntensity * 100).toInt()}%",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accentGrape,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            min: 0.1,
                            max: 1.0,
                            value: _globalIntensity,
                            activeColor: AppColors.accentGrape,
                            onChanged: _onIntensityChanged,
                          ),
                          const Text(
                            "Controls pitch modulation, chromatic grading depth, EQ variance, and spatial delays.",
                            style: TextStyle(fontSize: 11.5, color: AppColors.mut, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 9-Layer Modular List Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "MODULAR PROCESSING LAYERS (12)",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.mut, letterSpacing: 1.2),
                        ),
                        Text(
                          "${layers.where((l) => l.isEnabled).length}/12 Active",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentGrape),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 9-Layer List
                    ...layers.map((layer) => _buildLayerCard(layer)),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Bottom action bar. One action: the preview was removed because
          // it re-encoded a five-second segment with the full filtergraph just
          // to be discarded, which on a phone costs about as much as a real
          // render of the same span.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _startFullRender,
                  icon: const Icon(Icons.shield_rounded, size: 19),
                  label: Text(
                    _isSubmitting ? "Queueing..." : "Remove Copyright",
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    backgroundColor: AppColors.accentGrape,
                    disabledBackgroundColor: AppColors.line,
                    disabledForegroundColor: AppColors.mut,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Row that opens the twelve-layer configuration. Collapsed it states what is
  /// active, so hiding the detail does not hide the fact that work is happening.
  Widget _buildAdvancedToggle(List<TransformationLayer> layers) {
    final int active = layers.where((l) => l.isEnabled).length;

    return GestureDetector(
      onTap: () => setState(() => _showAdvanced = !_showAdvanced),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _showAdvanced ? AppColors.accentGrape : AppColors.line,
            width: _showAdvanced ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.tune_rounded,
              size: 20,
              color: _showAdvanced ? AppColors.accentGrape : AppColors.mut,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Advanced",
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "$active of ${layers.length} layers active at ${(_globalIntensity * 100).toInt()}% intensity",
                    style: const TextStyle(fontSize: 11.5, color: AppColors.mut),
                  ),
                ],
              ),
            ),
            Icon(
              _showAdvanced ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: AppColors.mut,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(PipelinePreset preset, String title, String subtitle) {
    final bool isSel = _selectedPreset == preset;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onPresetChanged(preset),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSel ? AppColors.accentGrape : AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSel ? AppColors.accentGrape : AppColors.line,
              width: 1.5,
            ),
            boxShadow: isSel
                ? [
                    BoxShadow(
                      color: AppColors.accentGrape.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: isSel ? Colors.white : AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: isSel ? Colors.white.withOpacity(0.8) : AppColors.mut,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayerCard(TransformationLayer layer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: layer.isEnabled ? AppColors.line : AppColors.line.withOpacity(0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: layer.isEnabled ? AppColors.softGrape : AppColors.line.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                layer.layerNumber.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: layer.isEnabled ? AppColors.accentGrape : AppColors.mut,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  layer.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: layer.isEnabled ? AppColors.ink : AppColors.mut,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  layer.subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.mut,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: layer.isEnabled,
            activeColor: AppColors.accentGrape,
            onChanged: (val) {
              setState(() {
                layer.isEnabled = val;
                _selectedPreset = PipelinePreset.custom;
              });
            },
          ),
        ],
      ),
    );
  }
}
