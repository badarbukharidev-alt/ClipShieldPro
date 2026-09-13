import 'package:flutter_test/flutter_test.dart';
import 'package:clipshield/models/app_modes.dart';
import 'package:clipshield/models/project_model.dart';
import 'package:clipshield/models/source_metadata.dart';

ProjectItem project({
  AppMode mode = AppMode.longVideoToShorts,
  AspectRatioOption aspect = AspectRatioOption.vertical916,
  Map<String, dynamic>? settings,
}) {
  return ProjectItem(
    id: 'p1',
    mode: mode,
    title: 'T',
    sourceUrlOrPath: '/tmp/a.mp4',
    sourceType: SourceType.youtubeUrl,
    aspectRatio: aspect,
    settings: settings,
  );
}

void main() {
  group('project aspect', () {
    test('copyright projects are always widescreen', () {
      final p = project(
        mode: AppMode.transformAndProtect,
        aspect: AspectRatioOption.vertical916,
      );
      expect(p.isWidescreen, isTrue,
          reason: 'a 16:9 copyright export must never be framed as a Short');
      expect(p.displayAspectRatio, closeTo(16 / 9, 0.001));
    });

    test('an explicit 16:9 shorts project is widescreen', () {
      expect(project(aspect: AspectRatioOption.original169).isWidescreen, isTrue);
    });

    test('a 9:16 shorts project is not widescreen', () {
      final p = project();
      expect(p.isWidescreen, isFalse);
      expect(p.displayAspectRatio, closeTo(9 / 16, 0.001));
    });
  });

  group('source metadata', () {
    const meta = SourceMetadata(
      videoId: 'abc12345678',
      title: 'Example Title',
      author: 'Channel',
      description: 'Line one\nLine two',
      keywords: ['alpha', 'beta', 'gamma'],
      thumbnailUrl: 'https://img/hq.jpg',
      thumbnailMaxResUrl: 'https://img/max.jpg',
      durationSeconds: 742,
    );

    test('keywords are comma separated for pasting into tags', () {
      expect(meta.keywordsCsv, 'alpha, beta, gamma');
    });

    test('long form is anything past three minutes', () {
      expect(meta.isLongForm, isTrue);
      expect(
        const SourceMetadata(videoId: 'x', title: 't', durationSeconds: 45).isLongForm,
        isFalse,
      );
    });

    test('duration formats with hours only when needed', () {
      expect(meta.formattedDuration, '12:22');
      expect(
        const SourceMetadata(videoId: 'x', title: 't', durationSeconds: 3725)
            .formattedDuration,
        '1:02:05',
      );
      expect(
        const SourceMetadata(videoId: 'x', title: 't').formattedDuration,
        '--:--',
      );
    });

    test('survives a round trip through project settings', () {
      final p = project(settings: {'sourceMeta': meta.toMap()});
      final restored = p.sourceMetadata;

      expect(restored, isNotNull);
      expect(restored!.title, 'Example Title');
      expect(restored.keywords, ['alpha', 'beta', 'gamma']);
      expect(restored.thumbnailMaxResUrl, 'https://img/max.jpg');
      expect(restored.durationSeconds, 742);
    });

    test('a project without metadata reports none', () {
      expect(project().sourceMetadata, isNull);
      expect(project(settings: {'sourceMeta': {}}).sourceMetadata, isNull);
    });
  });
}
