import '../layer.dart';

class ReverbLayer extends TransformationLayer {
  double? customDelayMs;
  double? customDecay;

  ReverbLayer({super.isEnabled = true, super.intensity = 0.5, this.customDelayMs, this.customDecay});

  @override int get layerNumber => 12;
  @override String get name => "Micro-Reverb Audio Defense";
  @override String get subtitle => "Imperceptible reverb tail for waveform disruption";
  @override String get description => "Adds a very subtle reverb/echo (10-25ms delay, 2-5% decay) to disrupt audio waveform fingerprinting.";

  @override
  bool validate(FilterContext context) {
    if (!context.hasAudio) return false;
    final delay = customDelayMs ?? 15.0;
    final decay = customDecay ?? 0.03;
    return delay >= 5.0 && delay <= 100.0 && decay >= 0.01 && decay <= 0.2;
  }

  @override
  FilterResult apply(FilterContext context) {
    if (!context.hasAudio) {
      return FilterResult(logMessage: "Layer 12: No audio stream. Skipped.");
    }
    final double delay = customDelayMs ?? (10.0 + (intensity * 15.0)); // 10-25ms
    final double decay = customDecay ?? (0.02 + (intensity * 0.03)); // 0.02-0.05

    // aecho=in_gain:out_gain:delays:decays
    return FilterResult(
      audioFilters: ["aecho=0.8:0.75:${delay.toStringAsFixed(0)}:${decay.toStringAsFixed(3)}"],
      logMessage: "Layer 12 applied: Micro-reverb delay=${delay.toStringAsFixed(0)}ms, decay=${decay.toStringAsFixed(3)}.",
    );
  }

  @override
  FilterResult fallback(FilterContext context) {
    return FilterResult(
      audioFilters: ["aecho=0.8:0.8:15:0.02"],
      logMessage: "Layer 12 fallback: Minimal reverb applied.",
      isFallback: true,
    );
  }
}
