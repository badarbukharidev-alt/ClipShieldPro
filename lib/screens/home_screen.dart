import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../models/app_modes.dart';
import '../models/project_model.dart';
import '../services/downloader_service.dart';
import '../services/project_storage_service.dart';
import '../services/render_job_service.dart';
import '../theme/app_theme.dart';
import 'analysis_screen.dart';
import 'processing_screen.dart';
import 'projects_history_screen.dart';
import 'results_screen.dart';
import 'settings_screen.dart';
import 'song_remover_screen.dart';
import 'transform_pipeline_screen.dart';

/// Per-mode copy for the action card. Keeping it in one place means the
/// segment, the header label and the card can never disagree.
class _ModeSpec {
  final String headerLabel;
  final String badge;
  final String title;
  final String description;
  final String cta;
  final IconData icon;
  final String segmentLabel;

  /// Presets are only offered where they are actually wired through to the
  /// render. Showing a control that changes nothing is worse than omitting it.
  final bool supportsPreset;

  const _ModeSpec({
    required this.headerLabel,
    required this.badge,
    required this.title,
    required this.description,
    required this.cta,
    required this.icon,
    required this.segmentLabel,
    this.supportsPreset = false,
  });
}

const Map<AppMode, _ModeSpec> _modeSpecs = {
  AppMode.transformAndProtect: _ModeSpec(
    headerLabel: "16:9 COPYRIGHT REMOVER",
    badge: "16:9 WIDESCREEN STREAM",
    title: "Long Video Copyright Remover",
    description:
        "Preserves native 16:9 widescreen canvas while passing through 12-layer geometric, chromatic, and acoustic signed-jitter perturbation.",
    cta: "Start Copyright Protection",
    icon: Icons.shield_outlined,
    segmentLabel: "Copyright",
    supportsPreset: true,
  ),
  AppMode.longVideoToShorts: _ModeSpec(
    headerLabel: "9:16 AI SHORTS",
    badge: "9:16 VERTICAL HIGHLIGHTS",
    title: "AI Shorts Generator",
    description:
        "Scores the strongest moments in a long video and reframes each one to 9:16 using facial centroid subject tracking.",
    cta: "Find Best Moments",
    icon: Icons.play_circle_outline,
    segmentLabel: "AI Shorts",
  ),
  AppMode.songRemover: _ModeSpec(
    headerLabel: "AUDIO DSP STUDIO",
    badge: "MULTI-STAGE DSP CHAIN",
    title: "Song DSP & Cover Export",
    description:
        "Re-masters audio through tone, pitch, spatial and dynamics processing, then composes it against a cover image for upload.",
    cta: "Open Song DSP",
    icon: Icons.music_note_outlined,
    segmentLabel: "Song DSP",
  ),
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;

  // Dashboard composer state
  AppMode _mode = AppMode.transformAndProtect;
  PipelinePreset _preset = PipelinePreset.fast;
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocus = FocusNode();
  final DownloaderService _downloader = DownloaderService();
  String? _pickedFilePath;

  int _shortsMade = 0;
  int _hoursSaved = 0;
  List<ProjectItem> _recentProjects = [];

  _ModeSpec get _spec => _modeSpecs[_mode]!;

  @override
  void initState() {
    super.initState();
    _loadStats();
    ProjectStorageService.revision.addListener(_loadStats);
    _urlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    ProjectStorageService.revision.removeListener(_loadStats);
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _urlFocus.dispose();
    _downloader.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    // Typing a link supersedes a previously picked file, and vice versa, so the
    // card always shows exactly one source.
    if (_urlController.text.trim().isNotEmpty && _pickedFilePath != null) {
      setState(() => _pickedFilePath = null);
    } else {
      setState(() {});
    }
  }

  Future<void> _loadStats() async {
    final stats = await ProjectStorageService.getStats();
    final projects = await ProjectStorageService.loadProjects();
    if (!mounted) return;
    setState(() {
      _shortsMade = stats['shortsMade'] as int? ?? 0;
      _hoursSaved = stats['editingSavedHours'] as int? ?? 0;
      _recentProjects = projects;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _toast("Clipboard is empty");
      return;
    }
    _urlController.text = text;
    _urlController.selection =
        TextSelection.fromPosition(TextPosition(offset: text.length));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: _mode == AppMode.songRemover ? FileType.any : FileType.video,
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      _pickedFilePath = path;
      _urlController.clear();
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: AppColors.darkCard,
      ));
  }

  bool get _hasSource =>
      _pickedFilePath != null || _urlController.text.trim().isNotEmpty;

  void _start() {
    final url = _urlController.text.trim();

    if (_pickedFilePath == null && url.isEmpty) {
      _toast("Paste a link or choose a file first");
      _urlFocus.requestFocus();
      return;
    }

    final bool isLocal = _pickedFilePath != null;
    if (!isLocal && _downloader.getVideoId(url) == null) {
      _toast("That does not look like a YouTube video or Shorts link");
      return;
    }

    final String source = isLocal ? _pickedFilePath! : url;
    final SourceType sourceType = isLocal
        ? (_mode == AppMode.songRemover
            ? SourceType.localAudio
            : SourceType.localVideo)
        : SourceType.youtubeUrl;

    switch (_mode) {
      case AppMode.transformAndProtect:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransformPipelineScreen(
              sourceVideoPathOrUrl: source,
              sourceType: sourceType,
              initialPreset: _preset,
            ),
          ),
        );
        break;
      case AppMode.longVideoToShorts:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AnalysisScreen(
              mode: _mode,
              sourceType: sourceType,
              source: source,
            ),
          ),
        );
        break;
      case AppMode.songRemover:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SongRemoverScreen(
              sourcePathOrUrl: source,
              sourceType: sourceType,
            ),
          ),
        );
        break;
    }
  }

  // ---------------------------------------------------------------- dashboard

  Widget _buildFastInputCard() {
    final bool hasFile = _pickedFilePath != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "FAST INPUT",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                "YOUTUBE / SHORTS / LOCAL",
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentTangerine,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // URL field with inline paste action
          Container(
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.line),
            ),
            padding: const EdgeInsets.only(left: 14, right: 6),
            child: Row(
              children: [
                const Icon(Icons.smart_display, color: Color(0xFFFF0033), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    focusNode: _urlFocus,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _start(),
                    style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: "Paste YouTube link (https://...)",
                      hintStyle: TextStyle(fontSize: 13.5, color: AppColors.mut),
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste, size: 15),
                  label: const Text("Paste"),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentTangerine,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.line)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  "OR",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mut.withOpacity(0.8),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: AppColors.line)),
            ],
          ),
          const SizedBox(height: 12),

          // Local file picker
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
              decoration: BoxDecoration(
                color: hasFile ? AppColors.softTangerine : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasFile ? AppColors.accentTangerine : AppColors.line,
                  width: hasFile ? 1.5 : 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasFile ? Icons.check_circle : Icons.image_outlined,
                    size: 19,
                    color: hasFile ? AppColors.accentTangerine : AppColors.ink,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      hasFile
                          ? p.basename(_pickedFilePath!)
                          : "Choose Video or Audio from Storage",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: hasFile ? AppColors.accentTangerine : AppColors.ink,
                      ),
                    ),
                  ),
                  if (hasFile) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _pickedFilePath = null),
                      child: const Icon(Icons.close, size: 17, color: AppColors.mut),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSegments() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.line.withOpacity(0.35),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: AppMode.values.map((mode) {
          final spec = _modeSpecs[mode]!;
          final bool isSel = _mode == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _mode = mode),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSel ? AppColors.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Icon(
                      spec.icon,
                      size: 20,
                      color: isSel ? AppColors.accentTangerine : AppColors.mut,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      spec.segmentLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSel ? AppColors.accentTangerine : AppColors.mut,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPresetChip(PipelinePreset preset, String label) {
    final bool isSel = _preset == preset;
    return GestureDetector(
      onTap: () => setState(() => _preset = preset),
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? AppColors.ink : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSel ? AppColors.ink : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isSel ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _buildModeDetailCard() {
    final spec = _spec;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.softTangerine,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              spec.badge,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: AppColors.accentTangerine,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            spec.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            spec.description,
            style: const TextStyle(fontSize: 13, color: AppColors.mut, height: 1.45),
          ),

          if (spec.supportsPreset) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Text(
                    "Processing Preset",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  _buildPresetChip(PipelinePreset.fast, "Fast"),
                  _buildPresetChip(PipelinePreset.balanced, "Balanced"),
                  _buildPresetChip(PipelinePreset.advanced, "Deep"),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: Text(
              spec.cta,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _hasSource ? AppColors.accentTangerine : AppColors.accentTangerine.withOpacity(0.55),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRenderBanner() {
    return ValueListenableBuilder<RenderJobState?>(
      valueListenable: RenderJobService.instance.activeJob,
      builder: (context, job, _) {
        if (job == null || !job.isActive) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProcessingScreen(
                projectId: job.projectId,
                mode: _modeForProject(job.projectId),
                title: job.title,
              ),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentTangerine,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Rendering in Background",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "${job.progressPercent}%",
                      style: const TextStyle(
                        color: AppColors.accentTangerine,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: job.status == RenderJobStatus.queued ? null : job.progress,
                    backgroundColor: Colors.white12,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.accentTangerine),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Exporting: ${job.title}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.mut, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Clip ${job.renderedClips + 1}/${job.totalClips}",
                      style: const TextStyle(color: AppColors.mut, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  AppMode _modeForProject(String projectId) {
    for (final project in _recentProjects) {
      if (project.id == projectId) return project.mode;
    }
    return AppMode.longVideoToShorts;
  }

  Widget _buildStatsRow() {
    Widget tile(String value, String unit, String label) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  if (unit.isNotEmpty)
                    Text(unit, style: const TextStyle(fontSize: 15, color: AppColors.mut)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mut,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        tile("$_shortsMade", "", "Clips made"),
        const SizedBox(width: 12),
        tile("$_hoursSaved", "h", "Editing saved"),
      ],
    );
  }

  Widget _buildDashboard() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact identity row
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "ClipShield Studio",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _currentNavIndex = 2),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.darkCard,
                      ),
                      child: const Icon(Icons.person, color: Colors.white70, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            _buildFastInputCard(),
            const SizedBox(height: 22),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "CHOOSE ACTION",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mut,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  _spec.headerLabel,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentTangerine,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            _buildModeSegments(),
            const SizedBox(height: 14),
            _buildModeDetailCard(),
            _buildRenderBanner(),

            const SizedBox(height: 24),
            _buildStatsRow(),

            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recent Projects",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _currentNavIndex = 1),
                  child: const Text(
                    "See all",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentTangerine,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_recentProjects.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  children: [
                    Icon(Icons.video_library_outlined,
                        size: 34, color: AppColors.mut.withOpacity(0.6)),
                    const SizedBox(height: 10),
                    const Text(
                      "No projects yet",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Paste a link above and pick an action to create your first project.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: AppColors.mut),
                    ),
                  ],
                ),
              )
            else
              _buildRecentProjectCard(_recentProjects.first),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- chrome

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_filled, "Home"),
            _buildNavItem(1, Icons.video_collection_outlined, "Projects"),
            _buildNavItem(2, Icons.settings_outlined, "Settings"),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSel = _currentNavIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentNavIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSel ? AppColors.accentTangerine : AppColors.mut, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSel ? AppColors.accentTangerine : AppColors.mut,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentProjectCard(ProjectItem project) {
    final bool isMode1 = project.mode == AppMode.longVideoToShorts;
    final bool hasThumb =
        project.thumbnailPath != null && File(project.thumbnailPath!).existsSync();

    return GestureDetector(
      onTap: () {
        // Only a genuinely finished render opens the results screen.
        if (project.isReady) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultsScreen(
                project: project,
                renderedClips: project.clips.where((c) => c.isRendered).toList(),
              ),
            ),
          );
        } else if (project.status == ProjectStatus.draft) {
          setState(() => _currentNavIndex = 1);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProcessingScreen(
                projectId: project.id,
                mode: project.mode,
                title: project.title,
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 74,
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(12),
                image: hasThumb
                    ? DecorationImage(
                        image: FileImage(File(project.thumbnailPath!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!hasThumb)
                    Icon(
                      isMode1 ? Icons.auto_awesome : Icons.security,
                      color: isMode1 ? AppColors.accentTangerine : AppColors.accentGrape,
                      size: 24,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isMode1
                        ? "${project.clipsCount} clips · ${project.formattedDate}"
                        : "Transformed · ${project.formattedDate}",
                    style: const TextStyle(fontSize: 13, color: AppColors.mut),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ValueListenableBuilder<Map<String, RenderJobState>>(
                        valueListenable: RenderJobService.instance.jobs,
                        builder: (context, allJobs, _) {
                          final live = allJobs[project.id];
                          final Color c = project.status == ProjectStatus.done
                              ? AppColors.accentLime
                              : (project.status == ProjectStatus.failed
                                  ? AppColors.error
                                  : (project.isRenderingOrQueued
                                      ? Colors.orange
                                      : AppColors.mut));
                          final String label = (live != null && live.isActive)
                              ? "${live.statusLabel.toUpperCase()} ${live.progressPercent}%"
                              : project.statusLabel.toUpperCase();
                          return Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: c,
                              ),
                            ),
                          );
                        },
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.mut),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (_currentNavIndex) {
      1 => const ProjectsHistoryScreen(),
      2 => const SettingsScreen(),
      _ => _buildDashboard(),
    };

    return PopScope(
      canPop: _currentNavIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _currentNavIndex = 0);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        resizeToAvoidBottomInset: true,
        body: body,
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }
}
