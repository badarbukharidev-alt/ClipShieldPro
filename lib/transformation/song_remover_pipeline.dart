import '../models/audio_dsp_config.dart';

/// Pipeline for Songs Remover module.
/// Builds FFmpeg args for: audio DSP processing + image-to-video composition.
class SongRemoverPipeline {
  /// Builds FFmpeg args for audio-only DSP processing.
  /// Input: audio/video file → Output: processed audio file (.m4a)
  List<String> buildAudioDspArgs({
    required String inputPath,
    required String outputPath,
    required AudioDspConfig config,
    required Function(String) logCallback,
  }) {
    logCallback("--- Compiling Songs Remover Audio DSP Chain ---");

    List<String> audioFilters = [];

    // 1. Volume adjustment
    if (config.volumeDb != 0.0) {
      audioFilters.add("volume=${config.volumeDb.toStringAsFixed(1)}dB");
      logCallback("DSP: Volume ${config.volumeDb > 0 ? '+' : ''}${config.volumeDb.toStringAsFixed(1)}dB");
    }

    // 2. 5-Band EQ
    if (config.eqGainDb.abs() > 0.1) {
      final bands = [80, 400, 2000, 8000, 15000];
      for (final freq in bands) {
        final double gain = config.eqGainDb * (freq < 2000 ? 0.8 : 1.0);
        audioFilters.add("equalizer=f=$freq:width_type=q:width=1:g=${gain.toStringAsFixed(2)}");
      }
      logCallback("DSP: 5-Band EQ applied (±${config.eqGainDb.toStringAsFixed(1)}dB)");
    }

    // 3. Tempo change
    if (config.tempoPercent.abs() > 0.1) {
      final double factor = 1.0 + (config.tempoPercent / 100.0);
      audioFilters.add("atempo=${factor.toStringAsFixed(4)}");
      logCallback("DSP: Tempo ${config.tempoPercent > 0 ? '+' : ''}${config.tempoPercent.toStringAsFixed(1)}%");
    }

    // 4. Pitch shift (using asetrate + aresample)
    if (config.pitchPercent.abs() > 0.1) {
      final double factor = 1.0 + (config.pitchPercent / 100.0);
      audioFilters.add("asetrate=44100*${factor.toStringAsFixed(4)}");
      audioFilters.add("aresample=44100");
      logCallback("DSP: Pitch ${config.pitchPercent > 0 ? '+' : ''}${config.pitchPercent.toStringAsFixed(1)}%");
    }

    // 5. Stereo panning
    if (config.stereoPanning.abs() > 0.01) {
      final double left = (1.0 - config.stereoPanning).clamp(0.0, 2.0);
      final double right = (1.0 + config.stereoPanning).clamp(0.0, 2.0);
      audioFilters.add("pan=stereo|c0=${left.toStringAsFixed(2)}*c0|c1=${right.toStringAsFixed(2)}*c1");
      logCallback("DSP: Stereo panning ${config.stereoPanning.toStringAsFixed(2)}");
    }

    // 6. Compression (using acompressor)
    if (config.compressionRatio > 1.1) {
      audioFilters.add("acompressor=ratio=${config.compressionRatio.toStringAsFixed(1)}:threshold=-20dB:attack=5:release=50");
      logCallback("DSP: Compression ratio ${config.compressionRatio.toStringAsFixed(1)}:1");
    }

    // 7. Reverb (using aecho)
    if (config.reverbMix > 0.01) {
      final int delayMs = (20 + (config.reverbMix * 200)).round();
      audioFilters.add("aecho=0.8:0.75:$delayMs:${config.reverbMix.toStringAsFixed(3)}");
      logCallback("DSP: Reverb mix ${(config.reverbMix * 100).toStringAsFixed(0)}%");
    }

    // 8. Delay/echo
    if (config.delayMs > 1.0) {
      audioFilters.add("adelay=${config.delayMs.toInt()}|${config.delayMs.toInt()}");
      logCallback("DSP: Delay ${config.delayMs.toInt()}ms");
    }

    // 9. Fade in/out
    if (config.fadeInSec > 0.1) {
      audioFilters.add("afade=t=in:st=0:d=${config.fadeInSec.toStringAsFixed(1)}");
      logCallback("DSP: Fade in ${config.fadeInSec.toStringAsFixed(1)}s");
    }
    if (config.fadeOutSec > 0.1) {
      // Fade out needs duration info - use a large value, FFmpeg handles it
      audioFilters.add("areverse,afade=t=in:d=${config.fadeOutSec.toStringAsFixed(1)},areverse");
      logCallback("DSP: Fade out ${config.fadeOutSec.toStringAsFixed(1)}s");
    }

    // 10. Normalization
    if (config.normalization) {
      audioFilters.add("loudnorm=I=-16:LRA=11:TP=-1.5");
      logCallback("DSP: Loudness normalization (ITU-R BS.1770)");
    }

    // Build final args
    List<String> args = ["-y", "-i", inputPath];

    if (audioFilters.isNotEmpty) {
      args.addAll(["-af", audioFilters.join(',')]);
    }

    args.addAll([
      "-vn",  // no video
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
    final int w = isWidescreen ? 1920 : 1080;
    final int h = isWidescreen ? 1080 : 1920;

    logCallback("Composing cover image (${w}x$h) + audio → video...");

    return [
      "-y",
      "-loop", "1",
      "-i", imagePath,
      "-i", audioPath,
      "-vf", "scale=$w:$h:force_original_aspect_ratio=decrease,pad=$w:$h:(ow-iw)/2:(oh-ih)/2:color=black",
      "-c:v", "libx264",
      "-tune", "stillimage",
      "-preset", "ultrafast",
      "-c:a", "aac",
      "-b:a", "192k",
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
    required Function(String) logCallback,
  }) {
    final fullArgs = buildAudioDspArgs(
      inputPath: inputPath,
      outputPath: outputPath,
      config: config,
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
