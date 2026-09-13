import 'dart:io';
import 'package:flutter/material.dart';
import '../models/app_modes.dart';
import '../models/project_model.dart';
import '../services/project_storage_service.dart';
import '../services/render_job_service.dart';
import '../theme/app_theme.dart';
import 'processing_screen.dart';
import 'results_screen.dart';

class ProjectsHistoryScreen extends StatefulWidget {
  const ProjectsHistoryScreen({super.key});

  @override
  State<ProjectsHistoryScreen> createState() => _ProjectsHistoryScreenState();
}

class _ProjectsHistoryScreenState extends State<ProjectsHistoryScreen> {
  List<ProjectItem> _projects = [];
  String _selectedFilter = "All";
  bool _isLoading = true;

  static const List<String> _filters = [
    "All",
    "Rendering",
    "Completed",
    "Failed",
    "Shorts",
    "Transformed",
    "Songs",
    "Drafts",
  ];

  @override
  void initState() {
    super.initState();
    _loadProjects();
    // Storage is the source of truth; these two notifiers tell us when either
    // the persisted record or the live job state changed.
    ProjectStorageService.revision.addListener(_loadProjects);
    RenderJobService.instance.jobs.addListener(_onJobsChanged);
  }

  @override
  void dispose() {
    ProjectStorageService.revision.removeListener(_loadProjects);
    RenderJobService.instance.jobs.removeListener(_onJobsChanged);
    super.dispose();
  }

  void _onJobsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProjects() async {
    final list = await ProjectStorageService.loadProjects();
    if (!mounted) return;
    setState(() {
      _projects = list;
      _isLoading = false;
    });
  }

  List<ProjectItem> get _filteredProjects {
    switch (_selectedFilter) {
      case "Rendering":
        return _projects.where((p) => p.isRenderingOrQueued).toList();
      case "Completed":
        return _projects.where((p) => p.status == ProjectStatus.done).toList();
      case "Failed":
        return _projects
            .where((p) => p.status == ProjectStatus.failed || p.status == ProjectStatus.canceled)
            .toList();
      case "Shorts":
        return _projects.where((p) => p.mode == AppMode.longVideoToShorts).toList();
      case "Transformed":
        return _projects.where((p) => p.mode == AppMode.transformAndProtect).toList();
      case "Songs":
        return _projects.where((p) => p.mode == AppMode.songRemover).toList();
      case "Drafts":
        return _projects.where((p) => p.status == ProjectStatus.draft).toList();
      default:
        return _projects;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case ProjectStatus.done:
        return AppColors.accentTangerine;
      case ProjectStatus.rendering:
      case ProjectStatus.queued:
        return Colors.orange;
      case ProjectStatus.failed:
        return AppColors.error;
      default:
        return AppColors.mut;
    }
  }

  void _openProject(ProjectItem p) {
    // A project only opens its results when the render genuinely finished and
    // the files exist. Anything else opens the live status page.
    if (p.isReady) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(
            project: p,
            renderedClips: p.clips.where((c) => c.isRendered).toList(),
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProcessingScreen(
          projectId: p.id,
          mode: p.mode,
          title: p.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projects = _filteredProjects;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text("Projects & History", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentTangerine))
          : Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Row(
                    children: _filters.map((filter) {
                      final isSel = _selectedFilter == filter;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFilter = filter),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel ? AppColors.accentTangerine : AppColors.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSel ? AppColors.accentTangerine : AppColors.line,
                            ),
                          ),
                          child: Text(
                            filter,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSel ? Colors.white : AppColors.mut,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: projects.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.video_library_outlined, size: 48, color: AppColors.mut),
                              SizedBox(height: 12),
                              Text(
                                "No projects in this category",
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.mut),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.accentTangerine,
                          onRefresh: _loadProjects,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                            itemCount: projects.length,
                            itemBuilder: (context, index) => _buildProjectCard(projects[index]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildProjectCard(ProjectItem p) {
    final bool isMode1 = p.mode == AppMode.longVideoToShorts;
    final isSong = p.mode == AppMode.songRemover;
    final hasThumb = p.thumbnailPath != null && File(p.thumbnailPath!).existsSync();

    final job = RenderJobService.instance.jobFor(p.id);
    final bool isLive = job != null && job.isActive;
    final String statusText = isLive
        ? "${job.statusLabel.toUpperCase()} ${job.progressPercent}%"
        : p.statusLabel.toUpperCase();
    final Color statusColor = isLive ? Colors.orange : _statusColor(p.status);

    final String subtitle = p.isRenderingOrQueued
        ? "${job?.renderedClips ?? p.renderedClipsCount}/${job?.totalClips ?? p.clipsCount} clips · ${p.aspectRatio.label}"
        : "${p.clipsCount} clip${p.clipsCount == 1 ? '' : 's'} · ${p.aspectRatio.label}";

    return GestureDetector(
      onTap: () => _openProject(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isLive ? Colors.orange.withOpacity(0.5) : AppColors.line),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 74,
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    image: hasThumb
                        ? DecorationImage(
                            image: FileImage(File(p.thumbnailPath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!hasThumb)
                        Icon(
                          isSong ? Icons.music_note : (isMode1 ? Icons.auto_awesome : Icons.security),
                          color: isSong
                              ? Colors.green
                              : (isMode1 ? AppColors.accentTangerine : AppColors.accentGrape),
                          size: 22,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSong
                                  ? Colors.green.withOpacity(0.15)
                                  : (isMode1 ? AppColors.softTangerine : AppColors.softGrape),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isSong ? "SONGS" : (isMode1 ? "SHORTS" : "TRANSFORM"),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: isSong
                                    ? Colors.green
                                    : (isMode1 ? AppColors.accentTangerine : AppColors.accentGrape),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            p.formattedDate,
                            style: const TextStyle(fontSize: 11.5, color: AppColors.mut),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, color: AppColors.mut),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (isLive) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: job.status == RenderJobStatus.queued ? null : job.progress,
                  backgroundColor: AppColors.line,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  job.currentStage,
                  style: const TextStyle(fontSize: 11, color: AppColors.mut),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (!isLive && p.status == ProjectStatus.failed && p.renderError != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  p.renderError!,
                  style: const TextStyle(fontSize: 11, color: AppColors.error),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
