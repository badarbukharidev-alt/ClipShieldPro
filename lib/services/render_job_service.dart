import 'package:flutter/foundation.dart';

class RenderJobState {
  final String projectId;
  final String title;
  double progress;
  String currentStage;
  bool isCompleted;
  bool isFailed;
  String? error;
  List<String> outputPaths;

  RenderJobState({
    required this.projectId,
    required this.title,
    this.progress = 0.0,
    this.currentStage = 'Starting...',
    this.isCompleted = false,
    this.isFailed = false,
    this.error,
    this.outputPaths = const [],
  });
}

class RenderJobService {
  RenderJobService._privateConstructor();
  static final RenderJobService instance = RenderJobService._privateConstructor();

  final ValueNotifier<RenderJobState?> activeJob = ValueNotifier(null);

  void startJob({required String projectId, required String title}) {
    activeJob.value = RenderJobState(projectId: projectId, title: title);
  }

  void updateProgress(double progress, String stage) {
    if (activeJob.value != null) {
      activeJob.value = RenderJobState(
        projectId: activeJob.value!.projectId,
        title: activeJob.value!.title,
        progress: progress,
        currentStage: stage,
        isCompleted: activeJob.value!.isCompleted,
        isFailed: activeJob.value!.isFailed,
        error: activeJob.value!.error,
        outputPaths: activeJob.value!.outputPaths,
      );
    }
  }

  void completeJob(List<String> outputPaths) {
    if (activeJob.value != null) {
      activeJob.value = RenderJobState(
        projectId: activeJob.value!.projectId,
        title: activeJob.value!.title,
        progress: 1.0,
        currentStage: 'Completed',
        isCompleted: true,
        isFailed: false,
        error: null,
        outputPaths: outputPaths,
      );
    }
  }

  void failJob(String error) {
    if (activeJob.value != null) {
      activeJob.value = RenderJobState(
        projectId: activeJob.value!.projectId,
        title: activeJob.value!.title,
        progress: activeJob.value!.progress,
        currentStage: 'Failed',
        isCompleted: false,
        isFailed: true,
        error: error,
        outputPaths: activeJob.value!.outputPaths,
      );
    }
  }

  void cancelJob() {
    activeJob.value = null;
  }
}
