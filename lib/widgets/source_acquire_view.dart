import 'package:flutter/material.dart';
import '../models/source_metadata.dart';
import '../theme/app_theme.dart';

/// Full-screen view shown while a source is being fetched and probed.
///
/// Replaces a bare spinner with the thing the user actually wants to see: which
/// video is being pulled, how far along it is, and what stage it is in.
class SourceAcquireView extends StatelessWidget {
  final String title;
  final String stageMessage;

  /// Null renders an indeterminate ring, for stages with no measurable progress.
  final double? progress;

  final SourceMetadata? metadata;
  final Color accent;
  final VoidCallback? onCancel;

  const SourceAcquireView({
    super.key,
    required this.title,
    required this.stageMessage,
    this.progress,
    this.metadata,
    this.accent = AppColors.accentTangerine,
    this.onCancel,
  });

  /// The stages a source goes through, in order. The active one is derived from
  /// progress so the list never disagrees with the ring.
  static const List<String> _stages = [
    "Resolving stream manifest",
    "Downloading video track",
    "Downloading audio track",
    "Muxing & probing tracks",
  ];

  int get _activeStage {
    final p = progress;
    if (p == null) return 0;
    if (p < 0.15) return 0;
    if (p < 0.70) return 1;
    if (p < 0.85) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final int percent =
        progress == null ? 0 : (progress!.clamp(0.0, 1.0) * 100).round();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  if (onCancel != null)
                    IconButton(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close, color: AppColors.mut),
                      tooltip: "Cancel",
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Source preview, so the user can confirm the right video
              if (metadata != null) _buildSourceCard(metadata!),
              if (metadata != null) const SizedBox(height: 22),

              // Progress ring
              Center(
                child: SizedBox(
                  width: 168,
                  height: 168,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 168,
                        height: 168,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 9,
                          strokeCap: StrokeCap.round,
                          backgroundColor: AppColors.line.withOpacity(0.5),
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            progress == null ? "···" : "$percent%",
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "ACQUIRING",
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: accent,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Stage checklist
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: ListView.builder(
                    itemCount: _stages.length,
                    itemBuilder: (context, index) {
                      final bool isDone = index < _activeStage;
                      final bool isActive = index == _activeStage;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDone
                                    ? accent
                                    : (isActive
                                        ? accent.withOpacity(0.18)
                                        : AppColors.line.withOpacity(0.35)),
                              ),
                              child: isDone
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : (isActive
                                      ? Center(
                                          child: SizedBox(
                                            width: 11,
                                            height: 11,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(accent),
                                            ),
                                          ),
                                        )
                                      : null),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _stages[index],
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight:
                                      isActive ? FontWeight.w700 : FontWeight.w600,
                                  color:
                                      isDone || isActive ? AppColors.ink : AppColors.mut,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Text(
                stageMessage,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mut,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceCard(SourceMetadata meta) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: SizedBox(
              width: 116,
              height: 65,
              child: meta.thumbnailUrl.isEmpty
                  ? Container(color: AppColors.darkCard)
                  : Image.network(
                      meta.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: AppColors.darkCard),
                      loadingBuilder: (context, child, p) =>
                          p == null ? child : Container(color: AppColors.darkCard),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        meta.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.mut),
                      ),
                    ),
                    if (meta.durationSeconds > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        meta.formattedDuration,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
