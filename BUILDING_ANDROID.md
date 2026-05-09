# Building Zerk Play — Android TV

## Prerequisites

| Tool | Version |
|---|---|
| Flutter SDK (stable) | ≥ 3.22 |
| Android SDK | API 23+ |
| Java | 17 |
| ADB (optional, for sideloading) | any recent |

## 1. Get dependencies

```bash
flutter pub get
```

## 2. Optional: extended codec support

For AC3, EAC3, DTS, TrueHD, AV1, VP9, FLAC, and Opus passthrough, place the
ExoPlayer decoder AARs in `android/app/libs/`:

```
decoder_ffmpeg-release.aar
decoder_av1-release.aar
decoder_vp9-release.aar
decoder_flac-release.aar
decoder_opus-release.aar
```

ExoPlayer's built-in decoders are used automatically when these files are absent.

## 3. Build the release APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

---

## Installing on an Android TV / Chromecast with Google TV

### Option A — ADB (recommended for developers)

1. Enable **Developer options** and **USB debugging** (or **Wireless debugging**) on
   the device.
2. Connect via USB or find the device IP address for wireless ADB:
   ```bash
   adb connect <device-ip>:5555
   ```
3. Install:
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```
4. Launch from the device launcher or via ADB:
   ```bash
   adb shell am start -n "cloud.zerk.play/cloud.zerk.play.MainActivity"
   ```

### Option B — Send Files to TV (no computer needed after the first download)

1. Install **[Send Files to TV](https://play.google.com/store/apps/details?id=com.yablio.sendfilestotv)**
   on **both** the Android TV device and an Android phone/tablet.
2. Download `app-release.apk` from the [GitHub Releases](../../releases) page on
   the phone.
3. Open *Send Files to TV* on the phone, tap **Send**, select the APK, and
   choose your TV as the destination.
4. Open *Send Files to TV* on the TV, tap **Receive** — the APK will be saved
   to the TV's storage.
5. Use a file manager (e.g. **FX File Explorer**) to browse to the received APK
   and tap it to install. Allow *Install from unknown sources* if prompted.

### Option C — Downloader (URL-based, TV-only)

1. Install **[Downloader by AFTVnews](https://play.google.com/store/apps/details?id=com.aftvnews.downloader)**
   on the TV.
2. Open Downloader, enter the direct URL to `app-release.apk` from the
   [GitHub Releases](../../releases) page.
3. The app will download and prompt you to install immediately.

---

## Updating an existing installation

Use the same method as the initial install.  
`adb install -r` (replace) or re-downloading and re-installing via Send Files /
Downloader will update in-place without losing app data.
