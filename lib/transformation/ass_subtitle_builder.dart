import 'package:flutter/material.dart';

import '../models/caption_models.dart';
import '../models/caption_style.dart';

/// Builds an ASS (Advanced SubStation Alpha) subtitle file for libass to burn
/// into the video.
///
/// ASS is used rather than drawtext because it gives per-word timing (`\k`),
/// transforms (`\t`), fades and precise positioning in a single pass, where
/// drawtext would need one filter instance per word.
class AssSubtitleBuilder {
  /// ASS colours are `&HAABBGGRR` — alpha first, then *reversed* RGB. Getting
  /// the byte order wrong silently swaps red and blue.
  static String assColor(Color color, {int alphaOverride = 0}) {
    final a = alphaOverride.clamp(0, 255);
    final r = color.red & 0xFF;
    final g = color.green & 0xFF;
    final b = color.blue & 0xFF;
    String hex(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '&H${hex(a)}${hex(b)}${hex(g)}${hex(r)}';
  }

  /// ASS timestamps are `H:MM:SS.cc` with centisecond precision.
  static String assTime(double seconds) {
    if (seconds < 0) seconds = 0;
    final total = (seconds * 100).round();
    final cs = total % 100;
    final totalSeconds = total ~/ 100;
    final s = totalSeconds % 60;
    final m = (totalSeconds ~/ 60) % 60;
    final h = totalSeconds ~/ 3600;
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        '.${cs.toString().padLeft(2, '0')}';
  }

  /// Braces and newlines are ASS control characters and must not reach libass
  /// from caption text.
  static String escape(String text) {
    return text
        // A lone backslash introduces an ASS override, so it must be doubled
        // first. This previously replaced a backslash with itself — a no-op
        // that let source text inject override tags.
        .replaceAll(r'\', r'\\')
        .replaceAll('{', r'\{')
        .replaceAll('}', r'\}')
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ');
  }

  /// Renders the full .ass document.
  ///
  /// [width]/[height] must match the output canvas so libass scales the text
  /// to the same coordinate space the video is encoded in.
  static String build({
    required List<CaptionCue> cues,
    required CaptionStylePreset preset,
    required int width,
    required int height,
  }) {
    // Scale the design size (authored against a 1080-wide canvas) to the real
    // output, so captions look identical on 720p and 1080p.
    final double scale = width / 1080.0;
    final int fontSize = (preset.fontSize * scale).round().clamp(12, 400);
    final int outline = (preset.outlineWidth * scale).round().clamp(0, 20);
    final int shadow = (preset.shadowDepth * scale).round().clamp(0, 20);
    final int marginV = ((preset.verticalMarginPercent / 100.0) * height).round();

    // BorderStyle 3 paints an opaque box; 1 is outline + shadow.
    final int borderStyle = preset.useBox ? 3 : 1;

    // Only the karaoke-fill animation consumes the Primary/Secondary pair.
    final bool isKaraokeFill = preset.animation == CaptionAnimation.wordHighlight;

    final buffer = StringBuffer()
      ..writeln('[Script Info]')
      ..writeln('ScriptType: v4.00+')
      ..writeln('WrapStyle: 2')
      ..writeln('ScaledBorderAndShadow: yes')
      ..writeln('YCbCr Matrix: TV.709')
      ..writeln('PlayResX: $width')
      ..writeln('PlayResY: $height')
      ..writeln()
      ..writeln('[V4+ Styles]')
      ..writeln('Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, '
          'OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, '
          'ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, '
          'MarginL, MarginR, MarginV, Encoding')
      ..writeln([
        'Style: Caption',
        preset.fontName,
        '$fontSize',
        // \kf sweeps text FROM SecondaryColour INTO PrimaryColour, so for the
        // karaoke fill the roles are inverted: already-spoken words must end up
        // in the highlight colour, and not-yet-spoken words in the base colour.
        // Assigning these the intuitive way round makes the highlight recede
        // instead of advance.
        assColor(isKaraokeFill ? preset.highlightColor : preset.primaryColor),
        assColor(isKaraokeFill ? preset.primaryColor : preset.highlightColor),
        assColor(preset.outlineColor),
        preset.useBox ? assColor(Colors.black, alphaOverride: 40) : assColor(Colors.black),
        preset.bold ? '-1' : '0',
        '0', '0', '0',
        '100', '100', '0', '0',
        '$borderStyle',
        '$outline',
        '$shadow',
        '2', // bottom-centre
        '60', '60', '$marginV',
        '1',
      ].join(','))
      ..writeln()
      ..writeln('[Events]')
      ..writeln('Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');

    for (final cue in cues) {
      final text = preset.allCaps ? cue.text.toUpperCase() : cue.text;
      if (text.trim().isEmpty) continue;

      final lines = _buildEvent(
        CaptionCue(
          startSeconds: cue.startSeconds,
          endSeconds: cue.endSeconds,
          text: text,
        ),
        preset,
      );
      for (final line in lines) {
        buffer.writeln(line);
      }
    }

    return buffer.toString();
  }

  /// One cue can expand to several dialogue lines (typewriter and word-pop each
  /// need a separate event per word).
  static List<String> _buildEvent(CaptionCue cue, CaptionStylePreset preset) {
    String dialogue(double start, double end, String body) {
      return 'Dialogue: 0,${assTime(start)},${assTime(end)},Caption,,0,0,0,,$body';
    }

    switch (preset.animation) {
      case CaptionAnimation.none:
        return [dialogue(cue.startSeconds, cue.endSeconds, escape(cue.text))];

      case CaptionAnimation.popIn:
        // Overshoot to 112% then settle, with a quick fade.
        const overshootMs = 90;
        const settleMs = 130;
        final body = '{\\fad(60,60)\\fscx60\\fscy60'
            '\\t(0,$overshootMs,\\fscx112\\fscy112)'
            '\\t($overshootMs,${overshootMs + settleMs},\\fscx100\\fscy100)}'
            '${escape(cue.text)}';
        return [dialogue(cue.startSeconds, cue.endSeconds, body)];

      case CaptionAnimation.slideUp:
        final body = '{\\fad(120,80)\\move(0,40,0,0,0,220)}${escape(cue.text)}';
        return [dialogue(cue.startSeconds, cue.endSeconds, body)];

      case CaptionAnimation.wordHighlight:
        // \k durations are in centiseconds and consume SecondaryColour as they
        // advance, which is exactly the karaoke fill effect.
        final words = cue.toWords();
        if (words.isEmpty) {
          return [dialogue(cue.startSeconds, cue.endSeconds, escape(cue.text))];
        }
        final body = StringBuffer('{\\fad(50,50)}');
        for (var i = 0; i < words.length; i++) {
          final cs = (words[i].duration * 100).round().clamp(1, 10000);
          body.write('{\\kf$cs}${escape(words[i].text)}');
          if (i < words.length - 1) body.write(' ');
        }
        return [dialogue(cue.startSeconds, cue.endSeconds, body.toString())];

      case CaptionAnimation.wordPop:
        // One event per word so each can carry its own scale transform.
        final words = cue.toWords();
        if (words.isEmpty) {
          return [dialogue(cue.startSeconds, cue.endSeconds, escape(cue.text))];
        }
        final lines = <String>[];
        for (var i = 0; i < words.length; i++) {
          final parts = <String>[];
          for (var j = 0; j < words.length; j++) {
            final word = escape(words[j].text);
            if (j == i) {
              parts.add('{\\c${assColor(preset.highlightColor)}'
                  '\\fscx118\\fscy118'
                  '\\t(0,110,\\fscx100\\fscy100)}$word'
                  '{\\c${assColor(preset.primaryColor)}}');
            } else {
              parts.add(word);
            }
          }
          final end = i == words.length - 1 ? cue.endSeconds : words[i + 1].startSeconds;
          if (end <= words[i].startSeconds) continue;
          lines.add(dialogue(words[i].startSeconds, end, parts.join(' ')));
        }
        return lines;

      case CaptionAnimation.typewriter:
        // Progressively longer prefixes, one event per word.
        final words = cue.toWords();
        if (words.isEmpty) {
          return [dialogue(cue.startSeconds, cue.endSeconds, escape(cue.text))];
        }
        final lines = <String>[];
        for (var i = 0; i < words.length; i++) {
          final visible = words.sublist(0, i + 1).map((w) => escape(w.text)).join(' ');
          final end = i == words.length - 1 ? cue.endSeconds : words[i + 1].startSeconds;
          if (end <= words[i].startSeconds) continue;
          lines.add(dialogue(words[i].startSeconds, end, visible));
        }
        return lines;
    }
  }

  /// Escapes a path for use inside the `subtitles=` filter argument.
  ///
  /// The filtergraph parser treats `:`, `'` and `\` specially, so a Windows
  /// path or any path with a colon breaks the graph unless escaped.
  static String escapeFilterPath(String path) {
    return path
        .replaceAll('\\', '/')
        .replaceAll(':', '\\:')
        .replaceAll("'", "\\'");
  }
}
