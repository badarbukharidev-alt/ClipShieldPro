import '../models/audio_dsp_config.dart';
import '../services/device_capability_service.dart';

/// Pipeline for Songs Remover module.
/// Builds FFmpeg args for: audio DSP processing + image-to-video composition.
class SongRemoverPipeline {
  /// Builds FFmpeg args for audio-only DSP processing.
  /// Input: audio/video file → Output: processed audio file (.m4a)
  List<String> buildAudioDspArgs({
    required String inputPath,
    required String outputPath,
    required AudioDspConfig config,
    double? audioDuration,
    int sourceSampleRate = 44100,
    int sourceChannels = 2,
    required Function(String) logCallback,
  }) {
    logCallback("--- Compiling Songs Remover Audio DSP Chain ---");

    final List<String> audioFilters = [];

    // Everything downstream assumes a known, stable format.
    final int baseRate = sourceSampleRate > 0 ? sourceSampleRate : 44100;
    audioFilters.add("aformat=sample_rates=$baseRate:channel_layouts=stereo");

    // ---------------------------------------------------------------- stage 1
    // Output mode. This was previously declared on the config and set by the UI,
    // but never read here, so every mode produced byte-identical audio.
    switch (config.outputMode) {
      case AudioOutputMode.fullMix:
        logCallback("Mode: Full Mix (no separation).");
        break;

      case AudioOutputMode.instrumentalOnly:
        if (sourceChannels >= 2) {
          // Centre-channel cancellation. Only removes content panned dead
          // centre, and takes centred bass/drums with it. On a mono source it
          // would cancel to silence, hence the guard.
          //
          // Both channels carry the SAME difference signal rather than an
          // inverted pair. The textbook karaoke filter (c1 = 0.5*c1-0.5*c0)
          // puts the channels perfectly out of phase, which sounds fine in
          // stereo but sums to total silence on any mono playback - phone
          // speakers, mono Bluetooth, many TVs.
          audioFilters.add("pan=stereo|c0=0.5*c0-0.5*c1|c1=0.5*c0-0.5*c1");
          logCallback(
              "Mode: Instrumental (karaoke centre-cancellation). Centre-panned vocals removed.");
        } else {
          logCallback(
              "Mode: Instrumental requested but source is mono - centre cancellation would output silence. Falling back to full mix.");
        }
        break;

      case AudioOutputMode.vocalOnly:
        // Mid extraction plus a vocal-range band. This emphasises centred
        // vocals; it is not true source separation, so centred instruments
        // remain audible.
        if (sourceChannels >= 2) {
          audioFilters.add("pan=stereo|c0=0.5*c0+0.5*c1|c1=0.5*c0+0.5*c1");
        }
        audioFilters.add("highpass=f=120");
        audioFilters.add("lowpass=f=12000");
        logCallback(
            "Mode: Vocal Focus (mid extraction + 120Hz-12kHz band). Approximate, not true isolation.");
        break;
    }

    // ---------------------------------------------------------------- stage 2
    // Loudness normalization runs BEFORE the creative controls. Running it last
    // (as it used to) renormalised the signal to a fixed target and silently
    // cancelled the volume slider: +3dB and -3dB both measured -18.2 dB.
    if (config.normalization) {
      audioFilters.add("loudnorm=I=-16:LRA=11:TP=-1.5");
      logCallback("DSP: Loudness normalization applied as input conditioning.");
    }

    // ---------------------------------------------------------------- stage 3
    // 5-band EQ as an actual tone curve. Previously every band received the same
    // sign, which is a broadband level change rather than equalization - and it
    // was then flattened by loudnorm.
    if (config.eqGainDb.abs() > 0.1) {
      const bands = <int, double>{
        80: 1.0, // low-end weight
        400: -0.8, // clear the boxy low-mids
        2000: 0.6, // presence
        8000: -0.5, // tame harshness
        15000: 0.9, // air
      };
      bands.forEach((freq, weight) {
        final double gain = config.eqGainDb * weight;
        audioFilters.add(
            "equalizer=f=$freq:width_type=q:width=1:g=${gain.toStringAsFixed(2)}");
      });
      logCallback(
          "DSP: 5-band tone curve applied (base ${config.eqGainDb.toStringAsFixed(1)}dB).");
    }

    // ---------------------------------------------------------------- stage 4
    if (config.compressionRatio > 1.1) {
      audioFilters.add(
          "acompressor=ratio=${config.compressionRatio.toStringAsFixed(1)}:threshold=-20dB:attack=5:release=50");
      logCallback(
          "DSP: Compression ratio ${config.compressionRatio.toStringAsFixed(1)}:1");
    }

    // ---------------------------------------------------------------- stage 5
    // Pitch. asetrate is relative to the stream's real sample rate: hardcoding
    // 44100 meant that on a 48kHz source a requested +0.5% actually produced a
    // -1.38 semitone shift and stretched the track by 8.3%. Forcing the rate
    // first makes the maths correct, and the trailing atempo undoes the speed
    // change so pitch no longer alters duration.
    double tempoFactor = 1.0;
    if (config.pitchPercent.abs() > 0.1) {
      final double factor = 1.0 + (config.pitchPercent / 100.0);
      audioFilters.add("aformat=sample_rates=44100");
      audioFilters.add("asetrate=44100*${factor.toStringAsFixed(5)}");
      audioFilters.add("aresample=44100");
      audioFilters.add("atempo=${(1.0 / factor).toStringAsFixed(5)}");
      logCallback(
          "DSP: Pitch ${config.pitchPercent > 0 ? '+' : ''}${config.pitchPercent.toStringAsFixed(1)}% (duration preserved)");
    }

    // Tempo is the only control that is meant to change duration.
    if (config.tempoPercent.abs() > 0.1) {
      final double factor = 1.0 + (config.tempoPercent / 100.0);
      tempoFactor = factor;
      audioFilters.add("atempo=${factor.toStringAsFixed(4)}");
      logCallback(
          "DSP: Tempo ${config.tempoPercent > 0 ? '+' : ''}${config.tempoPercent.toStringAsFixed(1)}%");
    }

    // ---------------------------------------------------------------- stage 6
    if (config.stereoPanning.abs() > 0.01) {
      final double left = (1.0 - config.stereoPanning).clamp(0.0, 2.0);
      final double right = (1.0 + config.stereoPanning).clamp(0.0, 2.0);
      audioFilters.add(
          "pan=stereo|c0=${left.toStringAsFixed(2)}*c0|c1=${right.toStringAsFixed(2)}*c1");
      logCallback(
          "DSP: Stereo panning ${config.stereoPanning.toStringAsFixed(2)}");
    }

    if (config.reverbMix > 0.01) {
      final int delayMs = (20 + (config.reverbMix * 200)).round();
      audioFilters
          .add("aecho=0.8:0.75:$delayMs:${config.reverbMix.toStringAsFixed(3)}");
      logCallback(
          "DSP: Reverb mix ${(config.reverbMix * 100).toStringAsFixed(0)}%");
    }

    if (config.delayMs > 1.0) {
      audioFilters
          .add("adelay=${config.delayMs.toInt()}|${config.delayMs.toInt()}:all=1");
      logCallback("DSP: Delay ${config.delayMs.toInt()}ms");
    }

    // ---------------------------------------------------------------- stage 7
    // Volume is the final trim so the level the user chose always survives.
    if (config.volumeDb.abs() > 0.01) {
      audioFilters.add("volume=${config.volumeDb.toStringAsFixed(1)}dB");
      logCallback(
          "DSP: Volume ${config.volumeDb > 0 ? '+' : ''}${config.volumeDb.toStringAsFixed(1)}dB (final trim)");
    }

    // Fades last, measured against the post-tempo timeline.
    if (config.fadeInSec > 0.1) {
      audioFilters
          .add("afade=t=in:st=0:d=${config.fadeInSec.toStringAsFixed(1)}");
      logCallback("DSP: Fade in ${config.fadeInSec.toStringAsFixed(1)}s");
    }
    if (config.fadeOutSec > 0.1 && audioDuration != null) {
      final double effectiveDuration = audioDuration / tempoFactor;
      if (effectiveDuration > config.fadeOutSec) {
        final double fadeStart = effectiveDuration - config.fadeOutSec;
        audioFilters.add(
            "afade=t=out:st=${fadeStart.toStringAsFixed(2)}:d=${config.fadeOutSec.toStringAsFixed(1)}");
        logCallback(
            "DSP: Fade out ${config.fadeOutSec.toStringAsFixed(1)}s starting at ${fadeStart.toStringAsFixed(1)}s");
      }
    }

    final List<String> args = [
      "-y",
      // A corrupt or oddly-encoded source must not be able to trigger a native
      // abort() that closes the app; cap the allocation and skip bad packets.
      "-max_alloc", "${DeviceCapabilityService.instance.maxAllocBytes}",
      "-fflags", "+discardcorrupt+genpts",
      "-i", inputPath,
    ];

    if (audioFilters.isNotEmpty) {
      args.addAll(["-af", audioFilters.join(',')]);
      logCallback(
          "Audio chain (${audioFilters.length} filters): ${audioFilters.join(',')}");
    }

    args.addAll([
      "-vn", // no video
      "-c:a", "aac",
      "-b:a", "192k",
      outputPath,
    ]);

    return args;
  }

  /// Builds FFmpeg args to compose a static cover image + processed audio → video.
  /// Aspect: 16:9 (1920x1080) or 9:16 (1080x1920)
  List<String> buildImageVideoArgs({
    required String imagePath,
    required String audioPath,
    required String outputPath,
    required bool isWidescreen, // true = 16:9, false = 9:16
    required Function(String) logCallback,
  }) {
    final int ceiling = DeviceCapabilityService.instance.maxOutputHeight; // 720 on low-tier, 1080 on mid/high
    final int w;
    final int h;

    if (isWidescreen) {
      // 16:9 widescreen: height is the short edge
      final int targetH = ceiling.clamp(360, 1080);
      int targetW = (targetH * 16 / 9).round();
      if (targetW.isOdd) targetW -= 1;
      w = targetW;
      h = targetH.isOdd ? targetH - 1 : targetH;
    } else {
      // 9:16 vertical: width is the short edge, capped by ceiling
      final int targetW = ceiling.clamp(360, 1080);
      int targetH = (targetW * 16 / 9).round();
      if (targetH.isOdd) targetH -= 1;
      w = targetW.isOdd ? targetW - 1 : targetW;
      h = targetH;
    }

    logCallback("Composing cover image (${w}x$h, ceiling: ${ceiling}p) + audio → video...");

    return [
      "-y",
      // Bound any single allocation so an oversized cover image fails to a
      // recoverable error rather than a native abort() that closes the app.
      "-max_alloc", "${DeviceCapabilityService.instance.maxAllocBytes}",
      "-threads", "${DeviceCapabilityService.instance.encoderThreads}",
      "-framerate", "1",
      "-loop", "1",
      "-i", imagePath,
      "-fflags", "+discardcorrupt+genpts",
      "-i", audioPath,
      "-vf", "scale=$w:$h:force_original_aspect_ratio=decrease,pad=$w:$h:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1",
      "-c:v", "libx264",
      "-tune", "stillimage",
      "-preset", "ultrafast",
      "-threads", "${DeviceCapabilityService.instance.encoderThreads}",
      "-max_muxing_queue_size", "2048",
      "-r", "1",
      "-c:a", "copy",
      "-shortest",
      "-pix_fmt", "yuv420p",
      outputPath,
    ];
  }

  /// Builds FFmpeg args for a 10-second audio preview.
  List<String> buildPreviewArgs({
    required String inputPath,
    required String outputPath,
    required AudioDspConfig config,
    int sourceSampleRate = 44100,
    int sourceChannels = 2,
    required Function(String) logCallback,
  }) {
    final fullArgs = buildAudioDspArgs(
      inputPath: inputPath,
      outputPath: outputPath,
      config: config,
      // The preview is a 10s window, so fade-out has no meaningful anchor.
      audioDuration: null,
      sourceSampleRate: sourceSampleRate,
      sourceChannels: sourceChannels,
      logCallback: logCallback,
    );

    // Insert duration limit after input
    final int inputIdx = fullArgs.indexOf("-i");
    if (inputIdx >= 0) {
      fullArgs.insert(inputIdx, "-t");
      fullArgs.insert(inputIdx + 1, "10");
    }

    return fullArgs;
  }
}
