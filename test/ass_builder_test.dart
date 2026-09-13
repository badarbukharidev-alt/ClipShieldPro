import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipshield/models/caption_models.dart';
import 'package:clipshield/models/caption_style.dart';
import 'package:clipshield/transformation/ass_subtitle_builder.dart';

void main() {
  const cues = [
    CaptionCue(startSeconds: 0.0, endSeconds: 1.5, text: 'this changes everything'),
    CaptionCue(startSeconds: 1.5, endSeconds: 3.0, text: 'watch what happens next'),
  ];

  group('ASS colour encoding', () {
    test('uses AABBGGRR byte order, not RGB', () {
      // Pure red must land in the last pair, not the first.
      expect(AssSubtitleBuilder.assColor(const Color(0xFFFF0000)), '&H000000FF');
      expect(AssSubtitleBuilder.assColor(const Color(0xFF0000FF)), '&H00FF0000');
      expect(AssSubtitleBuilder.assColor(const Color(0xFF00FF00)), '&H0000FF00');
      expect(AssSubtitleBuilder.assColor(Colors.white), '&H00FFFFFF');
    });

    test('honours an alpha override', () {
      expect(AssSubtitleBuilder.assColor(Colors.black, alphaOverride: 40), '&H28000000');
    });
  });

  group('ASS timestamps', () {
    test('format as H:MM:SS.cc', () {
      expect(AssSubtitleBuilder.assTime(0), '0:00:00.00');
      expect(AssSubtitleBuilder.assTime(1.5), '0:00:01.50');
      expect(AssSubtitleBuilder.assTime(3725.25), '1:02:05.25');
    });

    test('never emit negative times', () {
      expect(AssSubtitleBuilder.assTime(-5), '0:00:00.00');
    });
  });

  group('word timing', () {
    test('words span the cue and stay in order', () {
      const cue = CaptionCue(startSeconds: 10, endSeconds: 12, text: 'one two three');
      final words = cue.toWords();

      expect(words.length, 3);
      expect(words.first.startSeconds, closeTo(10, 0.001));
      expect(words.last.endSeconds, closeTo(12, 0.05));
      for (var i = 1; i < words.length; i++) {
        expect(words[i].startSeconds, greaterThanOrEqualTo(words[i - 1].startSeconds));
      }
    });
  });

  group('clip re-timing', () {
    test('cues are rebased onto the clip, not left at source time', () {
      const source = [
        CaptionCue(startSeconds: 100, endSeconds: 102, text: 'inside'),
        CaptionCue(startSeconds: 5, endSeconds: 7, text: 'before'),
        CaptionCue(startSeconds: 500, endSeconds: 502, text: 'after'),
      ];

      final clipped = CaptionTrack.forClip(source, 99, 110);
      expect(clipped.length, 1);
      expect(clipped.first.text, 'inside');
      expect(clipped.first.startSeconds, closeTo(1, 0.001));
    });

    test('partially overlapping cues are clamped to the clip', () {
      const source = [CaptionCue(startSeconds: 95, endSeconds: 105, text: 'straddles')];
      final clipped = CaptionTrack.forClip(source, 100, 110);
      expect(clipped.first.startSeconds, closeTo(0, 0.001));
      expect(clipped.first.endSeconds, closeTo(5, 0.001));
    });
  });

  group('chunking', () {
    test('long lines break into short bursts', () {
      const cue = CaptionCue(
        startSeconds: 0,
        endSeconds: 4,
        text: 'one two three four five six seven eight',
      );
      final chunks = CaptionTrack.chunk([cue], maxWords: 3);
      expect(chunks.length, 3);
      expect(chunks.first.text.split(' ').length, 3);
    });
  });

  group('document structure', () {
    test('header declares the output canvas', () {
      final ass = AssSubtitleBuilder.build(
        cues: cues, preset: CaptionPresets.hormozi, width: 1080, height: 1920);
      expect(ass, contains('PlayResX: 1080'));
      expect(ass, contains('PlayResY: 1920'));
      expect(ass, contains('[V4+ Styles]'));
      expect(ass, contains('[Events]'));
    });

    test('all caps preset uppercases the text', () {
      final ass = AssSubtitleBuilder.build(
        cues: cues, preset: CaptionPresets.hormozi, width: 1080, height: 1920);
      expect(ass, contains('THIS'));
      expect(ass.contains('Dialogue: 0,0:00:00.00'), isTrue);
    });

    test('word highlight emits karaoke tags', () {
      final ass = AssSubtitleBuilder.build(
        cues: cues, preset: CaptionPresets.karaoke, width: 1080, height: 1920);
      final bs = String.fromCharCode(92);
      expect(ass, contains('${bs}kf'));
    });

    test('pop in emits scale transforms', () {
      final ass = AssSubtitleBuilder.build(
        cues: cues, preset: CaptionPresets.beast, width: 1080, height: 1920);
      final bs = String.fromCharCode(92);
      expect(ass, contains('${bs}t('));
      expect(ass, contains('${bs}fscx'));
    });

    test('typewriter emits one event per word', () {
      final ass = AssSubtitleBuilder.build(
        cues: const [CaptionCue(startSeconds: 0, endSeconds: 2, text: 'a b c')],
        preset: CaptionPresets.typewriter, width: 1080, height: 1920);
      final events =
          ass.split('\n').where((l) => l.startsWith('Dialogue:')).length;
      expect(events, 3, reason: 'one dialogue event per word reveal');
    });

    test('box preset uses BorderStyle 3', () {
      final ass = AssSubtitleBuilder.build(
        cues: cues, preset: CaptionPresets.tiktok, width: 1080, height: 1920);
      final styleLine = ass.split('\n').firstWhere((l) => l.startsWith('Style: Caption'));
      expect(styleLine.split(',')[15], '3');
    });

    test('braces in caption text are escaped', () {
      final ass = AssSubtitleBuilder.build(
        cues: const [CaptionCue(startSeconds: 0, endSeconds: 1, text: 'a {b} c')],
        preset: CaptionPresets.minimal, width: 1080, height: 1920);
      final bs = String.fromCharCode(92);
      expect(ass, contains("$bs{b$bs}"));
    });
  });

  group('filter path escaping', () {
    test('colons are escaped so the filtergraph parses', () {
      // Built from a char code so no escaping layer can silently drop the
      // backslash — Dart treats an unknown escape like \: as a bare colon.
      final bs = String.fromCharCode(92);
      expect(
        AssSubtitleBuilder.escapeFilterPath(r'C:\temp\subs.ass'),
        'C$bs:/temp/subs.ass',
      );
    });
  });

  group('every preset produces a parseable document', () {
    for (final preset in CaptionPresets.all) {
      test(preset.id, () {
        final ass = AssSubtitleBuilder.build(
          cues: cues, preset: preset, width: 1080, height: 1920);
        expect(ass, contains('[Events]'));
        expect(ass.split('\n').where((l) => l.startsWith('Dialogue:')).length,
            greaterThan(0));
      });
    }
  });

  test('writes a sample file for the ffmpeg smoke test', () async {
    final dir = Directory('build/caption_samples')..createSync(recursive: true);
    for (final preset in CaptionPresets.all) {
      final ass = AssSubtitleBuilder.build(
        cues: const [
          CaptionCue(startSeconds: 0.0, endSeconds: 1.6, text: 'this changes everything'),
          CaptionCue(startSeconds: 1.6, endSeconds: 3.2, text: 'watch what happens next'),
        ],
        preset: preset,
        width: 1080,
        height: 1920,
      );
      File('${dir.path}/${preset.id}.ass').writeAsStringSync(ass);
    }
    expect(Directory(dir.path).listSync().length, CaptionPresets.all.length);
  });
}
