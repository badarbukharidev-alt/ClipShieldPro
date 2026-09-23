import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// How much this phone can be asked to do at once.
enum DeviceTier {
  /// Under ~3 GB, or flagged low-RAM by the manufacturer. Rendering has to be
  /// deliberately modest here or Android kills the process mid-job.
  low,

  /// 3-6 GB. The common case.
  mid,

  /// Over 6 GB. Can take the full pipeline.
  high,
}

/// Sizes the render pipeline to the device instead of to the machine it was
/// developed on.
///
/// The crash people saw -- "ClipShield isn't responding", or the app vanishing
/// when they tapped Render -- was not one bug. It was a pipeline configured for
/// a good phone running on a cheap one:
///
/// * `-threads 0` told x264 to use **every core**. Each thread keeps its own
///   frame buffers, so an 8-core budget phone allocated eight sets of them out
///   of a heap a fraction the size of a flagship's.
/// * Output was 1080p regardless of the device, which is four times the pixel
///   budget of 720p through every filter in the chain.
/// * Face detection loaded an ML Kit model alongside all of that.
///
/// None of those is wrong on a 12 GB phone. All three together on a 2 GB phone
/// exceed the heap before the first frame is written.
class DeviceCapabilityService {
  DeviceCapabilityService._();
  static final DeviceCapabilityService instance = DeviceCapabilityService._();

  static const MethodChannel _channel = MethodChannel('com.clipshield/device');

  static const int _gb = 1024 * 1024 * 1024;

  bool _loaded = false;
  int _totalMemoryBytes = 0;
  int _heapLimitMb = 0;
  int _processors = 4;
  bool _isLowRamDevice = false;
  bool _is64Bit = true;
  String _model = '';

  int get totalMemoryBytes => _totalMemoryBytes;
  int get heapLimitMb => _heapLimitMb;
  int get processors => _processors;
  String get model => _model;

  double get totalMemoryGb => _totalMemoryBytes / _gb;

  /// Reads the device's real numbers. Safe to call more than once; safe to skip
  /// entirely, since every getter has a sane default.
  Future<void> load() async {
    if (!Platform.isAndroid) {
      _loaded = true;
      return;
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getCapabilities');
      if (result != null) {
        _totalMemoryBytes = (result['totalMemoryBytes'] as num?)?.toInt() ?? 0;
        _heapLimitMb = (result['largeHeapLimitMb'] as num?)?.toInt() ??
            (result['heapLimitMb'] as num?)?.toInt() ??
            0;
        _processors = (result['processors'] as num?)?.toInt() ?? 4;
        _isLowRamDevice = result['isLowRamDevice'] == true;
        _is64Bit = result['is64Bit'] != false;
        _model = result['model'] as String? ?? '';
      }
    } catch (_) {
      // Unknown device: the tier getter treats that as `mid`, which is the safe
      // middle rather than an optimistic guess.
    }

    _loaded = true;
  }

  DeviceTier get tier {
    if (!_loaded || _totalMemoryBytes <= 0) return DeviceTier.mid;

    // The manufacturer's own flag outranks the spec sheet: a device marked
    // low-RAM has a stricter process killer whatever its total.
    if (_isLowRamDevice) return DeviceTier.low;

    // A 32-bit process cannot address much regardless of fitted RAM, so it is
    // treated as constrained even on a 4 GB phone.
    if (!_is64Bit) return DeviceTier.low;

    // The heap ceiling matters more than total RAM: it is what an allocation is
    // actually measured against, and it is a fraction of the total.
    if (_heapLimitMb > 0 && _heapLimitMb < 192) return DeviceTier.low;

    final gb = totalMemoryGb;
    if (gb < 3.2) return DeviceTier.low;
    if (gb < 6.2) return DeviceTier.mid;

    return DeviceTier.high;
  }

  bool get isLowEnd => tier == DeviceTier.low;

  /// Value for FFmpeg's `-threads`.
  ///
  /// This is the single biggest lever. x264 allocates per-thread frame buffers,
  /// so thread count multiplies memory use almost linearly. "0" means one per
  /// core, which is exactly the wrong default on a cheap eight-core phone.
  int get encoderThreads {
    switch (tier) {
      case DeviceTier.low:
        return 1;
      case DeviceTier.mid:
        return _processors >= 8 ? 3 : 2;
      case DeviceTier.high:
        return 0; // let FFmpeg decide
    }
  }

  /// Ceiling on output height, whatever quality was asked for.
  ///
  /// 1080p is four times the pixel budget of 720p through every filter in the
  /// chain. A low-end device that cannot finish a 1080p render is better served
  /// by a 720p file that exists.
  int get maxOutputHeight {
    switch (tier) {
      case DeviceTier.low:
        return 720;
      case DeviceTier.mid:
        return 1080;
      case DeviceTier.high:
        return 1080;
    }
  }

  /// Ceiling on output frame rate, whatever the source runs at.
  ///
  /// The second-biggest lever after threads. A 60 or 120 fps source multiplies
  /// the frame count — and therefore encode time, decode buffers and peak
  /// memory — for no visible benefit on a short social clip. Capping fps early
  /// (as the first filter) means every downstream filter processes fewer frames.
  int get maxFrameRate {
    switch (tier) {
      case DeviceTier.low:
        return 30;
      case DeviceTier.mid:
        return 30;
      case DeviceTier.high:
        return 60;
    }
  }

  /// B-frame count for the software encoder.
  ///
  /// B-frames make x264 hold future frames in memory. On a low-end heap that is
  /// a cost with no upside, so it drops to zero there and stays at 2 elsewhere.
  int get videoBframes => tier == DeviceTier.low ? 0 : 2;

  // NOTE: there is deliberately no `-x264-params` override. The pipeline encodes
  // with `-preset ultrafast`, which already uses the smallest fast working set
  // (ref=1, no rc-lookahead, no sync-lookahead). An earlier attempt to "shrink"
  // it further actually RE-ENABLED rc-lookahead and raised ref on mid devices,
  // which made every render markedly slower for no memory win. Thread count, the
  // resolution ceiling and the fps cap are the levers that matter; ultrafast is
  // left to its own encoder defaults.

  // NOTE: an earlier `-max_alloc` cap and `-fflags +discardcorrupt` were removed.
  // They were meant to turn a rare native abort into a recoverable error, but
  // `discardcorrupt` dropped genuinely-good video packets on some sources, which
  // produced a file with working audio and a BLACK video track. The memory that
  // matters is bounded by thread count, the resolution ceiling and the fps cap;
  // the encode is left to standard demuxing so every frame is kept.

  /// Whether face-tracking reframing can be afforded.
  ///
  /// ML Kit holds a detection model in memory for the whole pass, on top of the
  /// encoder. On a low-end device that is the allocation that tips it over.
  bool get canRunSubjectTracking => tier != DeviceTier.low;

  /// Bytes Flutter may hold in its decoded-image cache.
  ///
  /// The default is 100 MB, which on a 2 GB phone is a large share of the heap
  /// spent on thumbnails while FFmpeg is trying to encode.
  int get imageCacheBytes {
    switch (tier) {
      case DeviceTier.low:
        return 24 * 1024 * 1024;
      case DeviceTier.mid:
        return 60 * 1024 * 1024;
      case DeviceTier.high:
        return 100 * 1024 * 1024;
    }
  }

  /// Applies the cache ceiling. Called once at startup.
  void applyImageCacheLimit() {
    try {
      PaintingBinding.instance.imageCache.maximumSizeBytes = imageCacheBytes;
      // A count cap as well: many small images can be as damaging as a few large
      // ones, and the byte cap alone does not bound the entry count.
      PaintingBinding.instance.imageCache.maximumSize = isLowEnd ? 60 : 200;
    } catch (_) {}
  }

  /// One line for the diagnostics screen and for bug reports.
  String get summary {
    if (!_loaded || _totalMemoryBytes <= 0) return 'Device profile unavailable';

    final gb = totalMemoryGb.toStringAsFixed(1);

    return '$_model - $gb GB RAM, ${_heapLimitMb}MB heap, '
        '$_processors cores, ${tier.name} tier';
  }

  @visibleForTesting
  void debugSet({
    int totalMemoryBytes = 8 * _gb,
    int heapLimitMb = 512,
    int processors = 8,
    bool isLowRamDevice = false,
    bool is64Bit = true,
    String model = 'Test Device',
  }) {
    _loaded = true;
    _totalMemoryBytes = totalMemoryBytes;
    _heapLimitMb = heapLimitMb;
    _processors = processors;
    _isLowRamDevice = isLowRamDevice;
    _is64Bit = is64Bit;
    _model = model;
  }

  @visibleForTesting
  void debugReset() {
    _loaded = false;
    _totalMemoryBytes = 0;
    _heapLimitMb = 0;
    _processors = 4;
    _isLowRamDevice = false;
    _is64Bit = true;
    _model = '';
  }
}
