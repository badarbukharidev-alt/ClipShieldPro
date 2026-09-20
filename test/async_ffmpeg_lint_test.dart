import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FFmpeg Async Execution and Device Tiers', () {
    test('Zero synchronous FFmpeg execution calls exist in lib/', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final violations = <String>[];
      // Regex that matches synchronous FFmpegKit.executeWithArguments(
      // but NOT FFmpegKit.executeWithArgumentsAsync(
      final syncExecPattern = RegExp(r'FFmpegKit\s*\.\s*executeWithArguments\s*\(');

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final content = entity.readAsStringSync();
          final lines = content.split('\n');
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (syncExecPattern.hasMatch(line)) {
              violations.add('${entity.path}:${i + 1}: ${line.trim()}');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Synchronous FFmpeg execution blocks the Android main/method-channel thread '
            'and causes ANR on devices. Use FFmpegKit.executeWithArgumentsAsync instead.\n'
            'Violations found:\n${violations.join('\n')}',
      );
    });

    test('SongRemoverPipeline respects DeviceCapabilityService tier caps', () {
      final pipelineFile = File('lib/transformation/song_remover_pipeline.dart');
      expect(pipelineFile.existsSync(), isTrue);

      final content = pipelineFile.readAsStringSync();
      expect(
        content.contains('DeviceCapabilityService.instance.maxOutputHeight'),
        isTrue,
        reason: 'SongRemoverPipeline must dynamically respect tier-capped max output resolution',
      );
    });

    test('FFmpegEngineService uses async execution for all operations', () {
      final engineFile = File('lib/services/ffmpeg_engine_service.dart');
      expect(engineFile.existsSync(), isTrue);

      final content = engineFile.readAsStringSync();
      expect(content.contains('executeWithArgumentsAsync'), isTrue);
      expect(content.contains('executeWithArguments('), isFalse);
    });
  });
}
