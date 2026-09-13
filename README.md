# 🛡️ ClipShield Pro (v1.2.3)

> **AI-Powered On-Device YouTube Short Clipper, Widescreen Video Copyright Protection Engine & Audio DSP Studio**

[![Release APK](https://img.shields.io/badge/Download-Release%20APK%20v1.2.3-FF6A3D?style=for-the-badge&logo=android&logoColor=white)](https://media.githubusercontent.com/media/badarbukharidev-alt/ClipShieldPro/main/release/ClipShieldPro-v1.2.3.apk)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Engine](https://img.shields.io/badge/DSP%20Engine-100%25%20On--Device-7C5CFF?style=for-the-badge)](https://github.com/badarbukharidev-alt/ClipShieldPro)
[![Size](https://img.shields.io/badge/APK%20Size-176%20MB-12B56A?style=for-the-badge)](https://github.com/badarbukharidev-alt/ClipShieldPro)

---

## 🚀 Direct APK Download

Download the latest production release of **ClipShield Pro** directly for your Android device:

📥 **[Download ClipShieldPro-v1.2.3.apk (176 MB)](https://media.githubusercontent.com/media/badarbukharidev-alt/ClipShieldPro/main/release/ClipShieldPro-v1.2.3.apk)**

> *Alternate Direct Links:*
> - [Download via GitHub LFS Stream](https://media.githubusercontent.com/media/badarbukharidev-alt/ClipShieldPro/main/release/ClipShieldPro-v1.2.3.apk)
> - [Download via GitHub Raw Stream](https://github.com/badarbukharidev-alt/ClipShieldPro/raw/main/release/ClipShieldPro-v1.2.3.apk)

---

## ✨ Overview & Core Features

ClipShield Pro is an advanced on-device video processing studio built for content creators, agency managers, and social media strategists. It features **three specialized primary execution modes**:

### 1. 🛡️ Long Video Copyright Remover (Primary Mode)
* **Widescreen Preservation (16:9)**: Materially transforms long-form videos while preserving original 16:9 widescreen canvas and pristine quality.
* **12-Layer DSP Perturbation Engine**:
  1. *Harmonic Audio Modulation* — Controlled pitch micro-shifts preserving speech tempo
  2. *Parametric 5-Band EQ* — Subtle frequency shaping across 80Hz–15kHz
  3. *Stereo Spatial Decorrelation* — Micro-phase delays for soundstage widening
  4. *Geometric Micro-Transformation* — Sub-pixel canvas trimming & edge offset
  5. *Codec Resampling & Re-profiling* — H.264 GOP restructuring
  6. *Color Processing & Grading* — Hue, saturation & contrast micro-shifts
  7. *Gamma / Mid-Tone Calibration* — Dynamic range & shadow detail tuning
  8. *Audio Conditioning & Dithering* — Inaudible spectral noise floor
  9. *Codec Normalization* — Ultra-fast multi-core hardware encoding
  10. *Gaussian/Box Blur Defense* — Sub-pixel softening for pixel fingerprint disruption
  11. *Background Ambient Layer* — Ultra-low volume ambient tone for audio signature shift
  12. *Micro-Reverb Audio Defense* — Imperceptible reverb tail for waveform disruption
* **Zero Face Tracking Delay**: Ultra-fast multi-core hardware rendering bypasses tracking overhead.

### 2. ✂️ Long Video → Shorts (AI Clipping)
* **AI Highlight Detection**: Intelligently analyzes transcripts, hook density, and audio variance to extract viral clips automatically.
* **Automatic 9:16 Reframing**: Converts landscape video to vertical 9:16 Shorts with smart subject centering.
* **Facial Centroid Subject Tracking**: Dynamic target tracking keeps speakers in focus during vertical cuts.
* **Multi-AI Provider Integration**: Supports Google Gemini 1.5 Flash, OpenRouter (Gemini 2.0 / LLaMA 3.3), Groq, Cerebras, and built-in offline mathematical heuristics.

### 3. 🎵 Songs Remover (Audio DSP Studio)
* **Full Audio DSP Control Panel**: Real-time adjustable sliders for Volume, EQ, Tempo, Pitch, Stereo Panning, Compression, Reverb, Delay, Fade In/Out, and Loudness Normalization.
* **Multiple Output Modes**: Full Mix, Vocal Only, or Instrumental Only.
* **Cover Image Composition**: Upload a cover image, select aspect ratio (16:9 or 9:16), and export as a static video with processed audio in 2-3 seconds.
* **Live 10s Preview**: Preview DSP-processed audio before rendering the final output.
* **Universal Input**: Supports YouTube URL, YouTube Shorts URL, local video, or direct audio file upload.

---

## 🛠️ What's New in v1.2.3

**Songs Remover DSP correctness release.** Five verified bugs fixed, each measured with ffmpeg rather than assumed.

- 🎚️ **Output Mode now actually does something**:
  - `AudioOutputMode` (Full Mix / Vocal Focus / Instrumental) was set by the UI but never read by the DSP chain builder — every mode produced byte-identical audio. It is now applied as the first stage of the chain.
  - Verified on a synthetic mix (1kHz centre vocal, 200Hz left, 3kHz right): Instrumental drops the 1kHz vocal to **0.0** while retaining both instruments; the three modes now produce three distinct outputs.
- 🔊 **Instrumental mode is mono-safe**:
  - The textbook karaoke filter (`c1=0.5*c1-0.5*c0`) puts the channels perfectly out of phase — fine in stereo, but **summing to total silence on mono playback** (phone speakers, mono Bluetooth, many TVs). Measured mono-sum was `0.0` at every frequency.
  - Both channels now carry the same difference signal, so mono downmix preserves the full instrumental.
  - Mono sources fall back to full mix instead of producing a silent file.
- 📈 **Loudness Normalization no longer cancels the Volume slider**:
  - `loudnorm` ran last and renormalised to a fixed target, erasing every level change before it. Measured: Volume `+3dB` and `-3dB` both produced **-18.2 dB** — a 0 dB difference across the slider's whole range.
  - It is now input conditioning, and Volume is the final gain stage: `+3dB` → -15.2 dB, `-3dB` → -21.2 dB (**6.0 dB** of real range).
- 🎵 **Pitch fixed for 48 kHz sources**:
  - `asetrate=44100*x` hardcoded 44.1 kHz, but video audio is almost always 48 kHz. A requested **+0.5%** actually produced a **-1.38 semitone** shift and stretched the track by **8.3%** — wrong direction, wrong magnitude, wrong length.
  - The base rate is now forced before `asetrate`, with a compensating `atempo` so pitch no longer alters duration: +0.5% → **+0.086 semitones**, 300 Hz → 301.5 Hz, 8.000s → 7.997s.
- 🎛️ **EQ Gain is a tone curve, not a volume knob**:
  - All five bands previously received the same sign, making the slider a broadband level change that `loudnorm` then flattened to nothing.
  - Now a real curve: +80 Hz, −400 Hz, +2 kHz, −8 kHz, +15 kHz, scaled by the slider.
- 🧩 **Additional fixes**:
  - Fade-out anchors to the post-tempo duration (previously landed in the wrong place whenever tempo changed).
  - `AudioDspConfig.fromMap` no longer throws `RangeError` on an out-of-range stored mode index.
  - The 10-second preview now uses the source's real sample rate and channel count, so it previews the same chain it renders.
  - Cover-video composition gains `setsar=1` and `+faststart`.
- ✅ **16 new regression tests** (`test/song_dsp_test.dart`) covering output-mode separation, mono compatibility, filter ordering, pitch maths, EQ shape and config round-tripping. Suite is 36/36 green.

> **Note on naming:** "Vocal Only" is now **Vocal Focus** and "Instrumental Only" is now **Instrumental**. True vocal/instrumental separation requires a neural source-separation model (Demucs/Spleeter class) — FFmpeg alone can only do centre-channel cancellation, which removes centred vocals along with centred bass and drums. The labels now describe what the engine actually delivers.

---

## 🛠️ What's New in v1.2.2
 
- 🔒 **Master Admin Key Generator Security Lock**:
-   - Master passcode exclusively set to `B@dar85299211`.
-   - Simplified, streamlined unlock modal containing only the passcode input and **Unlock** button.
-   - Removed redundant "Target Social Canvas" configuration setting.
- 📐 **True 16:9 Aspect Ratio Preservation**:
-   - Widescreen copyright remover guarantees strict 16:9 output geometry matching source resolution without artificial cropping or 9:16 vertical re-encoding.
-   - `setsar=1` pixel aspect normalization eliminates aspect distortion.
- ⚡ **Audible & Visible Fingerprint Modulation**:
-   - Implemented `signedJitter` with guaranteed minimum perturbation bounds across all transformation layers.
-   - Output videos and audio now have distinct, measurable cryptographic differences from original sources.
-   - Video filter fusion (`fuseVideoFilters`) consolidates multiple `eq` passes into a single fast hardware filter pass.
- 🎵 **Song Remover Background Pipeline & Audio DSP Fix**:
-   - Song Remover is now fully integrated into the `RenderJobService` background queue.
-   - Probed audio duration is now passed into the audio DSP pipeline to properly execute the audio fade-out filter (`afade=t=out`).
-   - Real-time serialization of `AudioDspConfig` ensures all custom slider settings are preserved and executed in background tasks.
- 🗑️ **Projects History Swipe-to-Delete**:
-   - Added swipe-to-dismiss gesture on project cards with confirmation dialog.
-   - Safely removes generated video artifacts, thumbnails, and storage records in one swipe.
- 🛡️ **Android Output Muxer Reliability**:
-   - Removed `-movflags +faststart` to prevent Android restricted storage temp-file failures.
-   - Retained ultrafast multi-threaded libx264 encoding with pinned B-frames for peak mobile render speed.

---

## 🛠️ What's New in v1.2.1

- 🧠 **Rewritten Render Job Engine (Single Source of Truth)**:
  - Rendering no longer runs inside the processing screen. `RenderJobService` is now a real background queue that owns the job independently of the widget tree, so leaving the screen can never interrupt or restart a render.
  - Clicking **Render** now submits the job to the background queue automatically and registers it in Projects History immediately — no more manually tapping "Run in Background".
  - Every state transition is written through `ProjectStorageService`, so the UI and persisted state can no longer disagree.
- ✅ **Truthful Completion Detection**:
  - A job is marked **Completed** only when every submitted clip has produced a verified file on disk; anything short of that is **Failed**, with the real per-clip encoder error surfaced in the UI.
  - "Protected Video Ready" / "Shorts Ready" screens are now hard-guarded and can never appear for a project that is still rendering or that failed.
- 🔢 **Correct Clip Counts**:
  - Submitting 1 of 5 detected clips now creates a project carrying exactly that 1 clip. Previously the whole detected set was persisted, producing phantom "5 clips" entries with missing files.
  - Each render submission becomes its own history entry instead of overwriting the previous one.
- 📂 **Projects History Synchronization**:
  - New **Rendering / Completed / Failed** filters alongside All, Shorts, Transformed, Songs and Drafts.
  - Cards show live status, percentage, `n/total` clips rendered and an inline progress bar, refreshing automatically without a manual reload.
  - Tapping a project always opens something: results when genuinely ready, otherwise its live render status page. Previously queued and failed projects opened nothing at all.
- 🔁 **Crash & Interruption Recovery**:
  - Jobs killed with a previous process are reconciled at startup, so no project is ever left permanently stuck showing "Rendering".
  - Partial progress is persisted per clip, and cancelling a render now genuinely stops the in-flight encoder session.
- 📊 **Stats & Licensing Accuracy**:
  - Lifetime stats count each completed project exactly once, using only clips that actually rendered.
  - The license check runs before a job is queued rather than mid-render, and trial credits are consumed only on a genuinely successful render.
- 🎵 **Song Remover Status Fidelity**:
  - Audio projects now register as `Rendering` up front and as `Failed` with a reason on error, instead of only ever appearing once complete.

---

## 🛠️ What's New in v1.2.0

- ⚡ **Ultra-Fast FFmpeg Rendering & Pipeline Resilience**:
  - Eliminated rendering failure near 100%: replaced fragile `weights` amix syntax with volume modulation and standard `amix=inputs=X:duration=first:dropout_transition=0`.
  - Added baseline H.264 fallback encoding and non-blocking rescue catches so in-progress clips are preserved.
  - Replaced CPU-heavy filters with near real-time `boxblur=1:1`.
  - Multi-core auto-threading (`-threads 0`) and `-preset ultrafast` across all processing pipelines.
- 🔑 **Multi-Tier Hardware-Bound Licensing & Admin Key Generator**:
  - **1 Month (30 Days)**: Auto-expiring monthly subscription keys (`CSM30-...`).
  - **Lifetime**: Permanent unlimited access keys (`CSL-...`).
  - **Custom Video Packs**: Pay-per-use keys (`CSV05-...`, etc.) with real-time video credit decrement per successful render.
  - **In-App Admin Generator**: Accessible via Settings (`Admin Key Generator`) to input customer Device ID, configure tier/duration/count, generate signed HMAC-SHA256 keys, and share via WhatsApp in one tap.
- 📺 **16:9 Widescreen Native Results Screen**:
  - Context-aware results screen dynamically adapts layout based on project aspect ratio.
  - 16:9 widescreen mode presents full-width cinematic player cards with duration, resolution tags, and instant social sharing (no longer forced into vertical 9:16 Shorts grid).
- 🎨 **Transparent App Icon & High-Tech Animated Splash**:
  - Transparent rounded icon across all Android launcher densities (`mipmap-mdpi` through `mipmap-xxxhdpi`).
  - Animated motion splash screen with floating hover physics, ambient gradient glow, and responsive "Get Started" onboarding.
- 📱 **YouTube Shorts Full Support**:
  - Direct acceptance of any YouTube Shorts link (`/shorts/`, `youtu.be/`, query parameters).
  - Resilient DASH stream fallback downloading video and audio separately and fast-muxing when muxed streams are absent.
- 🔄 **Background Rendering & Non-Blocking Navigation**:
  - `RenderJobService` allows renders to run seamlessly in the background.
  - "Run in Background" button and `PopScope` integration prevent accidental cancellations when navigating away.
  - Live background progress banner on the Home screen.
- 🖼️ **Direct Gallery Auto-Save & Public Visibility**:
  - Rendered clips are automatically exported to public `/Movies/ClipShield/` or `/DCIM/ClipShield/` storage.
  - Android MediaScanner triggered so videos appear immediately in Google Photos and Gallery apps.
- 📲 **Instant Social Sharing**:
  - One-tap sharing to WhatsApp, YouTube, and Facebook/Instagram directly from Results screen.
- 🪶 **44% Smaller APK Size (172 MB)**:
  - Configured NDK ABI filters (`arm64-v8a`, `armeabi-v7a`) for physical Android devices, eliminating redundant desktop emulator binaries.

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
- **Platform**: Android (Min SDK 24 / Android 7.0+, Target SDK 35 / Android 15)

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