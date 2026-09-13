import 'package:flutter/material.dart';
import '../models/app_modes.dart';
import '../models/project_model.dart';
import '../services/project_storage_service.dart';
import '../services/render_job_service.dart';
import '../theme/app_theme.dart';
import 'results_screen.dart';

/// Live status page for a render job. This screen does **not** run the render —
/// [RenderJobService] owns the job and keeps running whether or not this screen
/// is on the stack. Everything shown here is read from the job state.
class ProcessingScreen extends StatefulWidget {
  final String projectId;
  final AppMode mode;
  final String title;

  const ProcessingScreen({
    super.key,
    required this.projectId,
    required this.mode,
    required this.title,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  bool _navigatedToResults = false;

  List<String> get _pipelineSteps {
    switch (widget.mode) {
      case AppMode.transformAndProtect:
        return const [
          "Analyzing source media",
          "Applying audio transformations",
          "Geometric perturbation layer",
          "Color & gamma defense layer",
          "Blur & ambient layers",
          "Encoding protected output",
        ];
      case AppMode.songRemover:
        return const [
          "Extracting audio stream",
          "Applying DSP transformations",
          "Processing output mode",
          "Compositing cover image",
          "Encoding final output",
          "Generating thumbnail",
        ];
      case AppMode.longVideoToShorts:
        return const [
          "Probing & source verification",
          "Aspect reframing & boundary clamping",
          "Facial centroid subject tracking",
          "Parametric equalization & pitch modulation",
          "Applying chromatic & geometric layers",
          "H.264 transcoding & thumbnail export",
        ];
    }
  }

  Future<void> _openResults(RenderJobState job) async {
    if (_navigatedToResults) return;
    _navigatedToResults = true;

    final project = await ProjectStorageService.getProject(widget.projectId);
    if (!mounted) return;

    // Guard: never open the "ready" screen for anything that is not genuinely
    // finished with artifacts on disk.
    if (project == null || !project.isReady) {
      _navigatedToResults = false;
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultsScreen(
          project: project,
          renderedClips: project.clips.where((c) => c.isRendered).toList(),
        ),
      ),
    );
  }

  Future<void> _confirmCancel() async {
    final bool? cancelIt = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text("Cancel this render?", style: TextStyle(color: AppColors.ink)),
        content: const Text(
          "The job will stop and the project will be marked as canceled. "
          "Closing this screen instead keeps it rendering in the background.",
          style: TextStyle(color: AppColors.mut),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Keep rendering", style: TextStyle(color: AppColors.mut)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Cancel render", style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (cancelIt != true) return;
    await RenderJobService.instance.cancel(widget.projectId);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, RenderJobState>>(
      valueListenable: RenderJobService.instance.jobs,
      builder: (context, allJobs, _) {
        final job = allJobs[widget.projectId];

        if (job != null && job.isCompleted) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _openResults(job));
        }

        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              job?.statusLabel ?? "Render status",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.ink),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: job == null
                  ? _buildUnknownJob()
                  : (job.isActive ? _buildActive(job) : _buildTerminal(job)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnknownJob() {
    // The job is not in this session's map (e.g. the app was restarted). Fall
    // back to the persisted project so the screen still tells the truth.
    return FutureBuilder<ProjectItem?>(
      future: ProjectStorageService.getProject(widget.projectId),
      builder: (context, snapshot) {
        if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accentTangerine));
        }
        final project = snapshot.data;
        if (project == null) {
          return _buildMessage(
            icon: Icons.help_outline,
            color: AppColors.mut,
            title: "Project not found",
            body: "This render job is no longer available.",
          );
        }
        if (project.isReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _navigatedToResults) return;
            _navigatedToResults = true;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ResultsScreen(
                  project: project,
                  renderedClips: project.clips.where((c) => c.isRendered).toList(),
                ),
              ),
            );
          });
          return const Center(child: CircularProgressIndicator(color: AppColors.accentTangerine));
        }
        return _buildMessage(
          icon: project.status == ProjectStatus.failed ? Icons.error_outline : Icons.pause_circle_outline,
          color: project.status == ProjectStatus.failed ? AppColors.error : AppColors.mut,
          title: "Render ${project.statusLabel.toLowerCase()}",
          body: project.renderError ??
              "This job was interrupted before it finished. Start the render again to produce the clips.",
        );
      },
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: color),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.mut, height: 1.45),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => Navigator.maybePop(context),
            style: OutlinedButton.styleFrom(minimumSize: const Size(200, 48)),
            child: const Text("Back to projects"),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminal(RenderJobState job) {
    if (job.isFailed) {
      return _buildMessage(
        icon: Icons.error_outline,
        color: AppColors.error,
        title: "Render failed",
        body: job.error?.trim().isNotEmpty == true
            ? job.error!
            : "The encoder did not produce the expected output.",
      );
    }
    if (job.isCanceled) {
      return _buildMessage(
        icon: Icons.cancel_outlined,
        color: AppColors.mut,
        title: "Render canceled",
        body: job.renderedClips > 0
            ? "${job.renderedClips} of ${job.totalClips} clips were finished before cancellation."
            : "No clips were produced.",
      );
    }
    // Completed: _openResults is already navigating.
    return const Center(child: CircularProgressIndicator(color: AppColors.accentTangerine));
  }

  Widget _buildActive(RenderJobState job) {
    final int pct = job.progressPercent;
    final steps = _pipelineSteps;
    final int activeStepIdx = (job.progress * steps.length).toInt().clamp(0, steps.length - 1);
    final logs = RenderJobService.instance.logsFor(widget.projectId);

    return Column(
      children: [
        Text(
          job.status == RenderJobStatus.queued ? "Queued for rendering" : "Rendering Your Media",
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "${job.totalClips} clip${job.totalClips == 1 ? '' : 's'} · on-device media engine",
          style: const TextStyle(fontSize: 13.5, color: AppColors.mut),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.softTangerine,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            "Running in background · you can leave this screen",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentTangerine),
          ),
        ),
        const SizedBox(height: 20),

        // Progress canvas
        Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentTangerine.withOpacity(0.18),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1E28), Color(0xFF14141E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.accentTangerine.withOpacity(0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 96,
                height: 96,
                child: CircularProgressIndicator(
                  value: job.progress > 0 ? job.progress : null,
                  strokeWidth: 6,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentTangerine),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "$pct%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentTangerine.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${job.renderedClips}/${job.totalClips} CLIPS DONE",
                      style: const TextStyle(
                        color: AppColors.accentTangerine,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.line),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListView.builder(
              itemCount: steps.length,
              itemBuilder: (context, index) {
                final bool isDone = index < activeStepIdx;
                final bool isActive = index == activeStepIdx && job.status == RenderJobStatus.rendering;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone
                              ? AppColors.accentTangerine
                              : (isActive ? AppColors.softTangerine : AppColors.line.withOpacity(0.3)),
                        ),
                        child: isDone
                            ? const Icon(Icons.check, size: 15, color: Colors.white)
                            : (isActive
                                ? const Center(
                                    child: SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.accentTangerine,
                                      ),
                                    ),
                                  )
                                : null),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          steps[index],
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDone || isActive ? AppColors.ink : AppColors.mut,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),

        Text(
          logs.isNotEmpty ? logs.last : job.currentStage,
          style: const TextStyle(fontSize: 12, color: AppColors.mut, fontStyle: FontStyle.italic),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _confirmCancel,
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: const Text("Cancel render", style: TextStyle(color: AppColors.error)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.maybePop(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: AppColors.accentTangerine,
                ),
                child: const Text("Run in background"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
