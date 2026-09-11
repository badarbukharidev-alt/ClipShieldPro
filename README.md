# 🛡️ ClipShield Pro (v1.1.0)

> **AI-Powered On-Device YouTube Short Clipper, Widescreen Video Copyright Protection Engine & Audio DSP Studio**

[![Release APK](https://img.shields.io/badge/Download-Release%20APK%20v1.1.0-FF6A3D?style=for-the-badge&logo=android&logoColor=white)](https://media.githubusercontent.com/media/badarbukharidev-alt/ClipShieldPro/main/release/ClipShieldPro-v1.1.0.apk)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Engine](https://img.shields.io/badge/DSP%20Engine-100%25%20On--Device-7C5CFF?style=for-the-badge)](https://github.com/badarbukharidev-alt/ClipShieldPro)
[![License](https://img.shields.io/badge/License-Commercial%20Pro-12B56A?style=for-the-badge)](https://github.com/badarbukharidev-alt/ClipShieldPro)

---

## 🚀 Direct APK Download

Download the latest production release of **ClipShield Pro** directly for your Android device:

📥 **[Download ClipShieldPro-v1.1.0.apk (~305 MB)](https://media.githubusercontent.com/media/badarbukharidev-alt/ClipShieldPro/main/release/ClipShieldPro-v1.1.0.apk)**

> *Alternate Link:* [Download via GitHub Raw Stream](https://github.com/badarbukharidev-alt/ClipShieldPro/raw/main/release/ClipShieldPro-v1.1.0.apk)

---

## ✨ Overview & Core Features

ClipShield Pro is an advanced on-device video processing studio built for content creators, agency managers, and social media strategists. It features **three specialized primary execution modes**:

### 1. 🛡️ Long Video Copyright Remover (Primary Mode)
* **Widescreen Preservation (16:9)**: Materially transforms long-form videos while preserving original 16:9 widescreen canvas and high quality.
* **12-Layer DSP Perturbation Engine**:
  1. *Harmonic Audio Modulation* — Controlled pitch micro-shifts preserving speech tempo
  2. *Parametric 5-Band EQ* — Subtle frequency shaping across 80Hz-15kHz
  3. *Stereo Spatial Decorrelation* — Micro-phase delays for soundstage widening
  4. *Geometric Micro-Transformation* — Sub-pixel canvas trimming & edge offset
  5. *Codec Resampling & Re-profiling* — H.264 GOP restructuring
  6. *Color Processing & Grading* — Hue, saturation & contrast micro-shifts
  7. *Gamma / Mid-Tone Calibration* — Dynamic range & shadow detail tuning
  8. *Audio Conditioning & Dithering* — Inaudible spectral noise floor
  9. *Codec Normalization* — Ultra-fast multi-core hardware encoding
  10. *Gaussian Blur Defense* — Sub-pixel softening for pixel fingerprint disruption **NEW**
  11. *Background Ambient Layer* — Ultra-low volume ambient tone for audio signature shift **NEW**
  12. *Micro-Reverb Audio Defense* — Imperceptible reverb tail for waveform disruption **NEW**
* **Enhanced Color & Contrast Perturbation**: Wider hue shift range with contrast micro-adjustments
* **Zero Face Tracking Delay**: Ultra-fast multi-core hardware rendering bypasses tracking overhead.

### 2. ✂️ Long Video → Shorts (AI Clipping)
* **AI Highlight Detection**: Intelligently analyzes transcripts, hook density, and audio variance to extract viral clips automatically.
* **Automatic 9:16 Reframing**: Converts landscape video to vertical 9:16 Shorts with smart subject centering.
* **Facial Centroid Subject Tracking**: Dynamic target tracking keeps speakers in focus during vertical cuts.
* **Multi-AI Provider Integration**: Supports Google Gemini 1.5 Flash, OpenRouter (Gemini 2.0 / LLaMA 3.3), Groq, Cerebras, and built-in offline mathematical heuristics.

### 3. 🎵 Songs Remover (Audio DSP Studio) **NEW in v1.1.0**
* **Full Audio DSP Control Panel**: Real-time adjustable sliders for Volume, EQ, Tempo, Pitch, Stereo Panning, Compression, Reverb, Delay, Fade In/Out, and Loudness Normalization.
* **Multiple Output Modes**: Full Mix, Vocal Only, or Instrumental Only.
* **Cover Image Composition**: Upload a cover image, select aspect ratio (16:9 or 9:16), and export as a static video with processed audio.
* **Live 10s Preview**: Preview DSP-processed audio before rendering the final output.
* **Universal Input**: Supports YouTube URL, local video, or direct audio file upload.

---

## 🛠️ What's New in v1.1.0

- 🎵 **Songs Remover Module**: Complete audio DSP studio with 12 adjustable parameters, output mode selection, cover image picker, and video composition engine.
- 🔲 **Gaussian Blur Layer**: Subtle pixel-level blur for enhanced visual fingerprint disruption.
- 🎶 **Background Ambient Layer**: Auto-generated sine wave tones at ultra-low volume to shift audio fingerprints.
- 🔊 **Micro-Reverb Layer**: Imperceptible echo disrupting audio waveform matching.
- 🎨 **Enhanced Color Shifting**: Wider hue, saturation, and contrast micro-shifts for stronger copyright defense.
- 📋 **Instant One-Tap Clipboard Paste**: Dedicated paste icon button in YouTube URL input.
- 🖼️ **Real-Time YouTube Metadata Preview**: Thumbnail, title, author, and duration preview before processing.
- ⚡ **Ultra-Fast FFmpeg Pipeline**: Multi-core accelerated rendering.
- 📱 **Seamless Tab & Back Navigation**: PopScope integration for graceful tab switching.
- 🎨 **Unified Warm Light Palette**: Premium cream theme across all screens.
- 🔐 **Offline Cryptographic Licensing**: HMAC-SHA256 hardware-bound activation (CS-XXXX-XXXX-XXXX).

---

## 📞 Licensing & Support

ClipShield Pro uses a hardware-bound device activation system. For activation keys, inquiries, or enterprise licensing:

- 💬 **WhatsApp Support**: `+923079031153` (`03079031153`)
- 📄 **License Mode**: Commercial Pro & Trial Evaluation

---

## 💻 Tech Stack & Architecture

- **Framework**: Flutter 3.x (Dart 3.x)
- **Media Engine**: `ffmpeg_kit_flutter_new` (Custom high-speed native build)
- **Computer Vision**: `google_mlkit_face_detection`
- **YouTube Media Integration**: `youtube_explode_dart`
- **Security & Crypto**: `crypto` (HMAC-SHA256 engine)
- **Platform**: Android (Min SDK 21 / Android 5.0+, Target SDK 34 / Android 14)

---

## 🔨 Building from Source

```bash
# 1. Clone repository
git clone https://github.com/badarbukharidev-alt/ClipShieldPro.git
cd ClipShieldPro

# 2. Install dependencies
flutter pub get

# 3. Build Release APK
flutter build apk --release
```

Release APK output will be generated at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## ⚖️ Legal & Safe Usage Disclaimer

ClipShield Pro is an authorized content editing, dynamic reframing, and transformation utility suite. Content creators and users are solely responsible for ensuring they possess the necessary rights, licenses, or permissions for all media imported or processed.

---

*Developed by **Badar Bukhari** for ClipShield Studio.*
