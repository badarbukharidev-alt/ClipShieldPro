import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/clip_model.dart';
import '../models/project_model.dart';
import '../models/source_metadata.dart';
import '../models/app_modes.dart';
import '../theme/app_theme.dart';
import '../services/gallery_export_service.dart';
import '../services/project_storage_service.dart';
import '../widgets/share_target_row.dart';
import '../widgets/source_metadata_panel.dart';
import 'preview_screen.dart';
import 'processing_screen.dart';

class ResultsScreen extends StatefulWidget {
  final ProjectItem project;
  final List<ClipItem> renderedClips;

  const ResultsScreen({
    super.key,
    required this.project,
    required this.renderedClips,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

/// What happened to the gallery save. A failure has to be visible: the old
/// banner only appeared on success, so a save that silently did nothing looked
/// exactly like one that never ran.
enum _SaveState { saving, saved, failed }

class _ResultsScreenState extends State<ResultsScreen> {
  _SaveState _saveState = _SaveState.saving;
  String _savedLocation = '';

  /// Clips with a verified artifact on disk. Nothing else may be presented as
  /// a finished result.
  List<ClipItem> get _readyClips => widget.renderedClips
      .where((c) => c.isRendered && c.outputPath != null && File(c.outputPath!).existsSync())
      .toList();

  /// Metadata captured when the source link was pasted, if this project had one.
  SourceMetadata? get _sourceMeta => widget.project.sourceMetadata;

  bool get _isGenuinelyReady =>
      widget.project.status == ProjectStatus.done && _readyClips.isNotEmpty;

  @override
  void initState() {
    super.initState();

    if (!_isGenuinelyReady) return;

    // Already published on an earlier visit: say so, and do not publish again.
    if (widget.project.isExportedToGallery) {
      _saveState = _SaveState.saved;
      _savedLocation = 'Movies/ClipShield';
      return;
    }

    _exportToGallery();
  }

  /// A name the user can actually find in their gallery, rather than the
  /// render's temp basename.
  String _exportFileName(ClipItem clip, int index) {
    final safeTitle = widget.project.title
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final base = safeTitle.isEmpty ? 'ClipShield' : 'ClipShield_$safeTitle';
    final suffix = _readyClips.length > 1 ? '_${index + 1}' : '';

    return '${base.substring(0, base.length > 60 ? 60 : base.length)}$suffix.mp4';
  }

  /// Publishes every finished clip to the gallery, once per project.
  ///
  /// [force] is for the Retry button, which must work even though the project
  /// may be flagged as exported from a run that in fact failed.
  Future<void> _exportToGallery({bool force = false}) async {
    if (!force && widget.project.isExportedToGallery) return;
    if (mounted) setState(() => _saveState = _SaveState.saving);

    bool anySaved = false;
    String location = '';
    for (var i = 0; i < _readyClips.length; i++) {
      final clip = _readyClips[i];
      if (clip.outputPath != null && File(clip.outputPath!).existsSync()) {
        final newPath = await GalleryExportService.exportToPublicGallery(
          clip.outputPath!,
          customFileName: _exportFileName(clip, i),
        );
        if (newPath != null) {
          anySaved = true;
          location = GalleryExportService.displayLocation(newPath);
        }
      }
    }

    // The source thumbnail goes to the gallery alongside the video, so it is
    // there to upload with rather than needing a separate trip back into the
    // metadata panel.
    if (anySaved) await _exportThumbnail();

    // Recorded only on success, so a failed export is retried on the next
    // visit rather than being written off.
    if (anySaved && !widget.project.isExportedToGallery) {
      widget.project.isExportedToGallery = true;
      await ProjectStorageService.saveProject(widget.project);
    }

    if (!mounted) return;
    setState(() {
      _saveState = anySaved ? _SaveState.saved : _SaveState.failed;
      _savedLocation = location;
    });
  }

  /// Saves the source video's thumbnail next to the render.
  ///
  /// Silent on failure: this is a bonus alongside the video, and a video that
  /// saved fine should not be reported as a failed export because a thumbnail
  /// URL was unreachable. The metadata panel's own button reports properly.
  Future<void> _exportThumbnail() async {
    final meta = _sourceMeta;
    if (meta == null) return;

    // Best quality first. maxresdefault.jpg only exists for videos uploaded
    // above 720p, so it 404s for a large share of sources.
    final candidates = <String>[
      meta.thumbnailMaxResUrl,
      meta.thumbnailUrl,
      if (meta.videoId.isNotEmpty) ...[
        'https://i.ytimg.com/vi/${meta.videoId}/hqdefault.jpg',
        'https://i.ytimg.com/vi/${meta.videoId}/mqdefault.jpg',
      ],
    ];
    if (candidates.every((u) => u.trim().isEmpty)) return;

    final stamp = meta.videoId.isNotEmpty ? meta.videoId : widget.project.id;
    await GalleryExportService.downloadImage(
      candidates,
      'ClipShield_thumb_$stamp.jpg',
    );
  }

  Future<void> _shareClips(List<ClipItem> clips, {String text = "Check out my video created with ClipShield Pro!"}) async {
    final paths = clips
        .where((c) => c.outputPath != null && File(c.outputPath!).existsSync())
        .map((c) => XFile(c.outputPath!))
        .toList();

    if (paths.isNotEmpty) {
      await Share.shareXFiles(paths, text: text);
    }
  }

  void _openPreview(BuildContext context, ClipItem clip) {
    if (clip.outputPath == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreviewScreen(
          originalVideoPath: widget.project.sourceUrlOrPath,
          transformedVideoPath: clip.outputPath!,
          title: clip.title,
          duration: clip.duration,
        ),
      ),
    );
  }

  /// States the outcome of the gallery save, including when it failed.
  Widget _buildSaveBanner() {
    late final Color tint;
    late final IconData icon;
    late final String label;

    switch (_saveState) {
      case _SaveState.saving:
        tint = AppColors.mut;
        icon = Icons.hourglass_top_rounded;
        label = "Saving to your gallery...";
        break;
      case _SaveState.saved:
        tint = AppColors.accentLime;
        icon = Icons.check_circle_rounded;
        label = _savedLocation.isEmpty
            ? "Saved to your gallery"
            : "Saved to your gallery ($_savedLocation)";
        break;
      case _SaveState.failed:
        tint = AppColors.error;
        icon = Icons.error_outline_rounded;
        label = "Could not save to the gallery";
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint),
      ),
      child: Row(
        children: [
          Icon(icon, color: tint, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: tint, fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ),
          if (_saveState == _SaveState.failed)
            TextButton(
              onPressed: () => _exportToGallery(force: true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                "Retry",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hard guard: this screen speaks only for completed renders. If it is ever
    // reached for a project that is still processing or failed, show the real
    // state instead of a "ready" headline.
    if (!_isGenuinelyReady) return _buildNotReady();

    final bool isWidescreen = widget.project.isWidescreen;
    final bool isSongRemover = widget.project.mode == AppMode.songRemover;

    final String headline = isSongRemover
        ? "Your Audio Asset Is Ready"
        : (isWidescreen ? "Protected Video Ready" : "Your Shorts Are Ready");

    final String subtitle = isSongRemover
        ? "DSP mastering applied · ${_readyClips.length} asset generated"
        : (isWidescreen
            ? "16:9 Widescreen · 12-layer protection applied"
            : "${_readyClips.length} clips · reframed, transformed & enhanced");

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSaveBanner(),

              // Success Icon & Headline
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 66,
                      height: 66,
                      decoration: const BoxDecoration(
                        color: AppColors.softTangerine,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 36, color: AppColors.accentTangerine),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      headline,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: AppColors.mut),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Content View: 16:9 Widescreen Cards or 9:16 Shorts Grid
              Builder(
                builder: (context) => isWidescreen
                    ? ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _readyClips.length,
                        itemBuilder: (context, index) {
                          final clip = _readyClips[index];
                          final hasThumb = clip.thumbnailPath != null && File(clip.thumbnailPath!).existsSync();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.line),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: GestureDetector(
                                    onTap: () => _openPreview(context, clip),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.darkCard,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                                        image: hasThumb
                                            ? DecorationImage(
                                                image: FileImage(File(clip.thumbnailPath!)),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: Stack(
                                        children: [
                                          Center(
                                            child: Container(
                                              width: 52,
                                              height: 52,
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.55),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                                            ),
                                          ),
                                          Positioned(
                                            top: 10,
                                            left: 10,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.accentTangerine,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                "16:9 WIDESCREEN",
                                                style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 10,
                                            right: 10,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.75),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                clip.duration,
                                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              clip.title,
                                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            const Text(
                                              "Widescreen · 1080p HD · H.264 FastStart",
                                              style: TextStyle(fontSize: 11.5, color: AppColors.mut),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.share, color: AppColors.ink),
                                        onPressed: () => _shareClips([clip]),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.58,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: _readyClips.length,
                        itemBuilder: (context, index) {
                          final clip = _readyClips[index];
                          final hasThumb = clip.thumbnailPath != null && File(clip.thumbnailPath!).existsSync();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _openPreview(context, clip),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.darkCard,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: AppColors.line),
                                      image: hasThumb
                                          ? DecorationImage(
                                              image: FileImage(File(clip.thumbnailPath!)),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: Stack(
                                      children: [
                                        Center(
                                          child: Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.4),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 26),
                                          ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          left: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.accentTangerine,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              "TRANSFORMED",
                                              style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            onTap: () => _shareClips([clip]),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.6),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.share, color: Colors.white, size: 14),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.75),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              clip.duration,
                                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                clip.title,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Score ${clip.score} · 9:16 portrait",
                                style: const TextStyle(fontSize: 11, color: AppColors.mut),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),

              // Share straight to a named app, with that app's own mark.
              ShareTargetRow(
                filePaths: _readyClips
                    .map((c) => c.outputPath)
                    .whereType<String>()
                    .toList(),
                text: widget.project.title.isEmpty
                    ? "Made with ClipShield Pro"
                    : "${widget.project.title} - made with ClipShield Pro",
              ),

              // Source metadata, shown inline after sharing so the title,
              // description, tags and thumbnail are right there when publishing.
              if (_sourceMeta != null) ...[
                const SizedBox(height: 6),
                SourceMetadataPanel(
                  metadata: _sourceMeta!,
                  accent: widget.project.isWidescreen
                      ? AppColors.accentGrape
                      : AppColors.accentTangerine,
                ),
              ],

              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text("Done", style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotReady() {
    final project = widget.project;
    final bool inFlight = project.isRenderingOrQueued;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(project.statusLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                inFlight ? Icons.hourglass_top : Icons.error_outline,
                size: 52,
                color: inFlight ? AppColors.accentTangerine : AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                inFlight ? "Still rendering" : "No finished output",
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 10),
              Text(
                inFlight
                    ? "This project has not finished rendering yet. Open its status page to follow the progress."
                    : (project.renderError ?? "This render did not produce any usable clips."),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.mut, height: 1.45),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProcessingScreen(
                      projectId: project.id,
                      mode: project.mode,
                      title: project.title,
                    ),
                  ),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(220, 48),
                  backgroundColor: AppColors.accentTangerine,
                ),
                child: const Text("Open render status"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
