import 'package:flutter_test/flutter_test.dart';

import 'package:clipshield/models/app_modes.dart';
import 'package:clipshield/services/device_capability_service.dart';
import 'package:clipshield/services/render_job_service.dart';
import 'package:clipshield/transformation/layer.dart';
import 'package:clipshield/transformation/pipeline.dart';

/// The app was closing the instant Render was tapped on a range of phones.
/// The cause is that FFmpeg runs in-process: a native out-of-memory or a fatal
/// decode aborts the whole process, and no Dart/Java catch can stop it. Device
/// tiering lowered the odds; these pin the guards that close the last gaps, so a
/// heavy source or a broken layer config can no longer produce a killer command.
const int gb = 1024 * 1024 * 1024;

FilterContext ctx({
  int targetWidth = 1280,
  int targetHeight = 720,
  int targetFps = 0,
  bool hasAudio = true,
}) =>
    FilterContext(
      sourceWidth: 3840,
      sourceHeight: 2160,
      duration: 30,
      hasAudio: hasAudio,
      quality: 'balanced',
      targetWidth: targetWidth,
      targetHeight: targetHeight,
      cropCoordinates: '$targetWidth:$targetHeight:0:0',
      targetFps: targetFps,
    );

void main() {
  final caps = DeviceCapabilityService.instance;
  final pipeline = TransformationPipeline();

  tearDown(caps.debugReset);

  String vf(List<String> args) {
    final i = args.indexOf('-filter_complex');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : '';
  }

  group('allocation ceiling — the abort() guard', () {
    test('every render command bounds a single libav allocation', () {
      caps.debugSet(totalMemoryBytes: 2 * gb, heapLimitMb: 128);
      final main = pipeline.buildFfmpegArgs(
        inputPath: 'in.mp4',
        outputPath: 'out.mp4',
        start: 0,
        end: 10,
        context: ctx(),
        logCallback: (_) {},
      );
      final resilient = pipeline.buildResilientArgs(
        inputPath: 'in.mp4',
        outputPath: 'out.mp4',
        start: 0,
        end: 10,
        context: ctx(),
        logCallback: (_) {},
      );

      // A corrupt/oversized header must fail to a recoverable error, not a
      // native abort() that kills the app.
      expect(main.contains('-max_alloc'), isTrue);
      expect(resilient.contains('-max_alloc'), isTrue);
      expect(main.contains('-fflags'), isTrue);
    });

    test('the ceiling grows with the tier but is always finite', () {
      caps.debugSet(totalMemoryBytes: 2 * gb, heapLimitMb: 128);
      final low = caps.maxAllocBytes;
      caps.debugSet(totalMemoryBytes: 12 * gb, heapLimitMb: 512);
      final high = caps.maxAllocBytes;

      expect(low, greaterThan(0));
      expect(high, greaterThan(low));
    });
  });

  group('resolution ceiling cannot be dodged by a disabled layer', () {
    test('a scale is present even when the resampling layer is off', () {
      caps.debugSet(totalMemoryBytes: 2 * gb, heapLimitMb: 128);
      // Custom preset with resampling switched off: previously this let the
      // encoder run at full source resolution and a low-end phone was killed.
      pipeline.applyPreset(PipelinePreset.custom);
      pipeline.resampling.isEnabled = false;

      final args = pipeline.buildFfmpegArgs(
        inputPath: 'in.mp4',
        outputPath: 'out.mp4',
        start: 0,
        end: 10,
        context: ctx(targetWidth: 1280, targetHeight: 720),
        logCallback: (_) {},
      );

      expect(vf(args).contains('scale='), isTrue,
          reason: 'the device ceiling must hold regardless of enabled layers');
      pipeline.applyPreset(PipelinePreset.balanced);
    });
  });

  group('frame-rate ceiling', () {
    test('a fast source is capped as the first video filter', () {
      caps.debugSet(totalMemoryBytes: 2 * gb, heapLimitMb: 128);
      final args = pipeline.buildFfmpegArgs(
        inputPath: 'in.mp4',
        outputPath: 'out.mp4',
        start: 0,
        end: 10,
        context: ctx(targetFps: 30),
        logCallback: (_) {},
      );

      final chain = vf(args);
      final vout = chain.split(';').first; // "[0:v]<filters>[vout]"
      expect(vout.contains('fps=30'), isTrue);
      expect(vout.indexOf('fps=30'), lessThan(vout.indexOf('scale=')),
          reason: 'capping fps first means every later filter runs on fewer frames');
    });

    test('the cap only ever reduces — a slow source is left alone', () {
      caps.debugSet(totalMemoryBytes: 2 * gb, heapLimitMb: 128); // cap 30
      expect(RenderJobService.fpsCapForTest(24.0), 0);
      expect(RenderJobService.fpsCapForTest(30.0), 0);
      expect(RenderJobService.fpsCapForTest(60.0), 30);

      caps.debugSet(totalMemoryBytes: 12 * gb, heapLimitMb: 512); // cap 60
      expect(RenderJobService.fpsCapForTest(30.0), 0);
      expect(RenderJobService.fpsCapForTest(120.0), 60);
    });
  });

  group('encoder working set shrinks on constrained devices', () {
    test('low-end drops b-frames and constrains x264 references', () {
      caps.debugSet(totalMemoryBytes: 2 * gb, heapLimitMb: 128);
      expect(caps.videoBframes, 0);
      expect(caps.x264Params, isNotNull);
      expect(caps.x264Params!.contains('ref=1'), isTrue);
    });

    test('high-end keeps b-frames and imposes no extra x264 constraint', () {
      caps.debugSet(totalMemoryBytes: 12 * gb, heapLimitMb: 512);
      expect(caps.videoBframes, 2);
      expect(caps.x264Params, isNull);
    });
  });
}
