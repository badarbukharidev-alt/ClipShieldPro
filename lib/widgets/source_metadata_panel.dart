import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/source_metadata.dart';
import '../services/gallery_export_service.dart';
import '../theme/app_theme.dart';

/// Shows the original video's title, description, keywords and thumbnail with
/// one-tap copy and download, so a creator can reuse the source metadata when
/// publishing the transformed export.
class SourceMetadataPanel extends StatefulWidget {
  final SourceMetadata metadata;
  final Color accent;

  const SourceMetadataPanel({
    super.key,
    required this.metadata,
    this.accent = AppColors.accentTangerine,
  });

  @override
  State<SourceMetadataPanel> createState() => _SourceMetadataPanelState();
}

class _SourceMetadataPanelState extends State<SourceMetadataPanel> {
  bool _descriptionExpanded = false;
  bool _isDownloadingThumb = false;

  SourceMetadata get _meta => widget.metadata;

  void _notify(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.darkCard,
        duration: const Duration(seconds: 3),
      ));
  }

  Future<void> _copy(String label, String value) async {
    if (value.trim().isEmpty) {
      _notify("No $label available for this video", isError: true);
      return;
    }
    await Clipboard.setData(ClipboardData(text: value));
    _notify("$label copied to clipboard");
  }

  Future<void> _downloadThumbnail() async {
    // Best quality first, then fall back. maxresdefault.jpg only exists for
    // videos uploaded above 720p, so asking for it alone fails on a large share
    // of videos whose thumbnail is perfectly available one rung down.
    final candidates = <String>[
      _meta.thumbnailMaxResUrl,
      _meta.thumbnailUrl,
      if (_meta.videoId.isNotEmpty) ...[
        'https://i.ytimg.com/vi/${_meta.videoId}/hqdefault.jpg',
        'https://i.ytimg.com/vi/${_meta.videoId}/mqdefault.jpg',
      ],
    ];

    if (candidates.every((u) => u.trim().isEmpty)) {
      _notify("No thumbnail available", isError: true);
      return;
    }

    setState(() => _isDownloadingThumb = true);

    final stamp = _meta.videoId.isNotEmpty
        ? _meta.videoId
        : DateTime.now().millisecondsSinceEpoch.toString();
    final saved = await GalleryExportService.downloadImage(
      candidates,
      "ClipShield_thumb_$stamp.jpg",
    );
    if (!mounted) return;
    setState(() => _isDownloadingThumb = false);

    if (saved == null) {
      _notify("Could not download the thumbnail", isError: true);
    } else {
      _notify("Thumbnail saved to ${GalleryExportService.displayLocation(saved)}");
    }
  }

  Future<void> _saveMetadataFile() async {
    final buffer = StringBuffer()
      ..writeln("TITLE")
      ..writeln(_meta.title)
      ..writeln()
      ..writeln("CHANNEL")
      ..writeln(_meta.author)
      ..writeln()
      ..writeln("DESCRIPTION")
      ..writeln(_meta.description)
      ..writeln()
      ..writeln("KEYWORDS")
      ..writeln(_meta.keywordsCsv);

    final saved = await GalleryExportService.saveTextFile(
      buffer.toString(),
      "ClipShield_metadata_${_meta.videoId}.txt",
    );
    if (!mounted) return;
    if (saved == null) {
      _notify("Could not save metadata file", isError: true);
    } else {
      _notify("Metadata saved to ${GalleryExportService.displayLocation(saved)}");
    }
  }

  Widget _sectionLabel(String text, {Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: AppColors.mut,
              letterSpacing: 1.0,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _copyButton(String label, String value) {
    return TextButton.icon(
      onPressed: () => _copy(label, value),
      icon: const Icon(Icons.copy_rounded, size: 14),
      label: const Text("Copy"),
      style: TextButton.styleFrom(
        foregroundColor: widget.accent,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasDescription = _meta.description.trim().isNotEmpty;
    final hasKeywords = _meta.keywords.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel("SOURCE VIDEO METADATA"),
          const SizedBox(height: 12),

          // 16:9 thumbnail with an explicit full-resolution download.
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _meta.thumbnailUrl.isEmpty
                  ? Container(
                      color: AppColors.darkCard,
                      child: const Icon(Icons.image_not_supported_outlined,
                          color: AppColors.mut, size: 28),
                    )
                  : Image.network(
                      _meta.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.darkCard,
                        child: const Icon(Icons.broken_image_outlined,
                            color: AppColors.mut, size: 28),
                      ),
                      loadingBuilder: (context, child, progress) => progress == null
                          ? child
                          : Container(
                              color: AppColors.darkCard,
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isDownloadingThumb ? null : _downloadThumbnail,
              icon: _isDownloadingThumb
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded, size: 17),
              label: Text(
                _isDownloadingThumb ? "Saving..." : "Download Full HD Thumbnail",
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: widget.accent,
                side: BorderSide(color: widget.accent.withOpacity(0.6)),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),

          const Divider(height: 26, color: AppColors.line),

          // Title
          _sectionLabel("TITLE", trailing: _copyButton("Title", _meta.title)),
          const SizedBox(height: 4),
          SelectableText(
            _meta.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              height: 1.35,
            ),
          ),
          if (_meta.author.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              "${_meta.author} · ${_meta.formattedDuration}",
              style: const TextStyle(fontSize: 12, color: AppColors.mut),
            ),
          ],

          // Description
          if (hasDescription) ...[
            const Divider(height: 26, color: AppColors.line),
            _sectionLabel("DESCRIPTION",
                trailing: _copyButton("Description", _meta.description)),
            const SizedBox(height: 4),
            SelectableText(
              _meta.description,
              maxLines: _descriptionExpanded ? null : 4,
              style: const TextStyle(fontSize: 12.5, color: AppColors.mut, height: 1.45),
            ),
            GestureDetector(
              onTap: () =>
                  setState(() => _descriptionExpanded = !_descriptionExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _descriptionExpanded ? "Show less" : "Show more",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: widget.accent,
                  ),
                ),
              ),
            ),
          ],

          // Keywords
          if (hasKeywords) ...[
            const Divider(height: 26, color: AppColors.line),
            _sectionLabel(
              "KEYWORDS (${_meta.keywords.length})",
              trailing: _copyButton("Keywords", _meta.keywordsCsv),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _meta.keywords.take(24).map((k) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    k,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.ink),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            Text(
              "Copy gives you all ${_meta.keywords.length}, comma separated.",
              style: const TextStyle(fontSize: 11, color: AppColors.mut),
            ),
          ],

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _saveMetadataFile,
              icon: const Icon(Icons.save_alt_rounded, size: 16),
              label: const Text(
                "Save all metadata as .txt",
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(foregroundColor: AppColors.mut),
            ),
          ),
        ],
      ),
    );
  }
}
