import 'dart:convert';
import 'app_modes.dart';
import 'clip_model.dart';

/// Canonical project lifecycle values. A project is only "ready" when a render
/// job has genuinely finished and produced files on disk.
class ProjectStatus {
  static const String draft = 'draft';
  static const String queued = 'queued';
  static const String rendering = 'rendering';
  static const String done = 'done';
  static const String failed = 'failed';
  static const String canceled = 'canceled';

  static String label(String status) {
    switch (status) {
      case queued:
        return 'Queued';
      case rendering:
        return 'Rendering';
      case done:
        return 'Completed';
      case failed:
        return 'Failed';
      case canceled:
        return 'Canceled';
      case draft:
        return 'Draft';
      default:
        return status.toUpperCase();
    }
  }
}

class ProjectItem {
  final String id;
  final AppMode mode;
  String title;
  final String sourceUrlOrPath;
  final SourceType sourceType;
  final DateTime createdAt;
  String status; // see [ProjectStatus]
  List<ClipItem> clips;
  List<String> outputPaths;
  String? thumbnailPath;
  PipelinePreset preset;
  AspectRatioOption aspectRatio;
  Map<String, dynamic> settings;

  ProjectItem({
    required this.id,
    required this.mode,
    required this.title,
    required this.sourceUrlOrPath,
    required this.sourceType,
    DateTime? createdAt,
    this.status = ProjectStatus.draft,
    List<ClipItem>? clips,
    List<String>? outputPaths,
    this.thumbnailPath,
    this.preset = PipelinePreset.balanced,
    this.aspectRatio = AspectRatioOption.vertical916,
    Map<String, dynamic>? settings,
  })  : createdAt = createdAt ?? DateTime.now(),
        clips = clips ?? [],
        outputPaths = outputPaths ?? [],
        settings = settings ?? {};

  /// Number of clips this project is responsible for. While a job is in flight
  /// this is the number of clips actually submitted, never the number that were
  /// merely detected.
  int get clipsCount => clips.isNotEmpty ? clips.length : outputPaths.length;

  /// Clips that have a verified artifact on disk.
  int get renderedClipsCount =>
      clips.isNotEmpty ? clips.where((c) => c.isRendered).length : outputPaths.length;

  bool get isRenderingOrQueued =>
      status == ProjectStatus.rendering || status == ProjectStatus.queued;

  /// The only condition under which result/"ready" screens may be shown.
  bool get isReady => status == ProjectStatus.done && outputPaths.isNotEmpty;

  String get statusLabel => ProjectStatus.label(status);

  String? get renderError => settings['renderError'] as String?;

  /// A fresh, independent history entry for one render submission, carrying
  /// only the clips actually being rendered.
  ProjectItem copyForRender({
    required List<ClipItem> clipsToRender,
    AspectRatioOption? aspectRatio,
  }) {
    return ProjectItem(
      id: 'render_${DateTime.now().microsecondsSinceEpoch}',
      mode: mode,
      title: title,
      sourceUrlOrPath: sourceUrlOrPath,
      sourceType: sourceType,
      status: ProjectStatus.queued,
      clips: clipsToRender.map((c) => ClipItem.fromMap(c.toMap())).toList(),
      preset: preset,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      settings: Map<String, dynamic>.from(settings),
    );
  }

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 60) {
      return "${diff.inMinutes}m ago";
    } else if (diff.inHours < 24) {
      return "${diff.inHours}h ago";
    } else if (diff.inDays < 7) {
      return "${diff.inDays}d ago";
    } else {
      return "${(diff.inDays / 7).floor()}w ago";
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mode': mode.name,
      'title': title,
      'sourceUrlOrPath': sourceUrlOrPath,
      'sourceType': sourceType.name,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'clips': clips.map((x) => x.toMap()).toList(),
      'outputPaths': outputPaths,
      'thumbnailPath': thumbnailPath,
      'preset': preset.name,
      'aspectRatio': aspectRatio.name,
      'settings': settings,
    };
  }

  factory ProjectItem.fromMap(Map<String, dynamic> map) {
    return ProjectItem(
      id: map['id'] as String,
      mode: AppMode.values.firstWhere(
        (e) => e.name == map['mode'],
        orElse: () => AppMode.longVideoToShorts,
      ),
      title: map['title'] as String,
      sourceUrlOrPath: map['sourceUrlOrPath'] as String,
      sourceType: SourceType.values.firstWhere(
        (e) => e.name == map['sourceType'],
        orElse: () => SourceType.youtubeUrl,
      ),
      createdAt: DateTime.parse(map['createdAt'] as String),
      status: map['status'] as String? ?? ProjectStatus.done,
      clips: (map['clips'] as List<dynamic>?)
              ?.map((x) => ClipItem.fromMap(x as Map<String, dynamic>))
              .toList() ??
          [],
      outputPaths: List<String>.from(map['outputPaths'] ?? []),
      thumbnailPath: map['thumbnailPath'] as String?,
      preset: PipelinePreset.values.firstWhere(
        (e) => e.name == map['preset'],
        orElse: () => PipelinePreset.balanced,
      ),
      aspectRatio: AspectRatioOption.values.firstWhere(
        (e) => e.name == map['aspectRatio'],
        orElse: () => AspectRatioOption.vertical916,
      ),
      settings: Map<String, dynamic>.from(map['settings'] ?? {}),
    );
  }

  String toJson() => json.encode(toMap());
  factory ProjectItem.fromJson(String source) => ProjectItem.fromMap(json.decode(source));
}
