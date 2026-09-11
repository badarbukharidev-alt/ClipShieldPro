import 'dart:io';
import 'package:flutter/material.dart';
import '../models/app_modes.dart';
import '../models/clip_model.dart';
import '../models/project_model.dart';
import '../services/project_storage_service.dart';
import '../theme/app_theme.dart';
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

  final List<String> _filters = ["All", "Shorts", "Transformed", "Songs", "Done", "Drafts"];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final list = await ProjectStorageService.loadProjects();
    setState(() {
      _projects = list;
      _isLoading = false;
    });
  }

  List<ProjectItem> get _filteredProjects {
    if (_selectedFilter == "All") return _projects;
    if (_selectedFilter == "Shorts") {
      return _projects.where((p) => p.mode == AppMode.longVideoToShorts).toList();
    }
    if (_selectedFilter == "Transformed") {
      return _projects.where((p) => p.mode == AppMode.transformAndProtect).toList();
    }
    if (_selectedFilter == "Songs") {
      return _projects.where((p) => p.mode == AppMode.songRemover).toList();
    }
    if (_selectedFilter == "Done") {
      return _projects.where((p) => p.status == 'done').toList();
    }
    if (_selectedFilter == "Drafts") {
      return _projects.where((p) => p.status == 'draft').toList();
    }
    return _projects;
  }

  @override
  Widget build(BuildContext context) {
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
                // Filter chips
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

                // Projects List
                Expanded(
                  child: _filteredProjects.isEmpty
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
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          itemCount: _filteredProjects.length,
                          itemBuilder: (context, index) {
                            final p = _filteredProjects[index];
                            final bool isMode1 = p.mode == AppMode.longVideoToShorts;
                            final isSong = p.mode == AppMode.songRemover;
                            final hasThumb = p.thumbnailPath != null && File(p.thumbnailPath!).existsSync();

                            return GestureDetector(
                              onTap: () {
                                if (p.outputPaths.isNotEmpty || p.clips.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ResultsScreen(
                                        project: p,
                                        renderedClips: p.clips.isNotEmpty
                                            ? p.clips
                                            : p.outputPaths
                                                .map((path) => ClipItem(
                                                      id: "clip_${path.hashCode}",
                                                      title: p.title,
                                                      duration: "",
                                                      startTime: 0,
                                                      endTime: 0,
                                                      score: 100,
                                                      tag: isSong ? "Song" : "Shielded",
                                                      outputPath: path,
                                                      thumbnailPath: p.thumbnailPath,
                                                      isRendered: true,
                                                    ))
                                                .toList(),
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: Row(
                                  children: [
                                    // Thumbnail
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
                                              isSong
                                                  ? Icons.music_note
                                                  : (isMode1 ? Icons.auto_awesome : Icons.security),
                                              color: isSong
                                                  ? Colors.green
                                                  : (isMode1 ? AppColors.accentTangerine : AppColors.accentGrape),
                                              size: 22,
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
                                                  isSong
                                                      ? "SONGS"
                                                      : (isMode1 ? "SHORTS" : "TRANSFORM"),
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
                                            "${p.clipsCount} clips · ${p.aspectRatio.label}",
                                            style: const TextStyle(fontSize: 12, color: AppColors.mut),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // Status Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: p.status == 'done'
                                            ? AppColors.softTangerine
                                            : (p.status == 'rendering'
                                                ? Colors.orange.withOpacity(0.15)
                                                : Colors.grey.withOpacity(0.12)),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        p.status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: p.status == 'done'
                                              ? AppColors.accentTangerine
                                              : (p.status == 'rendering' ? Colors.orange : AppColors.mut),
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
}
