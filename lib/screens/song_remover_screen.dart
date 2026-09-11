import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import '../models/app_modes.dart';
import '../models/audio_dsp_config.dart';
import '../models/clip_model.dart';
import '../models/project_model.dart';
import '../services/downloader_service.dart';
import '../services/ffmpeg_engine_service.dart';
import '../services/media_probe_service.dart';
import '../transformation/song_remover_pipeline.dart';
import '../theme/app_theme.dart';
import 'results_screen.dart';

class SongRemoverScreen extends StatefulWidget {
  final String sourcePathOrUrl;
  final SourceType sourceType;

  const SongRemoverScreen({
    super.key,
    required this.sourcePathOrUrl,
    required this.sourceType,
  });

  @override
  State<SongRemoverScreen> createState() => _SongRemoverScreenState();
}

class _SongRemoverScreenState extends State<SongRemoverScreen> {
  final DownloaderService _downloader = DownloaderService();
  final FfmpegEngineService _ffmpegService = FfmpegEngineService();
  final SongRemoverPipeline _pipeline = SongRemoverPipeline();

  final AudioDspConfig _config = AudioDspConfig();
  MediaProbeInfo? _probeInfo;
  String? _localPath;
  bool _isLoading = true;
  String _loadingMessage = "Preparing media...";

  // Cover image
  String? _coverImagePath;
  bool _isWidescreen = true; // true=16:9, false=9:16

  // Preview & Render state
  bool _isPreviewPlaying = false;
  bool _isRendering = false;

  @override
  void initState() {
    super.initState();
    _initializeSource();
  }

  @override
  void dispose() {
    _downloader.dispose();
    super.dispose();
  }

  Future<void> _initializeSource() async {
    try {
      if (widget.sourceType == SourceType.youtubeUrl) {
        setState(() => _loadingMessage = "Downloading audio stream...");
        final tempDir = await getTemporaryDirectory();
        final downloadDir = "${tempDir.path}/clipshield_song_remover";
        _localPath = await _downloader.downloadVideo(
          url: widget.sourcePathOrUrl,
          downloadDir: downloadDir,
          quality: 'balanced',
          progressCallback: (p, msg) {
            setState(() => _loadingMessage = msg);
          },
        );
      } else {
        _localPath = widget.sourcePathOrUrl;
      }

      setState(() => _loadingMessage = "Probing media tracks...");
      _probeInfo = await MediaProbeService.probe(_localPath!);

      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text("Failed: $e")),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _pickCoverImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _coverImagePath = result.files.single.path);
    }
  }

  Future<void> _preview10s() async {
    if (_localPath == null || _isPreviewPlaying) return;
    setState(() => _isPreviewPlaying = true);

    try {
      final tempDir = await getTemporaryDirectory();
      final previewPath = path.join(tempDir.path, "song_preview_${DateTime.now().millisecondsSinceEpoch}.m4a");

      final args = _pipeline.buildPreviewArgs(
        inputPath: _localPath!,
        outputPath: previewPath,
        config: _config,
        logCallback: (_) {},
      );

      final session = await FFmpegKit.executeWithArguments(args);
      final returnCode = await session.getReturnCode();

      if (returnCode != null && returnCode.isValueSuccess() && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Preview generated! Check your device audio."),
            backgroundColor: AppColors.accentLime,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Preview failed: $e"), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isPreviewPlaying = false);
    }
  }

  Future<void> _renderFinal() async {
    if (_localPath == null || _isRendering) return;
    if (_coverImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a cover image first")),
      );
      return;
    }

    setState(() => _isRendering = true);

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final outputDir = Directory(path.join(appDir.path, "ClipShield_Songs"));
      if (!await outputDir.exists()) await outputDir.create(recursive: true);

      final ts = DateTime.now().millisecondsSinceEpoch;

      // Step 1: Process audio with DSP chain
      final audioPath = path.join(outputDir.path, "processed_audio_$ts.m4a");
      await _ffmpegService.renderSongRemoverAudio(
        inputPath: _localPath!,
        outputPath: audioPath,
        config: _config,
        onProgress: (p, s) {},
        logCallback: (_) {},
      );

      // Step 2: Compose cover image + audio → video
      final videoPath = path.join(outputDir.path, "ClipShield_Song_$ts.mp4");
      await _ffmpegService.composeCoverVideo(
        imagePath: _coverImagePath!,
        audioPath: audioPath,
        outputPath: videoPath,
        isWidescreen: _isWidescreen,
        onProgress: (p, s) {},
        logCallback: (_) {},
      );

      // Step 3: Generate thumbnail
      final thumbPath = path.join(outputDir.path, "thumb_$ts.jpg");
      try {
        await _ffmpegService.extractThumbnail(videoPath: videoPath, thumbnailPath: thumbPath);
      } catch (_) {}

      if (!mounted) return;

      final clip = ClipItem(
        id: "song_$ts",
        title: "Processed Audio Export",
        duration: "${_probeInfo?.duration.toInt() ?? 0}s",
        startTime: 0.0,
        endTime: _probeInfo?.duration ?? 0.0,
        score: 100,
        tag: "Song",
      );
      clip.outputPath = videoPath;
      clip.thumbnailPath = thumbPath;
      clip.isRendered = true;

      final project = ProjectItem(
        id: "song_proj_$ts",
        mode: AppMode.songRemover,
        title: "Songs Remover Export",
        sourceUrlOrPath: _localPath!,
        sourceType: widget.sourceType,
        clips: [clip],
        preset: PipelinePreset.balanced,
        aspectRatio: _isWidescreen ? AspectRatioOption.original169 : AspectRatioOption.vertical916,
      );
      project.status = 'done';
      project.outputPaths = [videoPath];
      project.thumbnailPath = thumbPath;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsScreen(project: project, renderedClips: [clip]),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Render failed: $e"), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isRendering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.accentLime),
              const SizedBox(height: 20),
              Text(_loadingMessage, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text("Songs Remover", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Source Info Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.softLime,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.music_note, color: AppColors.accentLime, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _localPath?.split('/').last.split('\\').last ?? "Audio Source",
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Duration: ${_probeInfo?.duration.toStringAsFixed(1) ?? '0'}s · ${_probeInfo?.hasAudio == true ? 'Audio ✓' : 'No audio'}",
                                style: const TextStyle(fontSize: 11.5, color: AppColors.mut),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // DSP Controls Header
                  const Text(
                    "AUDIO DSP CONTROLS",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.mut, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 10),

                  // DSP Sliders Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      children: [
                        _buildSlider("Volume", "${_config.volumeDb > 0 ? '+' : ''}${_config.volumeDb.toStringAsFixed(1)} dB",
                            _config.volumeDb, -3.0, 3.0, (v) => setState(() => _config.volumeDb = v)),
                        _buildSlider("EQ Gain", "±${_config.eqGainDb.toStringAsFixed(1)} dB",
                            _config.eqGainDb, 0.0, 4.0, (v) => setState(() => _config.eqGainDb = v)),
                        _buildSlider("Tempo", "${_config.tempoPercent > 0 ? '+' : ''}${_config.tempoPercent.toStringAsFixed(1)}%",
                            _config.tempoPercent, -5.0, 5.0, (v) => setState(() => _config.tempoPercent = v)),
                        _buildSlider("Pitch", "${_config.pitchPercent > 0 ? '+' : ''}${_config.pitchPercent.toStringAsFixed(1)}%",
                            _config.pitchPercent, -3.0, 3.0, (v) => setState(() => _config.pitchPercent = v)),
                        _buildSlider("Stereo Pan", _config.stereoPanning.toStringAsFixed(2),
                            _config.stereoPanning, -1.0, 1.0, (v) => setState(() => _config.stereoPanning = v)),
                        _buildSlider("Compression", "${_config.compressionRatio.toStringAsFixed(1)}:1",
                            _config.compressionRatio, 1.0, 4.0, (v) => setState(() => _config.compressionRatio = v)),
                        _buildSlider("Reverb Mix", "${(_config.reverbMix * 100).toStringAsFixed(0)}%",
                            _config.reverbMix, 0.0, 0.3, (v) => setState(() => _config.reverbMix = v)),
                        _buildSlider("Delay", "${_config.delayMs.toInt()} ms",
                            _config.delayMs, 0.0, 100.0, (v) => setState(() => _config.delayMs = v)),
                        _buildSlider("Fade In", "${_config.fadeInSec.toStringAsFixed(1)}s",
                            _config.fadeInSec, 0.0, 5.0, (v) => setState(() => _config.fadeInSec = v)),
                        _buildSlider("Fade Out", "${_config.fadeOutSec.toStringAsFixed(1)}s",
                            _config.fadeOutSec, 0.0, 5.0, (v) => setState(() => _config.fadeOutSec = v)),
                        const Divider(color: AppColors.line),
                        // Normalization toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Loudness Normalization", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                            Switch(
                              value: _config.normalization,
                              activeColor: AppColors.accentLime,
                              onChanged: (v) => setState(() => _config.normalization = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Output Mode Selector
                  const Text(
                    "OUTPUT MODE",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.mut, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: AudioOutputMode.values.map((mode) {
                      final isSel = _config.outputMode == mode;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _config.outputMode = mode),
                          child: Container(
                            margin: EdgeInsets.only(right: mode != AudioOutputMode.values.last ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSel ? AppColors.accentLime : AppColors.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isSel ? AppColors.accentLime : AppColors.line, width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                mode.label,
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                  color: isSel ? Colors.white : AppColors.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Cover Image Section
                  const Text(
                    "COVER IMAGE & ASPECT RATIO",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.mut, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      children: [
                        // Aspect ratio chips
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isWidescreen = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _isWidescreen ? AppColors.accentLime : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: _isWidescreen ? AppColors.accentLime : AppColors.line),
                                  ),
                                  child: Center(
                                    child: Text("16:9 Landscape",
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                        color: _isWidescreen ? Colors.white : AppColors.ink)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isWidescreen = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !_isWidescreen ? AppColors.accentLime : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: !_isWidescreen ? AppColors.accentLime : AppColors.line),
                                  ),
                                  child: Center(
                                    child: Text("9:16 Portrait",
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                        color: !_isWidescreen ? Colors.white : AppColors.ink)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Image picker
                        GestureDetector(
                          onTap: _pickCoverImage,
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.line),
                              image: _coverImagePath != null
                                  ? DecorationImage(image: FileImage(File(_coverImagePath!)), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: _coverImagePath == null
                                ? const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add_photo_alternate_outlined, size: 32, color: AppColors.mut),
                                        SizedBox(height: 6),
                                        Text("Tap to select cover image", style: TextStyle(fontSize: 12.5, color: AppColors.mut, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: _isPreviewPlaying || _isRendering ? null : _preview10s,
                      icon: _isPreviewPlaying
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentLime))
                          : const Icon(Icons.headphones, size: 18),
                      label: Text(_isPreviewPlaying ? "Processing..." : "Preview 10s"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.accentLime, width: 1.5),
                        foregroundColor: AppColors.accentLime,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: _isRendering ? null : _renderFinal,
                      icon: _isRendering
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.music_video, size: 18),
                      label: Text(_isRendering ? "Rendering..." : "Render Final"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.accentLime,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, String valueText, double value, double min, double max, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.accentLime,
                inactiveTrackColor: AppColors.line,
                thumbColor: AppColors.accentLime,
                overlayColor: AppColors.softLime.withOpacity(0.4),
                trackHeight: 4,
              ),
              child: Slider(min: min, max: max, value: value, onChanged: onChanged),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(valueText, textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.accentLime)),
          ),
        ],
      ),
    );
  }
}
