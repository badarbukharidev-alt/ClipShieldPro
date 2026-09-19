# 🛡️ ClipShield Pro (v1.2.19)

> **AI-Powered On-Device YouTube Short Clipper, Widescreen Video Copyright Protection Engine & Audio DSP Studio**

[![Release APK](https://img.shields.io/badge/Download-Release%20APK%20v1.2.19-FF6A3D?style=for-the-badge&logo=android&logoColor=white)](https://media.githubusercontent.com/media/badarbukharidev-alt/ClipShieldPro/main/release/ClipShieldPro-v1.2.19.apk)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Engine](https://img.shields.io/badge/DSP%20Engine-100%25%20On--Device-7C5CFF?style=for-the-badge)](https://github.com/badarbukharidev-alt/ClipShieldPro)
[![Size](https://img.shields.io/badge/APK%20Size-176%20MB-12B56A?style=for-the-badge)](https://github.com/badarbukharidev-alt/ClipShieldPro)

---

## 🚀 Direct APK Download

Download the latest production release of **ClipShield Pro** directly for your Android device:

📥 **[Download ClipShieldPro-v1.2.19.apk (176 MB)](https://media.githubusercontent.com/media/badarbukharidev-alt/ClipShieldPro/main/release/ClipShieldPro-v1.2.19.apk)**

> *Alternate Direct Links:*
> - [Download via GitHub LFS Stream](https://media.githubusercontent.com/media/badarbukharidev-alt/ClipShieldPro/main/release/ClipShieldPro-v1.2.19.apk)
> - [Download via GitHub Raw Stream](https://github.com/badarbukharidev-alt/ClipShieldPro/raw/main/release/ClipShieldPro-v1.2.19.apk)
> - [Download Reseller APK (Abrar)](https://media.githubusercontent.com/media/badarbukharidev-alt/ClipShieldPro/main/resellers/ClipShieldPro-abrar.apk)

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

## 🏗️ Building the apps

One command builds the house app **and** every reseller's app:

```powershell
.	oolsuild_all.ps1 -Push
```

It fetches the reseller list from the live panel, so adding a reseller there is
all it takes for the next run to produce their APK. Output lands in `release/`
(house) and `resellers/` (one per reseller), and `-Push` commits both to GitHub.

| Flag | Effect |
|---|---|
| `-Push` | commit and push the APKs afterwards |
| `-SkipHouse` | resellers only |
| `-Only abrar,zain` | just those resellers |
| `-Offline -Only abrar` | skip the panel, build from the given list |

### Why this is two compiles and not one per reseller

The reseller code lives in **`assets/build/reseller.txt`**, a bundled asset —
not a compile-time constant. An asset can be rewritten inside a *finished* APK,
so the pipeline is:

1. compile the house app *(admin tools in, no reseller code)*
2. compile a reseller base **once** *(admin tools compiled out)*
3. for each reseller: copy the base → rewrite that one file → re-align → re-sign

Twenty resellers is **two compiles and twenty stamps**, not twenty-two compiles.
A stamp takes seconds.

Rewriting anything inside an APK invalidates its signature, so each stamped file
is re-signed with the same release keystore Gradle uses — it installs over an
existing ClipShield exactly like an ordinary update. `resources.arsc` is kept
uncompressed through the rewrite, because Android rejects an APK where it is not.

> **The admin tools deliberately did *not* move to an asset.** They stay a
> compile-time exclusion, because the asset is editable by anyone repackaging the
> APK. Those screens mint licence keys on-device with no quota and no record — in
> a reseller build they must be *absent*, not hidden behind a flag that could be
> flipped back. A test asserts that stamping or clearing the code cannot
> re-enable them.

---

## 🛠️ What's New in v1.2.19

### 🛡️ Universal Device Compatibility & Zero-Crash Shield
* **Bulletproof Startup (`runZonedGuarded` + `PlatformDispatcher.onError`)**: All asynchronous core subsystems (`BuildIdentity`, `DeviceCapabilityService`, `RemoteConfigService`, `UpdateService`, `LicenseService`, `RenderJobService`) are safely wrapped in isolated fallback blocks. Unhandled platform-level and asynchronous exceptions are caught and suppressed, preventing Android OS from terminating the application on launch.
* **Native Monochromatic Notification Icon (`ic_notification.xml`)**: Added standard monochrome vector drawable to prevent `RemoteServiceException: Bad notification for startForeground` crashes across Oppo (ColorOS), Realme UI, Vivo (FuntouchOS/OriginOS), Xiaomi (HyperOS/MIUI), and Samsung (OneUI).
* **Asynchronous Exception Isolation**: Attached safe `.catchError()` handlers across all unawaited background futures (`syncBonusCredits`, balance sync, remote telemetry), guaranteeing network timeouts or offline boots never kill the app in release mode.
* **Android 14 & 15 (API 34/35) Foreground Service Compliance**: Enhanced service declarations (`dataSync|mediaProcessing`) and runtime permissions (`POST_NOTIFICATIONS`) to ensure background rendering completes seamlessly without being killed by OEM power managers.
* **Graceful UI Recovery (`ErrorWidget.builder`)**: Substituted raw red error screens with a friendly, branded error boundary so users can continue operating the app even if an individual widget encounters layout constraints.
* **SEO & Web Landing Page Refresh**: Updated landing page at `https://clipshieldpro.toolsfinity.io/` with metadata, `llms.txt`, `robots.txt`, and `sitemap.xml`.

---

## 🛠️ What's New in v1.2.16

### 📱 Rendering sized to the device, not to a flagship

Low-end phones were killing the app mid-render — *"ClipShield isn't responding"*,
or the process simply vanishing when Render was tapped. That was **not one bug**.
It was a pipeline configured for the machine it was developed on, and three
things compounded:

| | Before | Why it hurt |
|---|---|---|
| `-threads` | `0` (every core) | x264 keeps **per-thread frame buffers** — an 8-core budget phone allocated 8 sets out of a fraction of a flagship's heap |
| Output | 1080p always | 4× the pixel budget of 720p through every filter |
| Face detection | always on | an ML Kit model resident for the whole pass, on top of the encoder |

None is wrong on a 12 GB phone. All three on a 2 GB phone exceed the heap before
the first frame is written.

`DeviceCapability` now reports total RAM, the **per-app heap ceiling**, core
count, 64-bitness and Android's own low-RAM flag. The heap ceiling matters more
than total RAM — it is what an allocation is measured against, and it is a
fraction of the total. The manufacturer's low-RAM flag outranks the spec sheet.

**Low** devices get one encoder thread, a 720p ceiling whatever quality was
asked, no subject tracking, a 24 MB image cache. **Mid** gets 2–3 threads.
**High is left exactly as it was** — a good phone is not punished to accommodate
a cheap one. An unknown device is treated as *mid*, never optimistically as high.

Also added `android:largeHeap` and bounded `-max_muxing_queue_size`, which is
otherwise free to grow without limit on a long source.

> Capping preserves aspect ratio exactly, never upscales, keeps dimensions even
> for H.264, and cannot be dodged with an ultra-wide source. Where a cap applies,
> the render log says so rather than quietly producing something else.

### 🤝 Reseller system

Resellers get their own portal, their own branded build, and a key allowance they
cannot exceed.

**Admin → Resellers**: create an account with a code, allot keys per tier
(lifetime / monthly / video pack), publish their APK build, reset their password,
disable them.

**Their portal** (`/reseller/`): generate keys against the allowance, set the
WhatsApp number their customers see, download their current build, and see what
versions their customers are actually running.

**Their app**: built with `tools/build_reseller.sh <code>`. It reports its
reseller code on every API call, so the panel returns *their* support number and
*their* update rather than the house ones.

Three decisions worth stating:

- **The in-app admin tools are compiled out of a reseller build.** Those screens
  mint licence keys on-device with no quota and no record — leaving them in would
  let a reseller, or anyone holding a copy of their APK, issue unlimited keys and
  make the whole allowance decorative. Verified by a test run with the define set,
  not assumed.
- **Quota is consumed in a single guarded `UPDATE`** (`WHERE used < allotted`).
  Reading the remaining count and then decrementing would let two requests
  arriving together both spend the last key. If the insert that follows fails,
  the allowance is refunded rather than charged for a key never recorded.
- **A reseller build is never offered the house APK.** It carries a different
  reseller code and would silently re-brand the customer's app, so a reseller with
  no published build gets *no* update rather than the wrong one.

Run `database/migrations/2026_09_16_resellers.sql` once to create the tables.

---

## 🛠️ What's New in v1.2.15

### 🔐 Fixed: "The download could not be verified, so it was not installed"

This stopped genuine updates dead, even after the user had allowed the install
source. Two mistakes compounded:

**The certificate was read the wrong way.** `getPackageArchiveInfo()` with
`GET_SIGNING_CERTIFICATES` returns a **null** `signingInfo` on a good number of
devices — archives have always been better served by the deprecated
`GET_SIGNATURES`. Reading only the modern accessor meant the signature came back
unreadable on a perfectly genuine APK. Both accessors are now tried, on both the
installed app and the download, and signing-key *history* is collected too so a
future key rotation does not read as a mismatch.

**Unreadable was treated as wrong.** That was the deeper error. A download that
could not be *parsed* was refused as though it had been caught being
*substituted*.

> Android already refuses to replace an installed app with one signed by a
> different key. That is enforced by the package manager and cannot be talked out
> of. This check exists to fail **early and legibly** rather than after a 180 MB
> download — it was never the only thing standing in the way. So an unreadable
> certificate now proceeds and lets the OS enforce what it was always going to
> enforce. **A signature that reads fine and does not match is still refused
> outright**, as is a different package name.

### ⚡ One tap to the permission screen

Tapping **Update** without the install permission used to show an error and then
require a *second* button press to reach Settings. That was one tap of pure
ceremony — there is nothing else someone could have wanted from "Update".

Settings now opens on that first tap. The dialog watches for the app resuming,
re-reads the permission, and clears the error by itself — so coming back and
tapping **Update** starts the download immediately, with no stale "needs
permission" message on a button that would now work. If the permission still is
not granted, it says so plainly instead of failing silently.

---

## 🛠️ What's New in v1.2.14

### 🔁 Fixed: one video appeared in the gallery two or three times

The results screen is reachable from four places, and **every visit re-ran the
export**. MediaStore does not overwrite, so a second insert of the same name
becomes `clip (1).mp4` and each visit looked like a brand new file.

Fixed in two layers, because either alone leaves a hole:

- **The insert is idempotent.** Before writing, MediaStore is queried for a row
  with the same display name, folder *and* size. A match is handed back instead of
  a second row. Size is part of the check so a genuinely different export of the
  same name is not silently skipped. The pre-Android-10 path got the same guard,
  where a re-copy plus re-scan produced the duplicate.
- **The project remembers.** A finished project carries a `galleryExported` flag,
  so a revisit reports the earlier save rather than repeating it. Set only on
  success, so a failed export is still retried next time.

### 🖼️ Fixed: thumbnail downloads failed on a large share of videos

YouTube only generates `maxresdefault.jpg` for videos uploaded above 720p. For
everything else that URL **404s** — verified against a real video:

```
jNQXAC9IVRw/maxresdefault.jpg -> 404  (1097 bytes of error page)
jNQXAC9IVRw/hqdefault.jpg     -> 200  (15921 bytes)
```

The old code asked for that single URL through a client whose default
`validateStatus` **throws** on a 404, caught the exception, and reported
"thumbnail download failed" for a video whose thumbnail was sitting one rung down.

Now four candidates are tried in quality order — `maxres`, the standard URL,
`hqdefault`, `mqdefault` — and the first that returns real bytes wins. A 404 moves
to the next candidate instead of ending the attempt. Anything under 2 KB is
rejected too, so an error page can never be saved as somebody's thumbnail.

### 🖼️ The thumbnail now saves itself

It is published to `Pictures/ClipShield` automatically alongside the render, so it
is there to upload with rather than needing a separate trip into the metadata
panel. Silent on failure: a video that saved fine is not reported as a failed
export because a thumbnail URL was unreachable.

---

## 🛠️ What's New in v1.2.13

### 🐛 Fixed: direct sharing failed on every app

Tapping WhatsApp, Instagram, YouTube or TikTok said *"the app would not accept
the file"*, while **More** worked — which was the clue: the file was fine, our
route to it was not.

`getApplicationDocumentsDirectory()` maps to `context.getDir("flutter")`, i.e.
`/data/user/0/<pkg>/**app_flutter**` — and that is covered by **no** FileProvider
tag. `files-path` is `getFilesDir()`, a *sibling* directory; the `external-*` tags
are elsewhere entirely. So `getUriForFile()` threw *"Failed to find configured
root"* for every rendered clip. share_plus worked because it copies the file into
its own cache directory first.

`root-path` now covers it. The exposure is narrow: the provider is not exported,
nothing is readable without a URI we mint, and each grant is per-share and
transient.

> **The real lesson was the error message.** `shareToPackage` returned a bare
> `bool`, so "provider path not configured", "app not installed" and "app refuses
> this type" all arrived as the same `false` — and the actual cause had to be
> found by reading path_provider's source. It now returns a reason code, and
> anything that is *our* fault falls back to the chooser instead of blaming the
> target app.

### 📲 Updates install inside the app

"Update now" downloads with a progress bar and hands the APK to Android's
installer. No browser, no Downloads folder, no hunting for the file.

**The APK is signature-checked against the running build before the installer is
opened.** This matters more than the convenience: the download link comes from the
admin panel, so without that check anyone who compromised the panel could point
every install at a different package, and the only thing between the user and
running it would be a dialog saying "ClipShield wants to install an app". A
mismatch is refused before the user is asked anything.

The app still installs nothing by itself — Android shows its own confirmation, and
from Android 8 the user must separately allow ClipShield under *Install unknown
apps*. That permission is checked **before** the download, not after, so nobody
waits through 180 MB to be sent to Settings. "Download in browser instead" remains
available if anything fails.

### 🎁 A way out when the trial runs out

The dialog that appears when your trial export is used up now leads with **Get
free videos**, opening the Tasks screen. It appears at exactly the moment someone
needs to know free renders are earnable, and until now the only things on screen
were *buy a key* and *close*. An existing balance is stated rather than asked for
again: *"You have 3 free videos"*.

### ⏱️ Lengths read like lengths

A two-hour source was labelled **`7200s`** — technically correct and useless.
Now `45s`, `12m 30s`, `1h 24m`. One formatter across shorts, songs and long videos.

Deliberately not `mm:ss`: "12:30" is read as half past twelve about as often as
twelve and a half minutes, and the same string has to serve a 20-second short and
a two-hour film.

### 🧱 Two XML comments that broke the build

`--` is not permitted inside an XML comment, and I used it as an em-dash in both
`file_paths.xml` and `AndroidManifest.xml`. Caught by the build, then swept for
across every XML file in the Android tree.

---

## 🛠️ What's New in v1.2.12

### 💾 Fixed: nothing was ever reaching the gallery

Renders, song exports and downloaded thumbnails were all missing from Gallery,
Photos and Files. The cause was one method that could not work on any phone
running Android 10 or newer:

```dart
// Both of these fail on modern Android, and both failures were swallowed.
final dir = Directory('/storage/emulated/0/Movies/ClipShield');  // scoped storage
await Process.run('am', ['broadcast', ...MEDIA_SCANNER_SCAN_FILE]);  // not app-callable
```

Scoped storage rejects the write outright on API 30+, and apps have not been able
to send that broadcast for years. Both errors were caught and ignored, so the
copy quietly fell back to **app-private storage** — a render reported itself saved
and then appeared in no gallery on earth.

Saving now goes through **MediaStore** in a new Kotlin bridge, which is the only
supported route. Videos land in `Movies/ClipShield`, images in
`Pictures/ClipShield`, audio in `Music/ClipShield`, and `IS_PENDING` keeps a row
hidden until the bytes are fully written so a gallery never shows a half-copied
file. Android 9 and below still take the legacy path with a proper
`MediaScannerConnection` call.

Downloaded thumbnails are staged privately and then published the same way,
rather than being written into a folder the app is not allowed to create.

Files are also named usefully now — `ClipShield_<project title>.mp4` instead of
the render's temp basename.

> **The failure is no longer silent.** The results banner has three states rather
> than only appearing on success, so a save that does not work says so and offers
> a retry.

### 📤 Share buttons that actually go somewhere

Every icon in the share row was wired to the same system chooser, so tapping
Instagram and tapping WhatsApp did exactly the same thing. Each destination now
builds an explicit `ACTION_SEND` intent for that app's package and goes straight
there. An app that is not installed is **named**, instead of nothing happening.

Icons are the real brand marks from Font Awesome, not Material look-alikes — a
green speech bubble is not the WhatsApp logo, and people find these by shape.

Added TikTok, covering **both** of its package names: it ships as
`com.zhiliaoapp.musically` or `com.ss.android.ugc.trill` depending on where the
phone was sold, and checking one reports "not installed" for half the world.

Sharing needed a `FileProvider`: a `file://` URI has thrown
`FileUriExposedException` since Android 7, and the receiving app cannot read our
private directory in any case.

### 🎛️ Song settings collapse behind Advanced

Ten DSP sliders and a toggle opened before you had done anything. They sit behind
an **Advanced** row now, the same as the copyright remover in v1.2.10. Cover image
and output shape stay visible — those are choices, not settings.

### 📌 Pinned `font_awesome_flutter` to 10.7.0

10.8+ calls `Color.withValues()`, which does not exist before Flutter 3.27; this
project builds on 3.24.5. Raise it only together with the SDK.

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