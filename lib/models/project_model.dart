import 'dart:convert';
import 'app_modes.dart';
import 'clip_model.dart';

class ProjectItem {
  final String id;
  final AppMode mode;
  String title;
  final String sourceUrlOrPath;
  final SourceType sourceType;
  final DateTime createdAt;
  String status; // 'done', 'rendering', 'draft', 'failed'
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
    this.status = 'draft',
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

  int get clipsCount => clips.isNotEmpty ? clips.length : (outputPaths.isNotEmpty ? outputPaths.length : 1);

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
      status: map['status'] as String? ?? 'done',
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
