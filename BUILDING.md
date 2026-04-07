# Building Zerk Play

This project is a Flutter desktop application. These instructions focus on Windows because playback uses libmpv on Windows.

## Prerequisites
- Flutter SDK (stable) installed and on PATH
- Visual Studio with the "Desktop development with C++" workload (Windows)

## libmpv (Windows playback)
Zerk Play expects a **libmpv** DLL at:
- `libs/libmpv-2.dll`

You can obtain mpv/libmpv builds from:
- https://mpv.io/

If you place `libmpv-2.dll` in `libs/`, the Windows build packaging step will copy it next to the executable.

## Get dependencies
From the project root:

```bash
flutter pub get
```

## Run (Windows)

```bash
flutter run -d windows
```

## Build (Windows release)

```bash
flutter build windows --release
```

The produced executable will be in:
- `build/windows/x64/runner/Release/zerk_play.exe`

