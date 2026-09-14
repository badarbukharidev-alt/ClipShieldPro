# 🛡️ ClipShield Pro (v1.2.11)

> **AI-Powered On-Device YouTube Short Clipper, Widescreen Video Copyright Protection Engine & Audio DSP Studio**

[![Release APK](https://img.shields.io/badge/Download-Release%20APK%20v1.2.11-FF6A3D?style=for-the-badge&logo=android&logoColor=white)](https://media.githubusercontent.com/media/badarbukharidev-alt/ClipShieldPro/main/release/ClipShieldPro-v1.2.11.apk)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Engine](https://img.shields.io/badge/DSP%20Engine-100%25%20On--Device-7C5CFF?style=for-the-badge)](https://github.com/badarbukharidev-alt/ClipShieldPro)
[![Size](https://img.shields.io/badge/APK%20Size-176%20MB-12B56A?style=for-the-badge)](https://github.com/badarbukharidev-alt/ClipShieldPro)

---

## 🚀 Direct APK Download

Download the latest production release of **ClipShield Pro** directly for your Android device:

📥 **[Download ClipShieldPro-v1.2.11.apk (176 MB)](https://media.githubusercontent.com/media/badarbukharidev-alt/ClipShieldPro/main/release/ClipShieldPro-v1.2.11.apk)**

> *Alternate Direct Links:*
> - [Download via GitHub LFS Stream](https://media.githubusercontent.com/media/badarbukharidev-alt/ClipShieldPro/main/release/ClipShieldPro-v1.2.11.apk)
> - [Download via GitHub Raw Stream](https://github.com/badarbukharidev-alt/ClipShieldPro/raw/main/release/ClipShieldPro-v1.2.11.apk)

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

## 🛠️ What's New in v1.2.11

### 📲 In-app update prompts

The panel can now announce a release, and installed apps offer it on their next
API call — app start, or opening Free Videos. There is no separate update check:
the announcement rides along on traffic that already happens.

Set it under **Update** in the admin panel: version name, version code, APK link,
release notes, and whether it is mandatory. Run
`database/migrations/2026_09_15_app_update.sql` once to seed the keys — it seeds
them **off**, so nothing is announced until you fill the form in.

**The version code is the comparison key, not the name.** It is the `+N` build
number from `pubspec.yaml`, the same integer Android uses, so `1.2.11` vs `1.2.9`
never has to be parsed and a release can be renamed without confusing anything.

Three decisions worth stating outright:

- **The app never installs anything.** "Update now" opens the link in the browser
  and Android's installer takes over. Downloading and installing silently would
  need `REQUEST_INSTALL_PACKAGES`, and an app that can install packages on its own
  is one compromise of the panel away from being a delivery mechanism for
  something else. The extra tap is the point.
- **Plain-http links are ignored,** at both ends. An APK fetched over a connection
  anyone on the path can rewrite is worse than shipping no update at all, so a
  non-HTTPS link is treated as "no update" rather than shown with a button.
- **"Later" is remembered per version code,** so the next release asks again but
  this one does not. The release stays reachable under **Settings → version**,
  because a prompt you can dismiss forever and never find again is just a bug with
  good manners.

A withdrawal is explicit: unticking the box sends `update: null`, which clears the
cached announcement. A response that merely *omits* the field leaves it alone —
otherwise every unrelated API call would quietly withdraw a live release.

### 🐛 Fixed: a second `init()` read stale preferences

`UpdateService.init()` and `RemoteConfigService.load()` used `_prefs ??=`, so
re-initialising kept an instance captured earlier instead of re-reading the store.
Caught by a test where one case's skipped version leaked into the next.

---

## 🛠️ What's New in v1.2.10

### 🛡️ The copyright remover is one button again

Finishing a download used to drop you straight into twelve layer switches, an
intensity slider and two competing buttons. The preset had already configured all
of it, so the screen asked for decisions it had itself already made.

- Everything optional now sits behind **Advanced**, collapsed by default. The row
  still states what is active (`9 of 12 layers active at 50% intensity`), so
  hiding the detail does not hide the fact that work is happening.
- The action reads **Remove Copyright** and spans the full width.
- **The 5s preview is gone.** It re-encoded a five-second segment through the
  entire filtergraph purely to be thrown away — on a phone that costs roughly what
  rendering the same span for real does, and the result was never kept.

### 🎵 Plain names for the song tool

"Song DSP & Cover Export" and "Open Song DSP" told you the implementation, not the
job. It is now **Song Copyright Remover** with a **Remove Song Copyright** action,
and the tab reads **Song Copyright**.

### 🎁 The Free tab asks for attention

The Free destination keeps its own green when idle rather than being one more grey
tab, and beats twice every six seconds.

Driven by a timer rather than `repeat()`: a repeating `AnimationController`
schedules a frame every 16 ms for as long as the dashboard is on screen, which is
a genuine battery cost for an animation nobody watches most of the time. Between
beats the app is properly idle.

### ☎️ Support number is now panel-managed

The WhatsApp number was compiled into the app, so changing it meant shipping an
APK and waiting for everyone to update. It now lives under **Settings → Support
contact** in the admin panel and rides along on every API response, so installed
apps adopt it on their next sync.

No table changes were needed — the existing key/value `settings` table holds it —
but run `database/migrations/2026_09_14_support_contact.sql` to seed the keys with
the current number so nothing changes until you edit it.

> A phone that never reaches the server keeps the number it shipped with, and a
> response that omits the field leaves a working number alone: a partial reply must
> never blank out the only support contact on every install at once.

### 🖍️ Fixed: unreadable call-to-action

With no source picked, the dashboard button was white text on a light grey fill —
all but invisible, reading as broken rather than as waiting. Caught by rendering
the screen, not by reading the code.

---

## 🛠️ What's New in v1.2.9

### 🎁 Tasks now actually appear

Tasks created in the admin panel were never reaching the app: `TaskApiService.apiSecret` was still its placeholder, so the client treated itself as unconfigured and never called the API at all.

The secret is now **injected at build time** rather than committed, because **this repository is public** — a hardcoded secret here would be readable by anyone. Build with:

```bash
tools/build_release.sh
```

which reads it from the gitignored `android/api_secret.txt` and passes `--dart-define=CLIPSHIELD_API_SECRET=…`. The same value must be set as `API_SECRET` in the panel's `inc/config.php`. Build without it and the task system stays disabled rather than sending signatures that can never verify.

### 🧭 Free Videos in the footer

Tasks are now a first-class destination in the bottom navigation (Home · Projects · **Free** · Settings) instead of only being reachable from a dashboard card. The bar was rebuilt with `Expanded` items so a fourth destination cannot push it past the screen edge — the existing 360 dp overflow test caught that regression before it shipped.

### 🎨 Solid colours, no gloss

- **Action tabs are solid**: the active tab is a filled block of its own accent with white icon and label; the others are flat white with a coloured icon. No translucent fills, no coloured glow.
- Removed the **gradient and drop-shadow** from the render canvas, the radial wash behind the progress ring, the gradient on the Free Videos balance card, and the translucent fills on task icons and buttons.
- A disabled call-to-action is now a flat neutral rather than a faded tint of its accent.

### 📊 Install statistics in the admin panel

New **Stats** page: total installs, new today / this week / this month, active devices over 24 h / 7 d / 30 d, dormant devices, a 30-day daily chart, a 12-month chart, and the spread of app versions in the field. Charts are plain CSS with no charting dependency.

> Installs are counted from a device's first contact with the API, so the figure is a **floor, not an exact count** — a phone that never reaches the server is never counted, and uninstalls are not detectable at all. Because device IDs derive from `ANDROID_ID`, a reinstall reuses the same row rather than counting twice.

---

## 🛠️ What's New in v1.2.8

### 🔐 Proper release signing

Releases up to v1.2.7 were signed with the **debug keystore**, which is generated per machine. That made the app's signing certificate unstable — and since `Settings.Secure.ANDROID_ID` is scoped to the signing certificate, an unstable key meant device identities (and therefore every issued licence key) could break without warning.

- Release builds are now signed with a dedicated 4096-bit RSA keystore valid until **2054**.
- Credentials live in `android/key.properties`, which is gitignored along with `*.jks` — neither is in this repository.
- If the keystore is missing, the build falls back to debug signing rather than failing, so a fresh clone still compiles — but **release builds must be made on a machine that has it.**

> ### ⚠️ This release cannot be installed over an older one
>
> Android refuses to upgrade an app when the signing certificate changes. To move to v1.2.8 you must **uninstall the previous version first**, which clears app data.
>
> **Existing licence keys will stop working after that uninstall.** Device IDs are derived from the signing certificate, so every device gets a new ID. Reissue keys from the admin panel for anyone already activated — the Licences page has their records.
>
> This is a one-time break. Every release from v1.2.8 onward uses the same key and will upgrade in place normally.

---

## 🛠️ What's New in v1.2.7

**Task rewards, animated captions, hardware encoding, and a background fix that actually works.**

### 🎁 Free videos from tasks
- Complete tasks (follow Instagram, join the WhatsApp channel, subscribe on YouTube) to earn free render credits, managed from the [ClipShield Admin](https://github.com/badarbukharidev-alt/ClipShield-Admin) panel.
- **Credits survive a wipe.** Device identity is now derived from `Settings.Secure.ANDROID_ID`, which persists through clearing app data and through uninstall/reinstall. The claim ledger lives on the server, so wiping the app resets nothing.
- **Existing installs keep their old device ID.** Licence keys are HMACs over that ID, so re-deriving it would have invalidated every key already sold. Only fresh installs get the new derivation.
- Request signing is pinned to the PHP backend by known-good vectors in `test/task_api_signing_test.dart`, and licence-key generation by `test/license_crossport_test.dart`. If either side drifts, the tests fail rather than the users.

### 💬 Animated captions
- Burn in captions from the source video's own caption track, with eight styles: **Bold Impact**, **Mega Pop**, **Word Pop**, **Karaoke Fill**, **Typewriter**, **Slide Up**, **Classic Box** and **Clean**.
- Animations are real ASS/libass effects — karaoke fill (`\kf`), scale-overshoot pops (`\t`), fades and slides — not static text.
- Captions are re-timed onto each clip's own timeline and chunked into short bursts, so they read as captions rather than subtitles.
- Burned in **after** every other video filter, so the blur and colour layers cannot soften or tint the text.
- A caption failure can never take a render down with it; the clip renders without them.

### ⚡ Long videos
- Clips over **10 minutes** now request the device's **hardware H.264 encoder** (`h264_mediacodec`) instead of software x264, which is several times faster on a phone. Bitrate scales with the output canvas. If a device rejects it, the existing resilient path re-encodes with x264 automatically.

### 🔋 Background rendering
- v1.2.6 added a foreground service, but that alone is not enough on the OEM skins most users are on. **Xiaomi, Oppo, Vivo and Samsung kill background work regardless** unless the app is exempt from battery optimisation — the real reason long renders were dying on minimise.
- The app now asks for that exemption before the first long render, and the notification channel importance was raised so the service is not deprioritised.

### 🎨 Interface
- **Action tabs are no longer muted** — unselected tabs keep their own colour instead of going flat grey, and the selected tab gets a tinted fill with a matching glow.
- **The app icon now sits beside the ClipShield Studio wordmark.**
- **Shorts render at a tighter CRF.** Vertical output fills a phone screen where compression artefacts read far more harshly than on a 16:9 card, so it now gets CRF 18–19 at high quality instead of 20–21.
- The licence pill in Settings is larger and no longer squeezed on narrow screens.

- ✅ **Tests**: adds `test/ass_builder_test.dart` (25 tests — ASS colour byte order, timestamps, clip re-timing, chunking, every preset), `test/task_api_signing_test.dart` and `test/license_crossport_test.dart`. Suite is **108/108** green, and every caption preset was rendered through libass and inspected frame by frame.

---

## 🛠️ What's New in v1.2.6

**Renders now survive the app being closed, and source metadata is on the results screen itself.**

- 🔋 **Jobs keep running when the app is closed**:
  - Rendering happens on the main isolate, so Android was free to kill the process the moment the app left the screen — silently abandoning a half-finished render.
  - A foreground service is now held for exactly as long as the render queue is busy, started when the queue goes from idle to busy and released when it drains. This covers **all three job types**: Copyright, AI Shorts and Song DSP, since they share one queue.
  - The service is held across the whole drain rather than per job, so the process is never released between two queued renders.
  - `android:stopWithTask="false"` keeps the service alive when the task is swiped away from recents, and `POST_NOTIFICATIONS` was added for the Android 13+ progress notification.
  - The notification shows the live project title, percentage, current stage and how many jobs are still queued. Repeated identical text is skipped so it is not rewritten on every FFmpeg statistics callback.
  - A denied notification permission never fails the render — the service falls back silently rather than taking the job down with it.
- 📋 **Source metadata is shown inline on the "video ready" screen**:
  - Previously it sat behind a disclosure button and only appeared for long-form sources, which is why it looked like it was missing entirely.
  - The title, description, tags and thumbnail now render directly on the results screen alongside the sharing options, for **any** YouTube source.
  - The results screen was restructured to scroll as one page (the clip list now sizes to its content) so the panel has somewhere to live.
- 🔗 **Metadata can no longer be lost to a race**: hitting Start before the debounced link lookup finished used to attach no metadata to the project at all. Start now waits for the lookup to complete first.
- 🎚️ **Balanced is the default processing preset**, matching the reference design.

- ✅ **Tests**: adds `test/results_metadata_test.dart` verifying the metadata panel renders inline on a genuinely-ready project, is absent when a project has none, and is no longer hidden behind a button — plus a default-preset assertion. Suite is **64/64** green.

---

## 🛠️ What's New in v1.2.5

**Link previews, colour-coded actions, correct 16:9 handling, and source metadata export.**

- 🎨 **Per-action colour identity**: each mode now carries its own accent instead of one orange wall — Copyright is tangerine, AI Shorts is grape, Song DSP is lime. The accent drives the segment, the input highlights, the badge, the card border and the call-to-action, so the active tool is obvious at a glance.
- 🔗 **Link preview on paste**: pasting a YouTube or Shorts URL now fetches and shows the **thumbnail, title, channel and duration** before anything downloads, so you can confirm the right video was resolved. The lookup is debounced and cancels cleanly if you paste something else mid-flight.
- 📺 **Proper source acquisition screen**: the bare spinner shown while a stream downloads is replaced with a real view — source thumbnail and title, a determinate progress ring driven by actual download bytes, and a four-stage checklist (manifest → video track → audio track → mux & probe).
- 📐 **16:9 is treated as 16:9 everywhere**:
  - Projects History and the Home recent card now render a **landscape tile** for widescreen projects instead of cropping them into a 9:16 Shorts tile.
  - The preview player used to frame every clip inside a fixed portrait viewport, so a 16:9 export appeared letterboxed inside a Shorts window. The canvas is now sized to the clip's real aspect ratio.
  - Aspect logic is centralised on `ProjectItem.isWidescreen` / `displayAspectRatio` rather than being re-derived in three screens.
- 📋 **Source metadata panel** for long-form sources (anything past three minutes), reachable from the results screen:
  - **Download Full HD Thumbnail** — pulls YouTube's max-resolution thumbnail.
  - **Copy title**, **copy description**, and **copy keywords as a comma-separated list** ready to paste straight into the tags box.
  - Keyword chips with a full count, and **Save all metadata as .txt**.
  - Metadata is captured when the link is pasted and persisted with the project, so it stays available long after the render.
- 📁 **ClipShield folders**: saves are routed to `Movies/ClipShield` (video), `Pictures/ClipShield` (thumbnails) and `Documents/ClipShield` (text), each followed by a MediaScanner broadcast so they surface in Gallery and Files. Every save reports the actual path it landed on, and falls back to app storage rather than failing silently.
- ⚙️ **Settings**: the license pill is larger and more legible, and the label column now yields space so the pill no longer gets squeezed on narrow screens.

- ✅ **Tests**: adds `test/metadata_aspect_test.dart` (aspect classification, keyword CSV, long-form threshold, duration formatting, settings round-trip). Suite is **59/59** green.

---

## 🛠️ What's New in v1.2.4

**One-step dashboard.** Creating a project no longer goes through a bottom-sheet modal — paste a link, pick an action, and start, all from the home screen.

- ⚡ **Fast Input card**:
  - YouTube / Shorts URL field with an inline **Paste** button that reads the clipboard directly.
  - Local video or audio picker beneath an OR divider, showing the chosen filename with a one-tap clear.
  - Source selection is exclusive — typing a link clears a picked file and vice versa — so the card always reflects exactly one input.
- 🎛️ **Choose Action segmented control**:
  - Copyright · AI Shorts · Song DSP in a single tab strip, with the active mode echoed in the section header.
  - Switching a segment swaps the entire action card: badge, title, description and call-to-action.
- ⚙️ **Processing Preset is wired through**:
  - `TransformPipelineScreen` now accepts an `initialPreset` and applies it in `initState`, so the Fast / Balanced / Deep choice made on the dashboard is honoured instead of being asked again on the next screen.
  - The preset row is shown **only** for Copyright mode, where it is actually plumbed through — no dead controls.
- 📡 **Live background render banner** on the dashboard, driven by `RenderJobService.activeJob`: percentage, progress bar, exporting filename and clip counter. Tapping it opens that job's status page.
- 🧭 **Simplified navigation**: Home / Projects / Settings. The centre "+" button and the non-functional "Shorts Templates" carousel (three cards that navigated nowhere) were removed.

### Layout defects found by rendering the screen

The dashboard was rendered to an image during development rather than assumed correct, which surfaced two bugs that structural tests alone would have missed:

- 🔀 **Action segments were in the wrong order.** `AppMode` declares `longVideoToShorts` first, so iterating `AppMode.values` placed **AI Shorts** in the leading slot instead of Copyright. Segment order is now an explicit list, pinned by a test.
- 📐 **Four `RenderFlex` overflows** — the preset row (47 px), both section header rows, and the identity / Recent Projects rows. At 360 dp (Pixel and Galaxy S base width) these would have painted visible yellow-and-black hazard stripes. Every unbounded `Text` in a `spaceBetween` row is now `Flexible` with ellipsis, and the preset chips sit in a right-pinned scroll strip that survives any width.

- ✅ **Tests**: `test/dashboard_layout_test.dart` asserts zero overflow at 360 / 411 / 480 dp across all three action cards, plus segment order and preset-chip reachability. `test/widget_test.dart` rewritten to cover the new dashboard: input card, mode switching, preset visibility, and source validation before navigation. Suite is **51/51** green.

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