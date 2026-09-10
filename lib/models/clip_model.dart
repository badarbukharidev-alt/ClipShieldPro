import 'dart:convert';

class ClipItem {
  final String id;
  String title;
  final String duration;
  final double startTime;
  final double endTime;
  final int score;
  final String tag;
  final String? reason;
  String? cropCoordinates; // format: "w:h:x:y"
  bool isSelected;
  String? outputPath;
  String? thumbnailPath;
  bool isRendered;

  ClipItem({
    required this.id,
    required this.title,
    required this.duration,
    required this.startTime,
    required this.endTime,
    required this.score,
    required this.tag,
    this.reason,
    this.cropCoordinates,
    this.isSelected = true,
    this.outputPath,
    this.thumbnailPath,
    this.isRendered = false,
  });

  double get durationSeconds => endTime - startTime;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'duration': duration,
      'startTime': startTime,
      'endTime': endTime,
      'score': score,
      'tag': tag,
      'reason': reason,
      'cropCoordinates': cropCoordinates,
      'isSelected': isSelected,
      'outputPath': outputPath,
      'thumbnailPath': thumbnailPath,
      'isRendered': isRendered,
    };
  }

  factory ClipItem.fromMap(Map<String, dynamic> map) {
    return ClipItem(
      id: map['id'] as String,
      title: map['title'] as String,
      duration: map['duration'] as String,
      startTime: (map['startTime'] as num).toDouble(),
      endTime: (map['endTime'] as num).toDouble(),
      score: map['score'] as int? ?? 85,
      tag: map['tag'] as String? ?? 'Highlight',
      reason: map['reason'] as String?,
      cropCoordinates: map['cropCoordinates'] as String?,
      isSelected: map['isSelected'] as bool? ?? true,
      outputPath: map['outputPath'] as String?,
      thumbnailPath: map['thumbnailPath'] as String?,
      isRendered: map['isRendered'] as bool? ?? false,
    );
  }

  String toJson() => json.encode(toMap());
  factory ClipItem.fromJson(String source) => ClipItem.fromMap(json.decode(source));
}
