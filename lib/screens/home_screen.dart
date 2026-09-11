import 'dart:io';
import 'package:flutter/material.dart';
import '../models/app_modes.dart';
import '../models/project_model.dart';
import '../services/project_storage_service.dart';
import '../theme/app_theme.dart';
import 'analysis_screen.dart';
import 'project_create_dialog.dart';
import 'projects_history_screen.dart';
import 'results_screen.dart';
import 'settings_screen.dart';
import 'transform_pipeline_screen.dart';
import 'song_remover_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  int _shortsMade = 0;
  int _hoursSaved = 0;
  List<ProjectItem> _recentProjects = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
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

  void _openCreateProjectModal({AppMode defaultMode = AppMode.longVideoToShorts}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProjectCreateDialog(
        initialMode: defaultMode,
        onProceed: ({
          required AppMode mode,
          required SourceType sourceType,
          required String sourcePathOrUrl,
          required bool authorized,
        }) {
          if (mode == AppMode.longVideoToShorts) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnalysisScreen(
                  mode: mode,
                  sourceType: sourceType,
                  source: sourcePathOrUrl,
                ),
              ),
            );
          } else if (mode == AppMode.songRemover) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SongRemoverScreen(
                  sourcePathOrUrl: sourcePathOrUrl,
                  sourceType: sourceType,
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TransformPipelineScreen(
                  sourceVideoPathOrUrl: sourcePathOrUrl,
                  sourceType: sourceType,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_filled, "Home"),
            GestureDetector(
              onTap: () => _openCreateProjectModal(),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.accentTangerine,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentTangerine.withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
            _buildNavItem(1, Icons.video_collection_outlined, "Projects"),
            _buildNavItem(2, Icons.settings_outlined, "Settings"),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentNavIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          setState(() => _currentNavIndex = 0);
        }
      },
      child: _currentNavIndex == 1
          ? Scaffold(
              backgroundColor: AppColors.bg,
              body: const ProjectsHistoryScreen(),
              bottomNavigationBar: _buildBottomNav(),
            )
          : _currentNavIndex == 2
              ? Scaffold(
                  backgroundColor: AppColors.bg,
                  body: const SettingsScreen(),
                  bottomNavigationBar: _buildBottomNav(),
                )
              : Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome back",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mut,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "ClipShield Studio",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _currentNavIndex = 2),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.darkCard,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.person, color: Colors.white70, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // HERO MODE: LONG VIDEO COPYRIGHT REMOVER (TOP HERO CARD)
              GestureDetector(
                onTap: () => _openCreateProjectModal(defaultMode: AppMode.transformAndProtect),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.accentGrape,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentGrape.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "PRIMARY · 9-LAYER DSP",
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Long Video Copyright Remover",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Protect full-length widescreen (16:9) videos against Content ID with 9-layer perturbation.",
                        style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.35),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield, color: AppColors.ink, size: 18),
                            SizedBox(width: 6),
                            Text(
                              "Protect & Transform",
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // SECONDARY MODE: LONG VIDEO -> SHORTS
              GestureDetector(
                onTap: () => _openCreateProjectModal(defaultMode: AppMode.longVideoToShorts),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.accentTangerine,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentTangerine.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "SECONDARY · AI CLIPPING",
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Long Video → Shorts",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Import a video or paste a link to extract viral vertical clips automatically.",
                        style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.35),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: AppColors.ink, size: 18),
                            SizedBox(width: 6),
                            Text(
                              "Start clipping",
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // THIRD MODE: SONGS REMOVER
              GestureDetector(
                onTap: () => _openCreateProjectModal(defaultMode: AppMode.songRemover),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.accentLime,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentLime.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "NEW · AUDIO DSP",
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const Icon(Icons.music_note, color: Colors.white, size: 20),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Songs Remover",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Process audio with full DSP controls, add cover image, and export as video.",
                        style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.35),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.music_video, color: AppColors.ink, size: 18),
                            SizedBox(width: 6),
                            Text(
                              "Process Audio",
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Quick Stats Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "$_shortsMade",
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Shorts made",
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.mut),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "$_hoursSaved",
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              const Text("h", style: TextStyle(fontSize: 16, color: AppColors.mut)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Editing saved",
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.mut),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Continue Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Recent Projects",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _currentNavIndex = 1),
                    child: const Text(
                      "See all",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accentTangerine),
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
                      Icon(Icons.video_library_outlined, size: 36, color: AppColors.mut.withOpacity(0.6)),
                      const SizedBox(height: 10),
                      const Text(
                        "No projects yet",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Transform or clip your first video using the modes above.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: AppColors.mut),
                      ),
                    ],
                  ),
                )
              else
                _buildRecentProjectCard(_recentProjects.first),
              const SizedBox(height: 24),

              // Templates Carousel
              const Text(
                "Shorts Templates",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTemplateCard("Talking Head", "POP", Icons.record_voice_over_outlined),
                    const SizedBox(width: 12),
                    _buildTemplateCard("Podcast Clip", "HOT", Icons.podcasts_outlined),
                    const SizedBox(width: 12),
                    _buildTemplateCard("Tutorial", "NEW", Icons.school_outlined),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    ),
  );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSel = _currentNavIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentNavIndex = index),
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
    );
  }

  Widget _buildRecentProjectCard(ProjectItem project) {
    final bool isMode1 = project.mode == AppMode.longVideoToShorts;
    final bool hasThumb = project.thumbnailPath != null && File(project.thumbnailPath!).existsSync();

    return GestureDetector(
      onTap: () {
        if (project.status == 'done') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultsScreen(
                project: project,
                renderedClips: project.clips,
              ),
            ),
          );
        } else {
          setState(() => _currentNavIndex = 1);
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
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isMode1 ? "${project.clipsCount} clips · ${project.formattedDate}" : "Transformed · ${project.formattedDate}",
                    style: const TextStyle(fontSize: 13, color: AppColors.mut),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: project.status == 'done'
                              ? AppColors.accentLime.withOpacity(0.15)
                              : AppColors.accentTangerine.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          project.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: project.status == 'done' ? AppColors.accentLime : AppColors.accentTangerine,
                          ),
                        ),
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

  Widget _buildTemplateCard(String title, String badge, IconData icon) {
    return Container(
      width: 120,
      height: 150,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accentTangerine,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badge,
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
            ),
          ),
          const Spacer(),
          Icon(icon, size: 30, color: AppColors.accentTangerine),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}
