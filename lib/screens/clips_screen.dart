import 'package:flutter/material.dart';
import '../models/clip_model.dart';
import '../models/project_model.dart';
import '../services/media_probe_service.dart';
import '../theme/app_theme.dart';
import 'customize_screen.dart';

class ClipsScreen extends StatefulWidget {
  final ProjectItem project;
  final String sourceVideoPath;
  final MediaProbeInfo probeInfo;

  const ClipsScreen({
    super.key,
    required this.project,
    required this.sourceVideoPath,
    required this.probeInfo,
  });

  @override
  State<ClipsScreen> createState() => _ClipsScreenState();
}

class _ClipsScreenState extends State<ClipsScreen> {
  late List<ClipItem> _clips;

  @override
  void initState() {
    super.initState();
    _clips = widget.project.clips;
  }

  int get _selectedCount => _clips.where((c) => c.isSelected).length;

  void _toggleSelect(ClipItem clip) {
    setState(() {
      clip.isSelected = !clip.isSelected;
    });
  }

  void _selectAll(bool select) {
    setState(() {
      for (var c in _clips) {
        c.isSelected = select;
      }
    });
  }

  void _goToCustomize() {
    if (_selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one clip")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomizeScreen(
          project: widget.project,
          sourceVideoPath: widget.sourceVideoPath,
          probeInfo: widget.probeInfo,
          selectedClips: _clips.where((c) => c.isSelected).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Column(
          children: [
            const Text("Best Moments", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            Text(
              "${_clips.length} moments found · auto-scored",
              style: const TextStyle(fontSize: 12, color: AppColors.mut, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _selectAll(_selectedCount != _clips.length),
            child: Text(
              _selectedCount == _clips.length ? "Deselect All" : "Select All",
              style: const TextStyle(color: AppColors.accentTangerine, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Text(
              "Tap to select clips for 9:16 rendering. Each moment is scored for engagement potential.",
              style: TextStyle(fontSize: 12.5, color: AppColors.mut, height: 1.4),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              itemCount: _clips.length,
              itemBuilder: (context, index) {
                final clip = _clips[index];
                final bool isSel = clip.isSelected;

                return GestureDetector(
                  onTap: () => _toggleSelect(clip),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSel ? AppColors.accentTangerine : AppColors.line,
                        width: isSel ? 2 : 1,
                      ),
                      boxShadow: isSel
                          ? [
                              BoxShadow(
                                color: AppColors.accentTangerine.withOpacity(0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left: 9:16 Card Thumbnail Placeholder
                        Container(
                          width: 60,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.darkCard,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.play_circle_outline, color: Colors.white70, size: 24),
                              Positioned(
                                bottom: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    clip.duration,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Middle Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Tag pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.softTangerine,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  clip.tag,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.accentTangerine,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                clip.title,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              // Score bar
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(99),
                                      child: LinearProgressIndicator(
                                        value: clip.score / 100.0,
                                        minHeight: 5,
                                        backgroundColor: AppColors.line,
                                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentTangerine),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${clip.score}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Right: Selection checkbox
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSel ? AppColors.accentTangerine : Colors.transparent,
                            border: Border.all(
                              color: isSel ? AppColors.accentTangerine : AppColors.mut.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: isSel
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _goToCustomize,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: AppColors.accentTangerine,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Customize $_selectedCount Clips",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
