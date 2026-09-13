import 'package:flutter/material.dart';
import '../models/app_modes.dart';
import '../models/caption_style.dart';
import '../models/clip_model.dart';
import '../models/project_model.dart';
import '../services/license_service.dart';
import '../services/media_probe_service.dart';
import '../services/render_job_service.dart';
import '../transformation/pipeline.dart';
import '../theme/app_theme.dart';
import 'activation_dialog.dart';
import 'processing_screen.dart';

class CustomizeScreen extends StatefulWidget {
  final ProjectItem project;
  final String sourceVideoPath;
  final MediaProbeInfo probeInfo;
  final List<ClipItem> selectedClips;

  const CustomizeScreen({
    super.key,
    required this.project,
    required this.sourceVideoPath,
    required this.probeInfo,
    required this.selectedClips,
  });

  @override
  State<CustomizeScreen> createState() => _CustomizeScreenState();
}

class _CustomizeScreenState extends State<CustomizeScreen> {
  AspectRatioOption _aspectRatio = AspectRatioOption.vertical916;
  bool _subjectTracking = true;
  bool _autoCaptions = true;
  CaptionStylePreset _captionStyle = CaptionPresets.hormozi;

  /// Captions can only be burned in when the source actually supplied any.
  bool get _hasCaptionSource => widget.project.captionCues.isNotEmpty;
  bool _enhanceAudioVideo = true;
  double _transformationStrength = 45.0; // 10 to 90%
  final String _resolution = "1080p";

  bool _isSubmitting = false;

  Future<void> _startRender() async {
    if (_isSubmitting) return;
    if (widget.selectedClips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one clip to render")),
      );
      return;
    }

    // License is checked before the job is queued, not mid-render.
    if (!LicenseService.instance.canRender()) {
      final activated = await ActivationDialog.show(context);
      if (!mounted || !activated) return;
    }

    setState(() => _isSubmitting = true);

    final pipeline = TransformationPipeline();
    pipeline.setGlobalIntensity(_transformationStrength / 100.0);

    // Synchronize user preferences with pipeline layers
    pipeline.resampling.isEnabled = true;
    pipeline.color.isEnabled = _enhanceAudioVideo;
    pipeline.parametricEq.isEnabled = _enhanceAudioVideo;
    pipeline.harmonicAudio.isEnabled = true;
    pipeline.codecNormalization.isEnabled = true;

    // One submission == one history entry, carrying only the selected clips.
    final renderProject = widget.project.copyForRender(
      clipsToRender: widget.selectedClips,
      aspectRatio: _aspectRatio,
    );

    final projectId = await RenderJobService.instance.submit(
      project: renderProject,
      sourceVideoPath: widget.sourceVideoPath,
      probeInfo: widget.probeInfo,
      clipsToRender: renderProject.clips,
      pipeline: pipeline,
      aspectRatio: _aspectRatio,
      enableSubjectTracking: _subjectTracking,
      quality: _resolution == "1080p" ? "high" : "balanced",
      captionCues:
          (_autoCaptions && _hasCaptionSource) ? widget.project.captionCues : const [],
      captionStyle: (_autoCaptions && _hasCaptionSource) ? _captionStyle : null,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProcessingScreen(
          projectId: projectId,
          mode: renderProject.mode,
          title: renderProject.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text("Customize Shorts", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 16:9 Viewport with animated 9:16 Subject Tracking Box
                  Container(
                    width: double.infinity,
                    height: 190,
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Positioned(
                          top: 10,
                          left: 12,
                          child: Text(
                            "SOURCE 16:9 PREVIEW",
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        // 9:16 Viewport outline
                        Container(
                          width: 107, // 190 * (9/16)
                          height: 190,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.accentTangerine, width: 2.5),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.black.withOpacity(0.2),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentTangerine,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    "${_aspectRatio.label} · tracking",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              // Centroid marker
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.8),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.accentTangerine,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Aspect Ratio Selector Chips
                  Row(
                    children: [
                      _buildAspectChip(AspectRatioOption.vertical916, "9:16 (Shorts)"),
                      const SizedBox(width: 8),
                      _buildAspectChip(AspectRatioOption.vertical45, "4:5 (Feed)"),
                      const SizedBox(width: 8),
                      _buildAspectChip(AspectRatioOption.square11, "1:1 (Square)"),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Features Switch Group Card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.line),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(
                      children: [
                        _buildSwitchTile(
                          icon: Icons.face_retouching_natural,
                          title: "Subject Tracking",
                          subtitle: "Keep speaker centered via facial centroid",
                          value: _subjectTracking,
                          onChanged: (val) => setState(() => _subjectTracking = val),
                        ),
                        const Divider(height: 1, color: AppColors.line),
                        _buildSwitchTile(
                          icon: Icons.subtitles_outlined,
                          title: "Auto-Captions",
                          subtitle: _hasCaptionSource
                              ? "Burn in animated captions from the source"
                              : "No captions available for this video",
                          value: _autoCaptions && _hasCaptionSource,
                          onChanged: _hasCaptionSource
                              ? (val) => setState(() => _autoCaptions = val)
                              : null,
                        ),
                        if (_autoCaptions && _hasCaptionSource) _buildCaptionStyles(),
                        const Divider(height: 1, color: AppColors.line),
                        _buildSwitchTile(
                          icon: Icons.auto_fix_high,
                          title: "Enhance Audio & Video",
                          subtitle: "Harmonic leveling, color grade & sharpen",
                          value: _enhanceAudioVideo,
                          onChanged: (val) => setState(() => _enhanceAudioVideo = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Transformation Strength Slider Card
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
                                Icon(Icons.shield_outlined, size: 20, color: AppColors.accentTangerine),
                                SizedBox(width: 8),
                                Text(
                                  "Transformation Strength",
                                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                                ),
                              ],
                            ),
                            Text(
                              "${_transformationStrength.toInt()}%",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accentTangerine,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          min: 10,
                          max: 90,
                          value: _transformationStrength,
                          onChanged: (val) => setState(() => _transformationStrength = val),
                        ),
                        const Text(
                          "Re-frames, re-times, and re-styles authorized footage. Higher intensity introduces deeper geometric, color, and audio modulation.",
                          style: TextStyle(fontSize: 12, color: AppColors.mut, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Render Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _startRender,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: AppColors.accentTangerine,
                ),
                child: Text(
                  _isSubmitting
                      ? "Queueing..."
                      : "Render ${widget.selectedClips.length} ${widget.selectedClips.length == 1 ? 'Short' : 'Shorts'}",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptionStyles() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "CAPTION STYLE",
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: AppColors.mut,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 92,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: CaptionPresets.all.length,
              itemBuilder: (context, index) {
                final preset = CaptionPresets.all[index];
                final isSel = _captionStyle.id == preset.id;

                return GestureDetector(
                  onTap: () => setState(() => _captionStyle = preset),
                  child: Container(
                    width: 132,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSel ? AppColors.darkCard : AppColors.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSel ? preset.swatch : AppColors.line,
                        width: isSel ? 1.6 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Miniature of the actual look.
                        Row(
                          children: [
                            Text(
                              "Aa",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: preset.bold ? FontWeight.w900 : FontWeight.w600,
                                color: isSel ? Colors.white : AppColors.ink,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              "Bb",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: preset.bold ? FontWeight.w900 : FontWeight.w600,
                                color: preset.swatch,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          preset.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isSel ? Colors.white : AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Expanded(
                          child: Text(
                            preset.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.25,
                              color: isSel ? Colors.white70 : AppColors.mut,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAspectChip(AspectRatioOption opt, String label) {
    final bool isSel = _aspectRatio == opt;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _aspectRatio = opt),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSel ? AppColors.softTangerine : AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSel ? AppColors.accentTangerine : AppColors.line,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              opt.label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isSel ? AppColors.accentTangerine : AppColors.mut,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    // Nullable so a tile can render disabled when the option is unavailable.
    required ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.softTangerine,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.accentTangerine, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.mut)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
