import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';

class PreviewScreen extends StatefulWidget {
  final String originalVideoPath;
  final String transformedVideoPath;
  final String title;
  final String duration;

  const PreviewScreen({
    super.key,
    required this.originalVideoPath,
    required this.transformedVideoPath,
    required this.title,
    required this.duration,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late VideoPlayerController _transformedController;
  late VideoPlayerController _originalController;
  bool _showTransformed = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  Future<void> _initControllers() async {
    _transformedController =
        VideoPlayerController.file(File(widget.transformedVideoPath));
    _originalController =
        VideoPlayerController.file(File(widget.originalVideoPath));

    await Future.wait([
      _transformedController.initialize(),
      _originalController.initialize(),
    ]);

    _transformedController.setLooping(true);
    _originalController.setLooping(true);
    _transformedController.play();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _transformedController.dispose();
    _originalController.dispose();
    super.dispose();
  }

  void _togglePreviewMode(bool showTransformed) {
    setState(() {
      _showTransformed = showTransformed;
      if (_showTransformed) {
        _originalController.pause();
        _transformedController.seekTo(_originalController.value.position);
        _transformedController.play();
      } else {
        _transformedController.pause();
        _originalController.seekTo(_transformedController.value.position);
        _originalController.play();
      }
    });
  }

  Future<void> _shareClip() async {
    final path = _showTransformed
        ? widget.transformedVideoPath
        : widget.originalVideoPath;
    await Share.shareXFiles([XFile(path)], text: widget.title);
  }

  @override
  Widget build(BuildContext context) {
    final activeController =
        _showTransformed ? _transformedController : _originalController;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _showTransformed
                          ? AppColors.accentTangerine
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _showTransformed ? "TRANSFORMED" : "ORIGINAL",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Mode Toggle Pill
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _togglePreviewMode(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: !_showTransformed
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Original",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: !_showTransformed
                                ? AppColors.ink
                                : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _togglePreviewMode(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _showTransformed
                              ? AppColors.accentTangerine
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Transformed (9-Layer)",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _showTransformed
                                ? Colors.white
                                : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Video canvas sized to the clip's real aspect ratio. It used to be
              // a fixed portrait viewport, which framed every 16:9 export inside
              // a 9:16 Shorts window with heavy black bars.
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio:
                        _isInitialized && activeController.value.aspectRatio > 0
                            ? activeController.value.aspectRatio
                            : 9.0 / 16.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(22),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_isInitialized)
                            Positioned.fill(
                                child: VideoPlayer(activeController))
                          else
                            const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.accentTangerine)),

                          // Subject Tracking Indicator overlay
                          if (_showTransformed)
                            Positioned(
                              top: 20,
                              left: 20,
                              child: Container(
                                width: 65,
                                height: 65,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: AppColors.accentTangerine,
                                      width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Align(
                                  alignment: Alignment.topLeft,
                                  child: Padding(
                                    padding: EdgeInsets.all(2.0),
                                    child: Text(
                                      "SUBJECT",
                                      style: TextStyle(
                                        color: AppColors.accentTangerine,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Play/Pause Center Tap
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (activeController.value.isPlaying) {
                                  activeController.pause();
                                } else {
                                  activeController.play();
                                }
                              });
                            },
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                activeController.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),

                          // Video Bottom Progress
                          if (_isInitialized)
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  VideoProgressIndicator(
                                    activeController,
                                    allowScrubbing: true,
                                    colors: const VideoProgressColors(
                                      playedColor: AppColors.accentTangerine,
                                      bufferedColor: Colors.white24,
                                      backgroundColor: Colors.white12,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      ValueListenableBuilder(
                                        valueListenable: activeController,
                                        builder:
                                            (context, VideoPlayerValue val, _) {
                                          final p = val.position;
                                          return Text(
                                            "${p.inMinutes}:${(p.inSeconds % 60).toString().padLeft(2, '0')}",
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11),
                                          );
                                        },
                                      ),
                                      Text(
                                        widget.duration,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bottom Actions: Share & Done
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _shareClip,
                      icon: const Icon(Icons.share,
                          size: 18, color: Colors.white),
                      label: const Text("Share Asset",
                          style: TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.accentTangerine,
                      ),
                      child: const Text("Done",
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
