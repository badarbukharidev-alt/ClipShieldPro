import 'package:flutter_test/flutter_test.dart';
import 'package:clipshield/models/audio_dsp_config.dart';
import 'package:clipshield/transformation/song_remover_pipeline.dart';

/// Returns the value of the `-af` argument, i.e. the compiled filter chain.
String chainOf(
  AudioDspConfig config, {
  int sampleRate = 48000,
  int channels = 2,
  double? duration,
}) {
  final args = SongRemoverPipeline().buildAudioDspArgs(
    inputPath: 'in.mp3',
    outputPath: 'out.m4a',
    config: config,
    audioDuration: duration,
    sourceSampleRate: sampleRate,
    sourceChannels: channels,
    logCallback: (_) {},
  );
  final i = args.indexOf('-af');
  return i >= 0 ? args[i + 1] : '';
}

AudioDspConfig flat({AudioOutputMode mode = AudioOutputMode.fullMix}) {
  // Every creative control neutral, so a test only sees what it is testing.
  return AudioDspConfig(
    volumeDb: 0.0,
    eqGainDb: 0.0,
    tempoPercent: 0.0,
    pitchPercent: 0.0,
    stereoPanning: 0.0,
    compressionRatio: 1.0,
    reverbMix: 0.0,
    delayMs: 0.0,
    fadeInSec: 0.0,
    fadeOutSec: 0.0,
    normalization: false,
    outputMode: mode,
  );
}

void main() {
  group('output mode is actually applied', () {
    test('the three modes produce three different chains', () {
      final full = chainOf(flat(mode: AudioOutputMode.fullMix));
      final vocal = chainOf(flat(mode: AudioOutputMode.vocalOnly));
      final inst = chainOf(flat(mode: AudioOutputMode.instrumentalOnly));

      expect(full, isNot(equals(vocal)));
      expect(full, isNot(equals(inst)));
      expect(vocal, isNot(equals(inst)),
          reason: 'selecting a mode must change the audio that is produced');
    });

    test('full mix applies no separation', () {
      expect(chainOf(flat(mode: AudioOutputMode.fullMix)), isNot(contains('pan=')));
    });

    test('instrumental cancels the centre channel', () {
      final chain = chainOf(flat(mode: AudioOutputMode.instrumentalOnly));
      expect(chain, contains('pan=stereo|c0=0.5*c0-0.5*c1'));
    });

    test('instrumental output stays mono-compatible', () {
      // Both channels must carry the same difference signal. An inverted pair
      // (c1=0.5*c1-0.5*c0) sums to silence on mono playback.
      final chain = chainOf(flat(mode: AudioOutputMode.instrumentalOnly));
      expect(chain, contains('c1=0.5*c0-0.5*c1'));
      expect(chain, isNot(contains('c1=0.5*c1-0.5*c0')));
    });

    test('instrumental falls back on a mono source instead of emitting silence', () {
      final chain =
          chainOf(flat(mode: AudioOutputMode.instrumentalOnly), channels: 1);
      expect(chain, isNot(contains('-0.5*c1')),
          reason: 'centre cancellation on mono would cancel to silence');
    });

    test('vocal focus extracts mid and band-limits', () {
      final chain = chainOf(flat(mode: AudioOutputMode.vocalOnly));
      expect(chain, contains('pan=stereo|c0=0.5*c0+0.5*c1'));
      expect(chain, contains('highpass=f=120'));
      expect(chain, contains('lowpass=f=12000'));
    });
  });

  group('loudness normalization does not cancel the user controls', () {
    test('loudnorm is applied before volume, not after', () {
      final config = flat()
        ..normalization = true
        ..volumeDb = 3.0;
      final chain = chainOf(config);

      expect(chain, contains('loudnorm'));
      expect(chain, contains('volume=3.0dB'));
      expect(chain.indexOf('loudnorm'), lessThan(chain.indexOf('volume=')),
          reason: 'loudnorm after volume renormalises the slider away entirely');
    });

    test('volume is the last gain stage in the chain', () {
      final config = flat()
        ..normalization = true
        ..eqGainDb = 2.0
        ..compressionRatio = 2.0
        ..volumeDb = -2.5;
      final chain = chainOf(config);

      expect(chain.indexOf('volume='), greaterThan(chain.indexOf('equalizer')));
      expect(chain.indexOf('volume='), greaterThan(chain.indexOf('acompressor')));
    });
  });

  group('pitch', () {
    test('forces the base sample rate before asetrate', () {
      final chain = chainOf(flat()..pitchPercent = 0.5, sampleRate: 48000);
      final formatIdx = chain.indexOf('aformat=sample_rates=44100');
      final setrateIdx = chain.indexOf('asetrate=');

      expect(formatIdx, greaterThanOrEqualTo(0),
          reason: 'asetrate is relative to the real rate; 48kHz sources break '
              'without this');
      expect(formatIdx, lessThan(setrateIdx));
    });

    test('compensates tempo so pitch does not change duration', () {
      final chain = chainOf(flat()..pitchPercent = 0.5);
      expect(chain, contains('asetrate=44100*1.00500'));
      expect(chain, contains('atempo=0.99502'));
    });

    test('tempo is the only control that changes duration', () {
      final chain = chainOf(flat()..tempoPercent = 2.0);
      expect(chain, contains('atempo=1.0200'));
      expect(chain, isNot(contains('asetrate')));
    });
  });

  group('EQ is a tone curve, not a volume knob', () {
    test('bands do not all share one sign', () {
      final chain = chainOf(flat()..eqGainDb = 2.0);
      final gains = RegExp(r'equalizer=f=\d+:width_type=q:width=1:g=(-?[\d.]+)')
          .allMatches(chain)
          .map((m) => double.parse(m.group(1)!))
          .toList();

      expect(gains.length, 5);
      expect(gains.any((g) => g > 0), isTrue);
      expect(gains.any((g) => g < 0), isTrue,
          reason: 'uniform-sign gains across all bands is a broadband level '
              'change, not equalization');
    });
  });

  group('fade out', () {
    test('is anchored to the post-tempo duration', () {
      final config = flat()
        ..fadeOutSec = 2.0
        ..tempoPercent = 100.0; // double speed => 60s becomes 30s
      final chain = chainOf(config, duration: 60.0);
      expect(chain, contains('afade=t=out:st=28.00'));
    });

    test('is skipped when the duration is unknown', () {
      final chain = chainOf(flat()..fadeOutSec = 2.0, duration: null);
      expect(chain, isNot(contains('afade=t=out')));
    });
  });

  group('stored config', () {
    test('an out-of-range output mode index does not throw', () {
      final config = AudioDspConfig.fromMap({'outputMode': 99});
      expect(config.outputMode, AudioOutputMode.fullMix);
    });

    test('output mode survives a round trip', () {
      final original = flat(mode: AudioOutputMode.instrumentalOnly);
      final restored = AudioDspConfig.fromMap(original.toMap());
      expect(restored.outputMode, AudioOutputMode.instrumentalOnly);
    });
  });
}
