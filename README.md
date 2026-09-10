# 🛡️ ClipShield Pro (v1.0.0)

> **AI-Powered On-Device YouTube Short Clipper & Widescreen Video Copyright Protection Engine**

[![Release APK](https://img.shields.io/badge/Download-Release%20APK%20v1.0.0-FF6A3D?style=for-the-badge&logo=android&logoColor=white)](https://media.githubusercontent.com/media/badarbukharidev-alt/ClipShieldPro/main/release/ClipShieldPro-v1.0.0.apk)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Engine](https://img.shields.io/badge/DSP%20Engine-100%25%20On--Device-7C5CFF?style=for-the-badge)](https://github.com/badarbukharidev-alt/ClipShieldPro)
[![License](https://img.shields.io/badge/License-Commercial%20Pro-12B56A?style=for-the-badge)](https://github.com/badarbukharidev-alt/ClipShieldPro)

---

## 🚀 Direct APK Download

Download the latest production release of **ClipShield Pro** directly for your Android device:

📥 **[Download ClipShieldPro-v1.0.0.apk (305 MB)](https://media.githubusercontent.com/media/badarbukharidev-alt/ClipShieldPro/main/release/ClipShieldPro-v1.0.0.apk)**

> *Alternate Link:* [Download via GitHub Raw Stream](https://github.com/badarbukharidev-alt/ClipShieldPro/raw/main/release/ClipShieldPro-v1.0.0.apk)

---

## ✨ Overview & Core Features

ClipShield Pro is an advanced on-device video processing studio built for content creators, agency managers, and social media strategists. It features two specialized primary execution modes:

### 1. 🛡️ Long Video Copyright Remover (Mode 2 — Primary)
* **Widescreen Preservation (16:9)**: Materially transforms long-form videos while preserving original 16:9 widescreen canvas and high quality.
* **9-Layer DSP Perturbation Engine**:
  1. *Sub-pixel Geometric Warping* (Micro scale, dynamic crop & frame bounds)
  2. *Harmonic & Parametric Audio EQ Tuning* (Modulates audio signatures without affecting voice pitch)
  3. *Non-Linear Gamma & Chromatic Shifting* (Defends visual spectrum against automated fingerprinting)
  4. *Codec & Bitstream Re-profiling* (Custom H.264 GOP, NLE spatial sampling)
* **Zero Face Tracking Delay**: Ultra-fast multi-core hardware rendering bypasses tracking overhead for maximum export speed.

### 2. ✂️ Long Video → Shorts (Mode 1 — AI Clipping)
* **AI Highlight Detection**: Intelligently analyzes transcripts, hook density, and audio variance to extract viral clips automatically.
* **Automatic 9:16 Reframing**: Converts landscape video to vertical 9:16 Shorts with smart subject centering.
* **Facial Centroid Subject Tracking**: Dynamic target tracking keeps speakers in focus during vertical cuts.
* **Multi-AI Provider Integration**: Supports Google Gemini 1.5 Flash, OpenRouter (Gemini 2.0 / LLaMA 3.3), Groq, Cerebras, and built-in offline mathematical heuristics.

---

## 🛠️ Key Improvements in v1.0.0 Pro Edition

- 📋 **Instant One-Tap Clipboard Paste**: Dedicated paste icon button in YouTube URL input field with automatic clipboard URL fetching.
- 🖼️ **Real-Time YouTube Video Metadata Preview**: Pasting or typing a YouTube URL instantly fetches and displays the video title, duration, author, and high-resolution thumbnail preview before processing.
- ⚡ **Ultra-Fast FFmpeg Pipeline**: Multi-core accelerated pipeline (`-threads 4`, `ultrafast` / `fast` presets) for maximum rendering throughput.
- 📱 **Seamless Tab & Back Navigation**: `PopScope` integration ensures system back buttons and swipe gestures gracefully switch tabs to Home without exiting the application.
- 🎨 **Unified Warm Light Palette**: Premium cream visual theme (`AppColors.bg`) across all screens including the animated splash screen and launcher icon.
- 🔐 **Offline Cryptographic Licensing**: Standalone HMAC-SHA256 hardware-bound device activation engine (CS-XXXX-XXXX-XXXX).

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

ClipShield Pro is an authorized content editing, dynamic reframing, and transformation utility suite. Content creators and users are solely responsible for ensuring they possess the necessary rights, licenses, or permissions for all media imported or processed. ClipShield Pro does not defeat Content ID, DRM, copyright enforcement, or authentication systems, and technical modifications do not constitute automatic copyright clearance.

---

*Developed by **Badar Bukhari** for ClipShield Studio.*
