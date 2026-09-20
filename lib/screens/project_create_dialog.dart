import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_modes.dart';
import '../services/downloader_service.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

class ProjectCreateDialog extends StatefulWidget {
  final AppMode initialMode;
  final Function({
    required AppMode mode,
    required SourceType sourceType,
    required String sourcePathOrUrl,
    required bool authorized,
  }) onProceed;

  const ProjectCreateDialog({
    super.key,
    this.initialMode = AppMode.transformAndProtect,
    required this.onProceed,
  });

  @override
  State<ProjectCreateDialog> createState() => _ProjectCreateDialogState();
}

class _ProjectCreateDialogState extends State<ProjectCreateDialog> {
  late AppMode _selectedMode;
  SourceType _sourceType = SourceType.youtubeUrl;
  final TextEditingController _urlController = TextEditingController();
  final DownloaderService _downloaderService = DownloaderService();
  Timer? _debounceTimer;
  
  String? _selectedFilePath;
  bool _isAuthorized = false;
  bool _isFetchingMetadata = false;
  yt.Video? _ytPreviewVideo;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
    _urlController.addListener(_onUrlChanged);
  }

  void _onUrlChanged() {
    _debounceTimer?.cancel();
    final text = _urlController.text.trim();
    if (text.isNotEmpty && _downloaderService.getVideoId(text) != null) {
      _debounceTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) {
          _fetchYtMetadata(text);
        }
      });
    } else {
      if (_ytPreviewVideo != null) {
        setState(() => _ytPreviewVideo = null);
      }
    }
  }

  Future<void> _fetchYtMetadata(String url) async {
    final videoId = _downloaderService.getVideoId(url);
    if (videoId == null) {
      if (_ytPreviewVideo != null) {
        setState(() => _ytPreviewVideo = null);
      }
      return;
    }

    if (_ytPreviewVideo?.id.value == videoId) return;

    setState(() => _isFetchingMetadata = true);
    try {
      final video = await _downloaderService
          .getVideoDetails(url)
          .timeout(const Duration(seconds: 8));
      if (mounted) {
        setState(() {
          _ytPreviewVideo = video;
          _isFetchingMetadata = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isFetchingMetadata = false);
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _downloaderService.dispose();
    super.dispose();
  }

  Future<void> _pickLocalFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: _selectedMode == AppMode.songRemover ? FileType.any : FileType.video,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
        _isAuthorized = true; // local file imported by user
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrl = _sourceType == SourceType.youtubeUrl;
    final isProtect = _selectedMode == AppMode.transformAndProtect;
    final isMode1 = _selectedMode == AppMode.longVideoToShorts;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.line.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            const Text(
              "Create New Project",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Select workflow mode and source video",
              style: TextStyle(
                fontSize: 13,
                color: AppColors.mut,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),

            // Mode Selector: Copyright Remover (Top/First) vs Shorts Clipper (Second)
            const Text(
              "PRIMARY APP MODE",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.mut,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedMode = AppMode.transformAndProtect),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isProtect ? AppColors.accentGrape : AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isProtect ? AppColors.accentGrape : AppColors.line,
                          width: 1.5,
                        ),
                        boxShadow: isProtect
                            ? [
                                BoxShadow(
                                  color: AppColors.accentGrape.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 20,
                            color: isProtect ? Colors.white : AppColors.accentGrape,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Copyright Remover",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isProtect ? Colors.white : AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "9-Layer DSP (16:9)",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isProtect ? Colors.white.withOpacity(0.8) : AppColors.mut,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedMode = AppMode.longVideoToShorts),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isMode1 ? AppColors.accentTangerine : AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isMode1 ? AppColors.accentTangerine : AppColors.line,
                          width: 1.5,
                        ),
                        boxShadow: isMode1
                            ? [
                                BoxShadow(
                                  color: AppColors.accentTangerine.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 20,
                            color: isMode1 ? Colors.white : AppColors.accentTangerine,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Video → Shorts",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isMode1 ? Colors.white : AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "AI Highlight (9:16)",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isMode1 ? Colors.white.withOpacity(0.8) : AppColors.mut,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Songs Remover Mode Button
            GestureDetector(
              onTap: () => setState(() => _selectedMode = AppMode.songRemover),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: _selectedMode == AppMode.songRemover ? AppColors.accentLime : AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedMode == AppMode.songRemover ? AppColors.accentLime : AppColors.line,
                    width: 1.5,
                  ),
                  boxShadow: _selectedMode == AppMode.songRemover
                      ? [
                          BoxShadow(
                            color: AppColors.accentLime.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.music_note,
                      size: 20,
                      color: _selectedMode == AppMode.songRemover ? Colors.white : AppColors.accentLime,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Songs Remover",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _selectedMode == AppMode.songRemover ? Colors.white : AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Audio DSP + Cover Image",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _selectedMode == AppMode.songRemover ? Colors.white.withOpacity(0.8) : AppColors.mut,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Source Tabs (YouTube URL vs Local Upload)
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _sourceType = SourceType.youtubeUrl),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isUrl ? AppColors.accentTangerine : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            "YouTube URL",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isUrl ? Colors.white : AppColors.mut,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _sourceType = SourceType.localVideo),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isUrl ? AppColors.accentTangerine : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            _selectedMode == AppMode.songRemover ? "Upload Audio/Video" : "Upload Video",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: !isUrl ? Colors.white : AppColors.mut,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // URL input or File Picker
            if (isUrl) ...[
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.line),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_fill, color: Colors.red, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        decoration: const InputDecoration(
                          hintText: "Paste YouTube link (https://...)",
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: AppColors.mut),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () async {
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        if (data != null && data.text != null && data.text!.isNotEmpty) {
                          _urlController.text = data.text!;
                          _urlController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _urlController.text.length),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.softTangerine,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.content_paste_rounded,
                          color: AppColors.accentTangerine,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isFetchingMetadata) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentTangerine),
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Fetching YouTube video metadata...",
                        style: TextStyle(fontSize: 12.5, color: AppColors.mut, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ] else if (_ytPreviewVideo != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.softTangerine, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          _ytPreviewVideo!.thumbnails.mediumResUrl,
                          width: 80,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 80,
                            height: 56,
                            color: AppColors.darkCard,
                            child: const Icon(Icons.movie, color: Colors.white70),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _ytPreviewVideo!.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${_ytPreviewVideo!.author} • ${_ytPreviewVideo!.duration != null ? '${_ytPreviewVideo!.duration!.inMinutes}:${(_ytPreviewVideo!.duration!.inSeconds % 60).toString().padLeft(2, '0')}' : 'YouTube'}",
                              style: const TextStyle(fontSize: 11, color: AppColors.mut),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              GestureDetector(
                onTap: _pickLocalFile,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.line, style: BorderStyle.solid),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.softTangerine,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.file_upload_outlined, color: AppColors.accentTangerine, size: 28),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedFilePath != null
                            ? _selectedFilePath!.split('/').last.split('\\').last
                            : "Tap to choose a local video",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "MP4, MOV, or WEBM · Android on-device storage",
                        style: TextStyle(fontSize: 12, color: AppColors.mut),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Rights & Authorization Disclaimer (Mandatory Legal Compliance)
            GestureDetector(
              onTap: () => setState(() => _isAuthorized = !_isAuthorized),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.softTangerine,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: _isAuthorized ? AppColors.accentTangerine : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.accentTangerine,
                          width: 2,
                        ),
                      ),
                      child: _isAuthorized
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "I have rights or permission for this media",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            "ClipShield Pro is an authorized transformation & short-form tool. Content is materially edited on-device.",
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.mut,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            ElevatedButton(
              onPressed: () {
                final source = isUrl ? _urlController.text.trim() : (_selectedFilePath ?? '');
                if (source.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please select a video or paste a YouTube URL")),
                  );
                  return;
                }
                if (!_isAuthorized) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please confirm rights authorization to proceed")),
                  );
                  return;
                }

                Navigator.pop(context);
                widget.onProceed(
                  mode: _selectedMode,
                  sourceType: _sourceType,
                  sourcePathOrUrl: source,
                  authorized: _isAuthorized,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedMode == AppMode.songRemover ? AppColors.accentLime : (isMode1 ? AppColors.accentTangerine : AppColors.accentGrape),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _selectedMode == AppMode.songRemover ? Icons.music_video : (isMode1 ? Icons.auto_awesome : Icons.tune),
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedMode == AppMode.songRemover ? "Open Audio DSP Studio" : (isMode1 ? "Analyze with AI" : "Configure 12-Layer Transform"),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
