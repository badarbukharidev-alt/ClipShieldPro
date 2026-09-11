enum AppMode {
  longVideoToShorts,
  transformAndProtect,
  songRemover,
}

enum SourceType {
  youtubeUrl,
  localVideo,
  localAudio,
}

enum PipelinePreset {
  fast,
  balanced,
  advanced,
  custom,
}

enum AspectRatioOption {
  original169, // 16:9 Widescreen (1920x1080 or 1280x720)
  vertical916, // 9:16 (1080x1920 or 720x1280)
  vertical45,  // 4:5 (1080x1350)
  square11,    // 1:1 (1080x1080)
}

extension AspectRatioOptionExt on AspectRatioOption {
  String get label {
    switch (this) {
      case AspectRatioOption.original169:
        return '16:9';
      case AspectRatioOption.vertical916:
        return '9:16';
      case AspectRatioOption.vertical45:
        return '4:5';
      case AspectRatioOption.square11:
        return '1:1';
    }
  }

  double get ratio {
    switch (this) {
      case AspectRatioOption.original169:
        return 16.0 / 9.0;
      case AspectRatioOption.vertical916:
        return 9.0 / 16.0;
      case AspectRatioOption.vertical45:
        return 4.0 / 5.0;
      case AspectRatioOption.square11:
        return 1.0;
    }
  }
}

enum SocialPlatformProfile {
  youtubeShorts,
  instagramReels,
  tiktok,
  genericVertical,
}

extension SocialPlatformProfileExt on SocialPlatformProfile {
  String get displayName {
    switch (this) {
      case SocialPlatformProfile.youtubeShorts:
        return 'YouTube Shorts';
      case SocialPlatformProfile.instagramReels:
        return 'Instagram Reels';
      case SocialPlatformProfile.tiktok:
        return 'TikTok';
      case SocialPlatformProfile.genericVertical:
        return 'Generic 9:16';
    }
  }
}
