import 'package:flutter_test/flutter_test.dart';

import 'package:clipshield/services/device_capability_service.dart';
import 'package:clipshield/services/render_job_service.dart';
import 'package:clipshield/services/media_probe_service.dart';

/// Low-end phones were killing the app mid-render — "isn't responding", or the
/// process simply vanishing. Not one bug: a pipeline tuned for a good phone,
/// running on a cheap one. These pin the three levers that matter, and pin that
/// a good phone is not punished for it.
const int gb = 1024 * 1024 * 1024;

MediaProbeInfo probe(int w, int h) => MediaProbeInfo(
      width: w,
      height: h,
      duration: 600,
      hasAudio: true,
    );

void main() {
  final caps = DeviceCapabilityService.instance;

  tearDown(caps.debugReset);

  group('tiering', () {
    test('a 2 GB phone is low', () {
      caps.debugSet(totalMemoryBytes: 2 * gb, heapLimitMb: 128);
      expect(caps.tier, DeviceTier.low);
      expect(caps.isLowEnd, isTrue);
    });

    test('a 4 GB phone is mid', () {
      caps.debugSet(totalMemoryBytes: 4 * gb, heapLimitMb: 256);
      expect(caps.tier, DeviceTier.mid);
    });

    test('an 8 GB phone is high', () {
      caps.debugSet(totalMemoryBytes: 8 * gb, heapLimitMb: 512);
      expect(caps.tier, DeviceTier.high);
    });

    test("the manufacturer's low-RAM flag outranks the spec sheet", () {
      // A phone can ship 4 GB and still be flagged low-RAM, and its process
      // killer is stricter regardless of the total.
      caps.debugSet(totalMemoryBytes: 4 * gb, heapLimitMb: 256, isLowRamDevice: true);
      expect(caps.tier, DeviceTier.low);
    });

    test('a 32-bit process is constrained whatever the RAM', () {
      caps.debugSet(totalMemoryBytes: 8 * gb, heapLimitMb: 512, is64Bit: false);
      expect(caps.tier, DeviceTier.low,
          reason: 'a 32-bit process cannot address much regardless of RAM');
    });

    test('a small heap ceiling outranks a large total', () {
      // The heap is what an allocation is measured against, not total RAM.
      caps.debugSet(totalMemoryBytes: 6 * gb, heapLimitMb: 96);
      expect(caps.tier, DeviceTier.low);
    });

    test('an unknown device is treated as mid, not as high', () {
      caps.debugReset();
      expect(caps.tier, DeviceTier.mid,
          reason: 'guessing optimistically about an unknown device is how it '
              'gets killed');
    });
  });

  group('encoder threads — the biggest lever', () {
    test('a low-end phone gets a single thread', () {
      caps.debugSet(totalMemoryBytes: 2 * gb, heapLimitMb: 128, processors: 8);

      // x264 keeps per-thread frame buffers, so "one per core" on a cheap
      // eight-core phone allocated eight sets of them.
      expect(caps.encoderThreads, 1);
    });

    test('a mid phone gets a few, not all', () {
      caps.debugSet(totalMemoryBytes: 4 * gb, heapLimitMb: 256, processors: 8);
      expect(caps.encoderThreads, 3);

      caps.debugSet(totalMemoryBytes: 4 * gb, heapLimitMb: 256, processors: 4);
      expect(caps.encoderThreads, 2);
    });

    test('a high-end phone is left alone', () {
      caps.debugSet(totalMemoryBytes: 12 * gb, heapLimitMb: 512);
      expect(caps.encoderThreads, 0, reason: '0 lets FFmpeg choose');
    });
  });

  group('output resolution', () {
    test('a low-end phone is capped at 720p even on high quality', () {
      caps.debugSet(totalMemoryBytes: 2 * gb, heapLimitMb: 128);

      final (w, h) = RenderJobService.widescreenOutputSize(
        probe(1920, 1080),
        'high',
        deviceCeiling: caps.maxOutputHeight,
      );

      expect(h, lessThanOrEqualTo(720));
      expect(w, lessThanOrEqualTo(1280));
    });

    test('a high-end phone still gets 1080p', () {
      caps.debugSet(totalMemoryBytes: 12 * gb, heapLimitMb: 512);

      final (w, h) = RenderJobService.widescreenOutputSize(
        probe(1920, 1080),
        'high',
        deviceCeiling: caps.maxOutputHeight,
      );

      expect(h, 1080);
      expect(w, 1920);
    });

    test('the cap cannot be dodged with an ultra-wide source', () {
      caps.debugSet(totalMemoryBytes: 2 * gb, heapLimitMb: 128);

      final (w, h) = RenderJobService.widescreenOutputSize(
        probe(3840, 1080), // 32:9
        'high',
        deviceCeiling: caps.maxOutputHeight,
      );

      expect(w * h, lessThan(1280 * 720 * 1.1),
          reason: 'a very wide source must not smuggle the pixel count back up');
    });

    test('aspect ratio is still preserved exactly', () {
      caps.debugSet(totalMemoryBytes: 2 * gb, heapLimitMb: 128);

      final (w, h) = RenderJobService.widescreenOutputSize(
        probe(1440, 1080), // 4:3
        'high',
        deviceCeiling: caps.maxOutputHeight,
      );

      expect((w / h), closeTo(4 / 3, 0.02),
          reason: 'capping resolution must never stretch the picture');
    });

    test('a source smaller than the cap is never upscaled', () {
      caps.debugSet(totalMemoryBytes: 12 * gb, heapLimitMb: 512);

      final (w, h) = RenderJobService.widescreenOutputSize(
        probe(640, 360),
        'high',
        deviceCeiling: caps.maxOutputHeight,
      );

      expect(w, 640);
      expect(h, 360);
    });

    test('dimensions stay even, which H.264 requires', () {
      for (final tierMemory in [2 * gb, 4 * gb, 12 * gb]) {
        caps.debugSet(totalMemoryBytes: tierMemory, heapLimitMb: 256);
        final (w, h) = RenderJobService.widescreenOutputSize(
          probe(1919, 1079),
          'high',
          deviceCeiling: caps.maxOutputHeight,
        );
        expect(w.isEven, isTrue);
        expect(h.isEven, isTrue);
      }
    });
  });

  group('subject tracking', () {
    test('is skipped on a low-end phone', () {
      caps.debugSet(totalMemoryBytes: 2 * gb, heapLimitMb: 128);

      // The ML Kit model sits in memory for the whole pass, on top of the
      // encoder. That is the allocation that tips a cheap phone over.
      expect(caps.canRunSubjectTracking, isFalse);
    });

    test('still runs everywhere else', () {
      caps.debugSet(totalMemoryBytes: 4 * gb, heapLimitMb: 256);
      expect(caps.canRunSubjectTracking, isTrue);

      caps.debugSet(totalMemoryBytes: 12 * gb, heapLimitMb: 512);
      expect(caps.canRunSubjectTracking, isTrue);
    });
  });

  group('image cache', () {
    test('a low-end phone holds far less', () {
      caps.debugSet(totalMemoryBytes: 2 * gb, heapLimitMb: 128);
      expect(caps.imageCacheBytes, lessThanOrEqualTo(24 * 1024 * 1024));
    });

    test('a high-end phone keeps the full default', () {
      caps.debugSet(totalMemoryBytes: 12 * gb, heapLimitMb: 512);
      expect(caps.imageCacheBytes, 100 * 1024 * 1024);
    });
  });
}
