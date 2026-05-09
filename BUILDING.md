# Building Zerk Play

Zerk Play is a Flutter application targeting **Windows** (desktop) and **Android TV**.

## Prerequisites
- Flutter SDK (stable) installed and on PATH
- **Windows**: Visual Studio with the "Desktop development with C++" workload
- **Android TV**: Android SDK, Java 17+, and an Android TV device or emulator (API 23+)

## Get dependencies

```bash
flutter pub get
```

## Windows

### libmpv (Windows playback)
Zerk Play expects a **libmpv** DLL at `libs/libmpv-2.dll`. You can obtain builds from https://mpv.io/.

### Run

```bash
flutter run -d windows
```

### Build release

```bash
flutter build windows --release
```

Output: `build/windows/x64/runner/Release/zerk_play.exe`

## Android TV

### Optional FFmpeg decoder AARs
For extended codec support (AC3, EAC3, DTS, TrueHD, AV1, VP9, FLAC, Opus), place the decoder AAR files in `android/app/libs/`:
- `decoder_ffmpeg-release.aar`
- `decoder_av1-release.aar`
- `decoder_vp9-release.aar`
- `decoder_flac-release.aar`
- `decoder_opus-release.aar`

These are optional; ExoPlayer will use its built-in decoders without them.

### Run on a connected device

```bash
flutter run -d <device-id>
```

### Build release APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Sideload to Android TV
Transfer the APK via ADB:

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

