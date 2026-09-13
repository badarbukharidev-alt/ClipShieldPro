/// Metadata fetched for a YouTube source, kept alongside the project so the
/// results screen can offer the title, description and keywords for copying
/// long after the original link was pasted.
class SourceMetadata {
  final String videoId;
  final String title;
  final String author;
  final String description;
  final List<String> keywords;

  /// Standard-resolution thumbnail, used for inline previews.
  final String thumbnailUrl;

  /// Highest resolution YouTube offers, used for the full-HD download.
  final String thumbnailMaxResUrl;

  final int durationSeconds;

  const SourceMetadata({
    required this.videoId,
    required this.title,
    this.author = '',
    this.description = '',
    this.keywords = const [],
    this.thumbnailUrl = '',
    this.thumbnailMaxResUrl = '',
    this.durationSeconds = 0,
  });

  /// Anything past three minutes is treated as long-form, which is where the
  /// extra metadata panel earns its space.
  bool get isLongForm => durationSeconds > 180;

  /// Keywords as a single comma-separated string, ready to paste into the
  /// YouTube tags box.
  String get keywordsCsv => keywords.join(', ');

  String get formattedDuration {
    if (durationSeconds <= 0) return '--:--';
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
  }

  Map<String, dynamic> toMap() => {
        'videoId': videoId,
        'title': title,
        'author': author,
        'description': description,
        'keywords': keywords,
        'thumbnailUrl': thumbnailUrl,
        'thumbnailMaxResUrl': thumbnailMaxResUrl,
        'durationSeconds': durationSeconds,
      };

  static SourceMetadata? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final id = map['videoId'];
    if (id is! String || id.isEmpty) return null;
    return SourceMetadata(
      videoId: id,
      title: map['title'] as String? ?? '',
      author: map['author'] as String? ?? '',
      description: map['description'] as String? ?? '',
      keywords: (map['keywords'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      thumbnailUrl: map['thumbnailUrl'] as String? ?? '',
      thumbnailMaxResUrl: map['thumbnailMaxResUrl'] as String? ?? '',
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}
