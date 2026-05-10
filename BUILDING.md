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
Zerk Play expects a **libmpv** DLL at `libs/libmpv-2.dll`.

Use the **patched mitzsch build** for correct TrueHD / DTS-HD bitstream passthrough:

1. Download `mpv-dev-x86_64-<date>-git-<hash>.7z` from the latest release at
   https://github.com/mitzsch/mpv-winbuild/releases
2. Extract `libmpv-2.dll` from the archive into the `libs/` folder.
3. The CMake build picks it up automatically — no other changes needed.

> The `v3` variant (`mpv-dev-x86_64-v3-…`) uses AVX2 and is faster, but requires
> Intel Haswell (2013+) or AMD Excavator (2015+). Use the non-v3 build for
> maximum compatibility in distributed releases.

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

For a full walkthrough — including extended codec AARs, ADB sideloading, and
wireless install options — see **[BUILDING_ANDROID.md](BUILDING_ANDROID.md)**.

### Quick start

```bash
# Run on a connected device
flutter run -d <device-id>

# Build release APK
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk

# Sideload via ADB
adb install build/app/outputs/flutter-apk/app-release.apk
```

