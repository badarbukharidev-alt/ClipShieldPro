import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/clip_model.dart';
import '../models/project_model.dart';
import '../models/app_modes.dart';
import '../theme/app_theme.dart';
import '../services/gallery_export_service.dart';
import 'preview_screen.dart';

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

class _ResultsScreenState extends State<ResultsScreen> {
  bool _isSavedToGallery = false;

  @override
  void initState() {
    super.initState();
    _exportToGallery();
  }

  Future<void> _exportToGallery() async {
    bool anySaved = false;
    for (var clip in widget.renderedClips) {
      if (clip.outputPath != null && File(clip.outputPath!).existsSync()) {
        final newPath = await GalleryExportService.exportToPublicGallery(clip.outputPath!);
        if (newPath != null) {
          anySaved = true;
        }
      }
    }
    if (anySaved && mounted) {
      setState(() {
        _isSavedToGallery = true;
      });
    }
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

  Widget _buildShareOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ink),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWidescreen = widget.project.mode == AppMode.transformAndProtect ||
        widget.project.aspectRatio == AspectRatioOption.original169;
    final bool isSongRemover = widget.project.mode == AppMode.songRemover;

    final String headline = isSongRemover
        ? "Your Audio Asset Is Ready"
        : (isWidescreen ? "Protected Video Ready" : "Your Shorts Are Ready");

    final String subtitle = isSongRemover
        ? "DSP mastering applied · ${widget.renderedClips.length} asset generated"
        : (isWidescreen
            ? "16:9 Widescreen · 12-layer protection applied"
            : "${widget.renderedClips.length} clips · reframed, transformed & enhanced");

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isSavedToGallery)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Saved to Gallery (Movies/ClipShield)",
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),

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
              Expanded(
                child: isWidescreen
                    ? ListView.builder(
                        itemCount: widget.renderedClips.length,
                        itemBuilder: (context, index) {
                          final clip = widget.renderedClips[index];
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
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.58,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: widget.renderedClips.length,
                        itemBuilder: (context, index) {
                          final clip = widget.renderedClips[index];
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
              const SizedBox(height: 14),

              // Rich Social Sharing Options
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildShareOption(Icons.message, "WhatsApp", Colors.green, () => _shareClips(widget.renderedClips)),
                    _buildShareOption(Icons.video_library, "YouTube", Colors.red, () => _shareClips(widget.renderedClips)),
                    _buildShareOption(Icons.camera_alt, "Instagram", Colors.purple, () => _shareClips(widget.renderedClips)),
                    _buildShareOption(Icons.share, "More", AppColors.ink, () => _shareClips(widget.renderedClips)),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text("Done", style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
