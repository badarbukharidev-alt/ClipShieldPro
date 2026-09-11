/// Audio DSP configuration model for Songs Remover module.
/// All parameters have defaults matching the recommended subtle processing ranges.
class AudioDspConfig {
  double volumeDb;        // ±0.5–1.5 dB
  double eqGainDb;        // ±1–2 dB  
  double tempoPercent;    // ±1–2%
  double pitchPercent;    // ±0.5–1%
  double stereoPanning;   // 0.0 = center, -1.0 = left, 1.0 = right
  double compressionRatio; // 1.5–2:1
  double reverbMix;       // 0.0–0.15 (very low)
  double delayMs;         // 0–50ms
  double fadeInSec;       // 1–3 sec
  double fadeOutSec;      // 1–3 sec
  bool normalization;     // gentle loudness normalization
  AudioOutputMode outputMode;

  AudioDspConfig({
    this.volumeDb = 1.0,
    this.eqGainDb = 1.5,
    this.tempoPercent = 1.0,
    this.pitchPercent = 0.5,
    this.stereoPanning = 0.0,
    this.compressionRatio = 1.8,
    this.reverbMix = 0.05,
    this.delayMs = 10.0,
    this.fadeInSec = 1.5,
    this.fadeOutSec = 2.0,
    this.normalization = true,
    this.outputMode = AudioOutputMode.fullMix,
  });

  AudioDspConfig copyWith({
    double? volumeDb,
    double? eqGainDb,
    double? tempoPercent,
    double? pitchPercent,
    double? stereoPanning,
    double? compressionRatio,
    double? reverbMix,
    double? delayMs,
    double? fadeInSec,
    double? fadeOutSec,
    bool? normalization,
    AudioOutputMode? outputMode,
  }) {
    return AudioDspConfig(
      volumeDb: volumeDb ?? this.volumeDb,
      eqGainDb: eqGainDb ?? this.eqGainDb,
      tempoPercent: tempoPercent ?? this.tempoPercent,
      pitchPercent: pitchPercent ?? this.pitchPercent,
      stereoPanning: stereoPanning ?? this.stereoPanning,
      compressionRatio: compressionRatio ?? this.compressionRatio,
      reverbMix: reverbMix ?? this.reverbMix,
      delayMs: delayMs ?? this.delayMs,
      fadeInSec: fadeInSec ?? this.fadeInSec,
      fadeOutSec: fadeOutSec ?? this.fadeOutSec,
      normalization: normalization ?? this.normalization,
      outputMode: outputMode ?? this.outputMode,
    );
  }
}

enum AudioOutputMode {
  fullMix,
  vocalOnly,
  instrumentalOnly,
}

extension AudioOutputModeExt on AudioOutputMode {
  String get label {
    switch (this) {
      case AudioOutputMode.fullMix:
        return 'Full Mix';
      case AudioOutputMode.vocalOnly:
        return 'Vocal Only';
      case AudioOutputMode.instrumentalOnly:
        return 'Instrumental Only';
    }
  }

  String get description {
    switch (this) {
      case AudioOutputMode.fullMix:
        return 'Process entire audio with all DSP effects';
      case AudioOutputMode.vocalOnly:
        return 'Isolate and process vocals only';
      case AudioOutputMode.instrumentalOnly:
        return 'Remove vocals, keep instrumental';
    }
  }
}
