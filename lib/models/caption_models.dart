/// A single caption line with its timing.
class CaptionCue {
  final double startSeconds;
  final double endSeconds;
  final String text;

  const CaptionCue({
    required this.startSeconds,
    required this.endSeconds,
    required this.text,
  });

  double get duration => (endSeconds - startSeconds).abs();

  /// Splits the cue into words with estimated per-word timings.
  ///
  /// Source captions only carry line-level timing, so word timings are
  /// approximated by weighting each word by its length. This is what the
  /// popular caption tools do, and at reading speed it tracks closely enough
  /// for a highlight to feel synced.
  List<CaptionWord> toWords() {
    final tokens = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (tokens.isEmpty) return const [];

    final totalWeight = tokens.fold<int>(0, (sum, w) => sum + w.length + 1);
    final span = duration <= 0 ? tokens.length * 0.3 : duration;

    final words = <CaptionWord>[];
    double cursor = startSeconds;
    for (final token in tokens) {
      final share = ((token.length + 1) / totalWeight) * span;
      words.add(CaptionWord(
        text: token,
        startSeconds: cursor,
        endSeconds: cursor + share,
      ));
      cursor += share;
    }
    return words;
  }

  /// Re-times relative to a clip that starts at [clipStart].
  CaptionCue shifted(double clipStart) => CaptionCue(
        startSeconds: startSeconds - clipStart,
        endSeconds: endSeconds - clipStart,
        text: text,
      );

  Map<String, dynamic> toMap() => {
        'start': startSeconds,
        'end': endSeconds,
        'text': text,
      };

  factory CaptionCue.fromMap(Map<String, dynamic> map) => CaptionCue(
        startSeconds: (map['start'] as num?)?.toDouble() ?? 0,
        endSeconds: (map['end'] as num?)?.toDouble() ?? 0,
        text: map['text'] as String? ?? '',
      );
}

class CaptionWord {
  final String text;
  final double startSeconds;
  final double endSeconds;

  const CaptionWord({
    required this.text,
    required this.startSeconds,
    required this.endSeconds,
  });

  double get duration => (endSeconds - startSeconds).abs();
}

/// Utilities for reshaping a caption track before it is burned in.
class CaptionTrack {
  /// Keeps only the cues overlapping [start]..[end], re-timed to the clip.
  ///
  /// Clips are cut out of a longer source, so the source's absolute timings
  /// have to be rebased or every caption lands at the wrong moment.
  static List<CaptionCue> forClip(
    List<CaptionCue> cues,
    double start,
    double end,
  ) {
    final result = <CaptionCue>[];
    for (final cue in cues) {
      if (cue.endSeconds <= start || cue.startSeconds >= end) continue;

      final clampedStart = cue.startSeconds < start ? start : cue.startSeconds;
      final clampedEnd = cue.endSeconds > end ? end : cue.endSeconds;
      if (clampedEnd - clampedStart < 0.05) continue;

      result.add(CaptionCue(
        startSeconds: clampedStart - start,
        endSeconds: clampedEnd - start,
        text: cue.text,
      ));
    }
    return result;
  }

  /// Breaks long lines so captions never overflow a vertical frame.
  ///
  /// Short bursts are also what the trending caption styles rely on for their
  /// rhythm — a full sentence on screen reads as a subtitle, not a caption.
  static List<CaptionCue> chunk(List<CaptionCue> cues, {int maxWords = 4}) {
    if (maxWords < 1) return cues;

    final result = <CaptionCue>[];
    for (final cue in cues) {
      final words = cue.toWords();
      if (words.length <= maxWords) {
        result.add(cue);
        continue;
      }

      for (var i = 0; i < words.length; i += maxWords) {
        final slice = words.sublist(i, (i + maxWords).clamp(0, words.length));
        result.add(CaptionCue(
          startSeconds: slice.first.startSeconds,
          endSeconds: slice.last.endSeconds,
          text: slice.map((w) => w.text).join(' '),
        ));
      }
    }
    return result;
  }
}
