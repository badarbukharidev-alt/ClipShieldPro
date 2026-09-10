import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/clip_model.dart';
import '../models/project_model.dart';
import '../theme/app_theme.dart';
import 'preview_screen.dart';

class ResultsScreen extends StatelessWidget {
  final ProjectItem project;
  final List<ClipItem> renderedClips;

  const ResultsScreen({
    super.key,
    required this.project,
    required this.renderedClips,
  });

  Future<void> _shareAll() async {
    final paths = renderedClips
        .where((c) => c.outputPath != null && File(c.outputPath!).existsSync())
        .map((c) => XFile(c.outputPath!))
        .toList();

    if (paths.isNotEmpty) {
      await Share.shareXFiles(paths, text: "Rendered with ClipShield Pro");
    }
  }

  void _openPreview(BuildContext context, ClipItem clip) {
    if (clip.outputPath == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreviewScreen(
          originalVideoPath: project.sourceUrlOrPath,
          transformedVideoPath: clip.outputPath!,
          title: clip.title,
          duration: clip.duration,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
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
                    const Text(
                      "Your Shorts Are Ready",
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${renderedClips.length} clips · reframed, transformed & enhanced",
                      style: const TextStyle(fontSize: 13, color: AppColors.mut),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2-Column Grid of 9:16 Shorts
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.60,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: renderedClips.length,
                  itemBuilder: (context, index) {
                    final clip = renderedClips[index];
                    final hasThumb = clip.thumbnailPath != null && File(clip.thumbnailPath!).existsSync();

                    return GestureDetector(
                      onTap: () => _openPreview(context, clip),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
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
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Bottom Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (renderedClips.isNotEmpty) {
                          _openPreview(context, renderedClips.first);
                        }
                      },
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                      label: const Text("Preview"),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _shareAll,
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text("Save & Share"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.accentTangerine,
                      ),
                    ),
                  ),
                ],
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
