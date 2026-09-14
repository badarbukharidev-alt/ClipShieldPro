import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import '../models/clip_model.dart';
import '../utils/duration_format.dart';
import 'project_storage_service.dart';

class HighlightDetectorService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
  ));

  /// Analyzes media transcript to find viral moments.
  /// Routes inference request according to selected provider in settings/storage:
  /// - 'gemini': Google Gemini 1.5 Flash
  /// - 'openrouter': OpenRouter (Gemini 2.0 Flash Lite / LLaMA 3.3 70B)
  /// - 'groq': Groq (LLaMA-3.3-70B-versatile)
  /// - 'cerebras': Cerebras (LLaMA-3.1-70B)
  /// - 'heuristic': Uniform Segment Fallback (offline mathematical heuristic)
  Future<List<ClipItem>> analyzeTranscriptAndDetectHighlights({
    required double totalDuration,
    required String? transcript,
    required int targetClipCount,
    required double preferredDuration,
    String? provider,
    String? geminiApiKey,
    String? openRouterApiKey,
    String? groqApiKey,
    String? cerebrasApiKey,
    required Function(String) logCallback,
  }) async {
    logCallback("Initiating highlight detection (Target: $targetClipCount clips)...");

    // Resolve provider from settings if not passed
    final activeProvider = (provider != null && provider.trim().isNotEmpty)
        ? provider.trim().toLowerCase()
        : (await ProjectStorageService.getSelectedAiProvider()).toLowerCase();

    // Resolve API keys from settings if omitted
    geminiApiKey ??= await ProjectStorageService.getGeminiApiKey();
    openRouterApiKey ??= await ProjectStorageService.getOpenRouterApiKey();
    groqApiKey ??= await ProjectStorageService.getGroqApiKey();
    cerebrasApiKey ??= await ProjectStorageService.getCerebrasApiKey();

    logCallback("Active AI Engine: ${_getProviderDisplayName(activeProvider)}");

    if (transcript != null && transcript.trim().length > 50 && activeProvider != 'heuristic') {
      // 1. Primary route based on user selection
      try {
        List<ClipItem>? clips;
        switch (activeProvider) {
          case 'gemini':
            if (geminiApiKey != null && geminiApiKey.trim().isNotEmpty) {
              clips = await _queryGemini(
                apiKey: geminiApiKey.trim(),
                transcript: transcript,
                clipCount: targetClipCount,
                totalDuration: totalDuration,
                preferredDuration: preferredDuration,
                logCallback: logCallback,
              );
            } else {
              logCallback("Gemini API key not configured. Checking fallbacks...");
            }
            break;

          case 'openrouter':
            if (openRouterApiKey != null && openRouterApiKey.trim().isNotEmpty) {
              clips = await _queryOpenRouter(
                apiKey: openRouterApiKey.trim(),
                transcript: transcript,
                clipCount: targetClipCount,
                totalDuration: totalDuration,
                preferredDuration: preferredDuration,
                logCallback: logCallback,
              );
            } else {
              logCallback("OpenRouter API key not configured. Checking fallbacks...");
            }
            break;

          case 'groq':
            if (groqApiKey != null && groqApiKey.trim().isNotEmpty) {
              clips = await _queryGroq(
                apiKey: groqApiKey.trim(),
                transcript: transcript,
                clipCount: targetClipCount,
                totalDuration: totalDuration,
                preferredDuration: preferredDuration,
                logCallback: logCallback,
              );
            } else {
              logCallback("Groq API key not configured. Checking fallbacks...");
            }
            break;

          case 'cerebras':
            if (cerebrasApiKey != null && cerebrasApiKey.trim().isNotEmpty) {
              clips = await _queryCerebras(
                apiKey: cerebrasApiKey.trim(),
                transcript: transcript,
                clipCount: targetClipCount,
                totalDuration: totalDuration,
                preferredDuration: preferredDuration,
                logCallback: logCallback,
              );
            } else {
              logCallback("Cerebras API key not configured. Checking fallbacks...");
            }
            break;
        }

        if (clips != null && clips.isNotEmpty) {
          logCallback("AI Engine successfully identified ${clips.length} highlight moments.");
          return clips;
        }
      } catch (e) {
        logCallback("Primary AI engine ($activeProvider) error: $e. Checking alternate providers...");
      }

      // 2. Cascade through remaining available providers if primary failed
      final fallbacks = ['gemini', 'openrouter', 'groq', 'cerebras']
          .where((p) => p != activeProvider)
          .toList();

      for (final alt in fallbacks) {
        try {
          List<ClipItem>? altClips;
          if (alt == 'gemini' && geminiApiKey != null && geminiApiKey.trim().isNotEmpty) {
            logCallback("Switching to fallback provider: Gemini 1.5 Flash...");
            altClips = await _queryGemini(
              apiKey: geminiApiKey.trim(),
              transcript: transcript,
              clipCount: targetClipCount,
              totalDuration: totalDuration,
              preferredDuration: preferredDuration,
              logCallback: logCallback,
            );
          } else if (alt == 'openrouter' && openRouterApiKey != null && openRouterApiKey.trim().isNotEmpty) {
            logCallback("Switching to fallback provider: OpenRouter...");
            altClips = await _queryOpenRouter(
              apiKey: openRouterApiKey.trim(),
              transcript: transcript,
              clipCount: targetClipCount,
              totalDuration: totalDuration,
              preferredDuration: preferredDuration,
              logCallback: logCallback,
            );
          } else if (alt == 'groq' && groqApiKey != null && groqApiKey.trim().isNotEmpty) {
            logCallback("Switching to fallback provider: Groq LLaMA 3.3 70B...");
            altClips = await _queryGroq(
              apiKey: groqApiKey.trim(),
              transcript: transcript,
              clipCount: targetClipCount,
              totalDuration: totalDuration,
              preferredDuration: preferredDuration,
              logCallback: logCallback,
            );
          } else if (alt == 'cerebras' && cerebrasApiKey != null && cerebrasApiKey.trim().isNotEmpty) {
            logCallback("Switching to fallback provider: Cerebras LLaMA 3.1 70B...");
            altClips = await _queryCerebras(
              apiKey: cerebrasApiKey.trim(),
              transcript: transcript,
              clipCount: targetClipCount,
              totalDuration: totalDuration,
              preferredDuration: preferredDuration,
              logCallback: logCallback,
            );
          }

          if (altClips != null && altClips.isNotEmpty) {
            logCallback("Fallback engine ($alt) generated ${altClips.length} clips.");
            return altClips;
          }
        } catch (err) {
          logCallback("Fallback to $alt failed: $err");
        }
      }
    }

    // 3. Offline Mathematical Heuristic: Uniform Segment Fallback
    logCallback("Applying Uniform Segment Fallback (offline mathematical heuristic)...");
    return _algorithmicFallbackSplit(
      totalDuration: totalDuration,
      clipCount: targetClipCount,
      preferredDuration: preferredDuration,
    );
  }

  /// Backward-compatible alias for analyzeTranscriptAndDetectHighlights
  Future<List<ClipItem>> detectHighlights({
    required double totalDuration,
    required String? transcript,
    required int targetClipCount,
    required double preferredDuration,
    String? provider,
    String? geminiApiKey,
    String? openRouterApiKey,
    String? groqApiKey,
    String? cerebrasApiKey,
    required Function(String) logCallback,
  }) {
    return analyzeTranscriptAndDetectHighlights(
      totalDuration: totalDuration,
      transcript: transcript,
      targetClipCount: targetClipCount,
      preferredDuration: preferredDuration,
      provider: provider,
      geminiApiKey: geminiApiKey,
      openRouterApiKey: openRouterApiKey,
      groqApiKey: groqApiKey,
      cerebrasApiKey: cerebrasApiKey,
      logCallback: logCallback,
    );
  }

  String _getProviderDisplayName(String provider) {
    switch (provider.toLowerCase()) {
      case 'gemini':
        return 'Google Gemini (gemini-1.5-flash)';
      case 'openrouter':
        return 'OpenRouter (Gemini 2.0 Flash / LLaMA 3.3)';
      case 'groq':
        return 'Groq (llama-3.3-70b-versatile)';
      case 'cerebras':
        return 'Cerebras (llama3.1-70b)';
      case 'heuristic':
        return 'Uniform Segment (Offline Heuristic)';
      default:
        return provider;
    }
  }

  String _buildPrompt({
    required String transcript,
    required int clipCount,
    required double preferredDuration,
  }) {
    final clampedText = transcript.length > 14000 ? transcript.substring(0, 14000) : transcript;
    final int minDur = max(20, (preferredDuration - 15).toInt());
    final int maxDur = min(90, (preferredDuration + 20).toInt());

    return """
You are a viral YouTube Shorts and TikTok strategist. Analyze this timestamped video transcript.
Identify exactly $clipCount highly engaging, self-contained viral segments (duration between $minDur and $maxDur seconds).
Return ONLY a valid JSON array matching this exact schema:
[
  {
    "start": 12.5,
    "end": 48.0,
    "title": "Short Hook Headline #keyword",
    "reason": "Why this moment pops",
    "tag": "Strong hook"
  }
]
Transcript:
$clampedText
""";
  }

  /// Provider 1: Google Gemini 1.5 Flash
  Future<List<ClipItem>> _queryGemini({
    required String apiKey,
    required String transcript,
    required int clipCount,
    required double totalDuration,
    required double preferredDuration,
    required Function(String) logCallback,
  }) async {
    logCallback("Querying Google Gemini API (gemini-1.5-flash)...");
    final prompt = _buildPrompt(transcript: transcript, clipCount: clipCount, preferredDuration: preferredDuration);

    final url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey";
    final response = await _dio.post(
      url,
      options: Options(headers: {
        "Content-Type": "application/json",
      }),
      data: {
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.3,
          "maxOutputTokens": 2048,
          "responseMimeType": "application/json"
        }
      },
    );

    final candidates = response.data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception("Gemini returned no candidates in response.");
    }
    final content = candidates[0]['content']['parts'][0]['text'] as String;
    return _parseAiJsonResponse(content, totalDuration);
  }

  /// Provider 2: OpenRouter API (Gemini 2.0 Flash Lite / LLaMA 3.3 70B Instruct)
  Future<List<ClipItem>> _queryOpenRouter({
    required String apiKey,
    required String transcript,
    required int clipCount,
    required double totalDuration,
    required double preferredDuration,
    required Function(String) logCallback,
  }) async {
    final prompt = _buildPrompt(transcript: transcript, clipCount: clipCount, preferredDuration: preferredDuration);

    // Attempt primary free model first
    try {
      logCallback("Querying OpenRouter API (google/gemini-2.0-flash-lite-preview-02-05:free)...");
      return await _postOpenRouter(
        apiKey: apiKey,
        model: "google/gemini-2.0-flash-lite-preview-02-05:free",
        prompt: prompt,
        totalDuration: totalDuration,
      );
    } catch (e) {
      logCallback("OpenRouter free tier busy ($e). Retrying with meta-llama/llama-3.3-70b-instruct...");
      return await _postOpenRouter(
        apiKey: apiKey,
        model: "meta-llama/llama-3.3-70b-instruct",
        prompt: prompt,
        totalDuration: totalDuration,
      );
    }
  }

  Future<List<ClipItem>> _postOpenRouter({
    required String apiKey,
    required String model,
    required String prompt,
    required double totalDuration,
  }) async {
    final response = await _dio.post(
      "https://openrouter.ai/api/v1/chat/completions",
      options: Options(headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://clipshield.pro",
        "X-Title": "ClipShield Pro",
      }),
      data: {
        "model": model,
        "messages": [
          {"role": "user", "content": prompt}
        ],
        "temperature": 0.3,
        "max_tokens": 1500,
      },
    );

    final choices = response.data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception("OpenRouter returned no choices.");
    }
    final content = choices[0]['message']['content'] as String;
    return _parseAiJsonResponse(content, totalDuration);
  }

  /// Provider 3: Groq API (llama-3.3-70b-versatile)
  Future<List<ClipItem>> _queryGroq({
    required String apiKey,
    required String transcript,
    required int clipCount,
    required double totalDuration,
    required double preferredDuration,
    required Function(String) logCallback,
  }) async {
    logCallback("Querying Groq API (llama-3.3-70b-versatile)...");
    final prompt = _buildPrompt(transcript: transcript, clipCount: clipCount, preferredDuration: preferredDuration);

    final response = await _dio.post(
      "https://api.groq.com/openai/v1/chat/completions",
      options: Options(headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      }),
      data: {
        "model": "llama-3.3-70b-versatile",
        "messages": [
          {"role": "user", "content": prompt}
        ],
        "temperature": 0.3,
        "max_tokens": 1500,
      },
    );

    final choices = response.data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception("Groq returned empty response.");
    }
    final content = choices[0]['message']['content'] as String;
    return _parseAiJsonResponse(content, totalDuration);
  }

  /// Provider 4: Cerebras API (llama3.1-70b)
  Future<List<ClipItem>> _queryCerebras({
    required String apiKey,
    required String transcript,
    required int clipCount,
    required double totalDuration,
    required double preferredDuration,
    required Function(String) logCallback,
  }) async {
    logCallback("Querying Cerebras Ultra-Fast API (llama3.1-70b)...");
    final prompt = _buildPrompt(transcript: transcript, clipCount: clipCount, preferredDuration: preferredDuration);

    final response = await _dio.post(
      "https://api.cerebras.ai/v1/chat/completions",
      options: Options(headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      }),
      data: {
        "model": "llama3.1-70b",
        "messages": [
          {"role": "user", "content": prompt}
        ],
        "temperature": 0.3,
      },
    );

    final choices = response.data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception("Cerebras returned empty response.");
    }
    final content = choices[0]['message']['content'] as String;
    return _parseAiJsonResponse(content, totalDuration);
  }

  /// Parses JSON response from LLMs into ClipItem models
  List<ClipItem> _parseAiJsonResponse(String content, double maxDuration) {
    String cleanJson = content.trim();
    if (cleanJson.contains("```json")) {
      cleanJson = cleanJson.split("```json")[1].split("```")[0].trim();
    } else if (cleanJson.contains("```")) {
      cleanJson = cleanJson.split("```")[1].split("```")[0].trim();
    }

    // Extract JSON array if surrounded by chatter
    final firstBracket = cleanJson.indexOf('[');
    final lastBracket = cleanJson.lastIndexOf(']');
    if (firstBracket != -1 && lastBracket != -1 && lastBracket > firstBracket) {
      cleanJson = cleanJson.substring(firstBracket, lastBracket + 1);
    }

    final List<dynamic> list = json.decode(cleanJson);
    List<ClipItem> results = [];
    int baseScore = 96;

    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      final double start = (item['start'] as num).toDouble().clamp(0.0, maxDuration);
      double end = (item['end'] as num).toDouble().clamp(start + 15.0, maxDuration);
      if (end <= start) end = min(maxDuration, start + 45.0);

      final durStr = formatClipDuration(start, end);

      results.add(ClipItem(
        id: "clip_${i + 1}_${DateTime.now().millisecondsSinceEpoch}",
        title: item['title'] ?? "Engaging Highlight #${i + 1}",
        duration: durStr,
        startTime: start,
        endTime: end,
        score: max(75, baseScore - (i * 4)),
        tag: item['tag'] ?? (i == 0 ? "Strong hook" : (i == 1 ? "Emotional" : "Key moment")),
        reason: item['reason'] ?? "High virality potential flagged by AI model.",
      ));
    }

    return results;
  }

  /// Algorithmic Uniform Segment Fallback (offline mathematical heuristic)
  List<ClipItem> _algorithmicFallbackSplit({
    required double totalDuration,
    required int clipCount,
    required double preferredDuration,
  }) {
    List<ClipItem> results = [];
    final Random random = Random();

    final double clipLen = preferredDuration.clamp(25.0, 90.0);
    final tags = ["Strong hook", "Emotional", "Listicle", "Debate", "Punchy", "Insight", "Climax"];
    final titles = [
      "The pivotal insight you missed",
      "Why nobody discusses this shift",
      "3 essential rules for the breakthrough",
      "The unexpected strategy that changed everything",
      "The fundamental truth about this process",
      "A rare perspective worth remembering",
    ];

    if (totalDuration <= clipLen + 5.0) {
      // Short video: single clip
      results.add(ClipItem(
        id: "clip_1_${DateTime.now().millisecondsSinceEpoch}",
        title: titles[0],
        duration: formatDuration(totalDuration),
        startTime: 0.0,
        endTime: totalDuration,
        score: 96,
        tag: "Strong hook",
        reason: "Full source segment with complete narrative flow.",
      ));
      return results;
    }

    final double segmentInterval = (totalDuration - clipLen) / max(1, clipCount);

    for (int i = 0; i < clipCount; i++) {
      final double start = (i * segmentInterval) + (random.nextDouble() * 2.0);
      final double end = min(totalDuration, start + clipLen);
      final double durSec = end - start;

      final int m = durSec ~/ 60;
      final int s = (durSec % 60).toInt();
      final durStr = "$m:${s.toString().padLeft(2, '0')}";

      final int score = 96 - (i * 4) + random.nextInt(3);

      results.add(ClipItem(
        id: "clip_${i + 1}_${DateTime.now().millisecondsSinceEpoch}",
        title: titles[i % titles.length],
        duration: durStr,
        startTime: start,
        endTime: end,
        score: score.clamp(70, 99),
        tag: tags[i % tags.length],
        reason: "Uniform mathematical partitioning with optimal pacing balance.",
      ));
    }

    return results;
  }
}
