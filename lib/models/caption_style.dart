import 'package:flutter/material.dart';

/// How a caption animates onto the screen.
enum CaptionAnimation {
  /// No motion — the line simply appears.
  none,

  /// The active word is highlighted in the accent colour as it is spoken.
  wordHighlight,

  /// The whole line pops in with a scale overshoot.
  popIn,

  /// The active word scales up as it is spoken.
  wordPop,

  /// Words reveal one at a time, left to right.
  typewriter,

  /// The line slides up into place while fading in.
  slideUp,
}

/// A burned-in caption look.
///
/// Values map onto ASS (Advanced SubStation Alpha) styling, which libass
/// renders. Colours are stored as Flutter [Color]s and converted to ASS's
/// `&HAABBGGRR` byte order at build time.
class CaptionStylePreset {
  final String id;
  final String name;
  final String description;

  final String fontName;
  final int fontSize;
  final bool bold;
  final bool allCaps;

  final Color primaryColor;

  /// Colour of the word currently being spoken, for the highlight animations.
  final Color highlightColor;

  final Color outlineColor;
  final double outlineWidth;
  final double shadowDepth;

  /// Opaque box behind the text instead of an outline.
  final bool useBox;

  /// 0-100 from the bottom of the frame.
  final int verticalMarginPercent;

  final CaptionAnimation animation;

  /// Words per on-screen line. Short bursts are what make these styles read as
  /// captions rather than subtitles.
  final int maxWordsPerLine;

  const CaptionStylePreset({
    required this.id,
    required this.name,
    required this.description,
    this.fontName = 'Arial',
    this.fontSize = 56,
    this.bold = true,
    this.allCaps = false,
    this.primaryColor = Colors.white,
    this.highlightColor = const Color(0xFFFFE500),
    this.outlineColor = Colors.black,
    this.outlineWidth = 4,
    this.shadowDepth = 1,
    this.useBox = false,
    this.verticalMarginPercent = 18,
    this.animation = CaptionAnimation.wordHighlight,
    this.maxWordsPerLine = 4,
  });

  /// Preview swatch for the picker.
  Color get swatch => animation == CaptionAnimation.none ? primaryColor : highlightColor;
}

/// The bundled looks, ordered roughly by how commonly they are used.
class CaptionPresets {
  const CaptionPresets._();

  static const CaptionStylePreset hormozi = CaptionStylePreset(
    id: 'hormozi',
    name: 'Bold Impact',
    description: 'Big all-caps with a yellow highlight on the spoken word',
    fontSize: 62,
    allCaps: true,
    primaryColor: Colors.white,
    highlightColor: Color(0xFFFFE500),
    outlineWidth: 5,
    shadowDepth: 2,
    animation: CaptionAnimation.wordHighlight,
    maxWordsPerLine: 3,
  );

  static const CaptionStylePreset beast = CaptionStylePreset(
    id: 'beast',
    name: 'Mega Pop',
    description: 'Huge stroked text that pops in line by line',
    fontSize: 70,
    allCaps: true,
    primaryColor: Colors.white,
    highlightColor: Color(0xFF00E5FF),
    outlineWidth: 6,
    shadowDepth: 3,
    animation: CaptionAnimation.popIn,
    maxWordsPerLine: 3,
  );

  static const CaptionStylePreset tiktok = CaptionStylePreset(
    id: 'tiktok',
    name: 'Classic Box',
    description: 'White text on a solid block, centred low',
    fontSize: 48,
    primaryColor: Colors.white,
    highlightColor: Colors.white,
    outlineColor: Colors.black,
    outlineWidth: 0,
    shadowDepth: 0,
    useBox: true,
    verticalMarginPercent: 14,
    animation: CaptionAnimation.none,
    maxWordsPerLine: 5,
  );

  static const CaptionStylePreset karaoke = CaptionStylePreset(
    id: 'karaoke',
    name: 'Karaoke Fill',
    description: 'Each word fills with colour exactly as it is said',
    fontSize: 54,
    primaryColor: Color(0xFFEFEFEF),
    highlightColor: Color(0xFFFF6A3D),
    outlineWidth: 4,
    animation: CaptionAnimation.wordHighlight,
    maxWordsPerLine: 4,
  );

  static const CaptionStylePreset wordPop = CaptionStylePreset(
    id: 'word_pop',
    name: 'Word Pop',
    description: 'The spoken word scales up as it lands',
    fontSize: 58,
    allCaps: true,
    primaryColor: Colors.white,
    highlightColor: Color(0xFF12B56A),
    outlineWidth: 5,
    shadowDepth: 2,
    animation: CaptionAnimation.wordPop,
    maxWordsPerLine: 3,
  );

  static const CaptionStylePreset typewriter = CaptionStylePreset(
    id: 'typewriter',
    name: 'Typewriter',
    description: 'Words appear one at a time',
    fontSize: 52,
    primaryColor: Colors.white,
    highlightColor: Colors.white,
    outlineWidth: 4,
    animation: CaptionAnimation.typewriter,
    maxWordsPerLine: 4,
  );

  static const CaptionStylePreset slide = CaptionStylePreset(
    id: 'slide',
    name: 'Slide Up',
    description: 'Lines rise into place with a fade',
    fontSize: 54,
    primaryColor: Colors.white,
    highlightColor: Color(0xFF7C5CFF),
    outlineWidth: 4,
    animation: CaptionAnimation.slideUp,
    maxWordsPerLine: 4,
  );

  static const CaptionStylePreset minimal = CaptionStylePreset(
    id: 'minimal',
    name: 'Clean',
    description: 'Understated white text with a soft shadow',
    fontSize: 46,
    bold: false,
    primaryColor: Colors.white,
    highlightColor: Colors.white,
    outlineWidth: 2,
    shadowDepth: 2,
    animation: CaptionAnimation.none,
    maxWordsPerLine: 6,
  );

  static const List<CaptionStylePreset> all = [
    hormozi,
    beast,
    wordPop,
    karaoke,
    typewriter,
    slide,
    tiktok,
    minimal,
  ];

  static CaptionStylePreset byId(String id) {
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return hormozi;
  }
}
