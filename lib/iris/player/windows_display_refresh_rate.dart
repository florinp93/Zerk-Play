import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';

/// Matches primary display refresh rate to video content on Windows (best-effort).
///
/// Restores the mode captured before [applyForVideoFps] when [restore] is called.
final class WindowsDisplayRefreshRate {
  WindowsDisplayRefreshRate._();

  static Pointer<DEVMODE>? _savedBeforeSwitch;
  static bool _applied = false;

  static final Pointer<Utf16> _primaryDevice = Pointer<Utf16>.fromAddress(0);

  /// Parses mpv-style fractional fps (e.g. `24000/1001`) or a plain double.
  static double? parseFpsString(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final slash = s.indexOf('/');
    if (slash > 0) {
      final a = double.tryParse(s.substring(0, slash));
      final b = double.tryParse(s.substring(slash + 1));
      if (a != null && b != null && b != 0) {
        return a / b;
      }
    }
    return double.tryParse(s);
  }

  /// Maps common film/video frame rates to a display refresh rate in Hz.
  static int targetRefreshHzFromFps(double fps) {
    if (fps >= 23.4 && fps <= 24.2) return 24;
    if (fps >= 24.8 && fps <= 25.2) return 25;
    if (fps >= 29.4 && fps <= 30.2) return 60;
    if (fps >= 47.5 && fps <= 50.2) return 50;
    if (fps >= 59.0 && fps <= 60.2) return 60;
    final r = fps.round();
    return r.clamp(24, 360);
  }

  static void restore() {
    if (!Platform.isWindows) return;
    if (!_applied || _savedBeforeSwitch == null) return;
    try {
      final r = ChangeDisplaySettings(_savedBeforeSwitch!, CDS_FULLSCREEN);
      if (kDebugMode && r != DISP_CHANGE_SUCCESSFUL) {
        debugPrint('[WindowsDisplayRefreshRate] restore returned $r');
      }
    } catch (e, st) {
      debugPrint('[WindowsDisplayRefreshRate] restore failed: $e\n$st');
    } finally {
      calloc.free(_savedBeforeSwitch!);
      _savedBeforeSwitch = null;
      _applied = false;
    }
  }

  /// Attempts to switch the primary display to a mode with [targetHz] at the current resolution.
  static void applyForVideoFps(double? fps) {
    if (!Platform.isWindows || fps == null || fps <= 0) return;

    final targetHz = targetRefreshHzFromFps(fps);

    final current = calloc<DEVMODE>(1);
    current.ref.dmSize = sizeOf<DEVMODE>();

    try {
      if (EnumDisplaySettings(_primaryDevice, ENUM_CURRENT_SETTINGS, current) == 0) {
        calloc.free(current);
        return;
      }

      final w = current.ref.dmPelsWidth;
      final h = current.ref.dmPelsHeight;
      final currentHz = current.ref.dmDisplayFrequency;

      if (currentHz == targetHz) {
        calloc.free(current);
        return;
      }

      var bestIndex = -1;
      var bestDiff = 1 << 30;

      for (var i = 0; i < 4096; i++) {
        final dm = calloc<DEVMODE>(1);
        dm.ref.dmSize = sizeOf<DEVMODE>();
        final ok = EnumDisplaySettings(_primaryDevice, i, dm);
        if (ok == 0) {
          calloc.free(dm);
          break;
        }
        if (dm.ref.dmPelsWidth == w && dm.ref.dmPelsHeight == h) {
          final hz = dm.ref.dmDisplayFrequency;
          final diff = (hz - targetHz).abs();
          if (diff < bestDiff) {
            bestDiff = diff;
            bestIndex = i;
          }
        }
        calloc.free(dm);
      }

      if (bestIndex < 0) {
        calloc.free(current);
        return;
      }

      final targetMode = calloc<DEVMODE>(1);
      targetMode.ref.dmSize = sizeOf<DEVMODE>();
      if (EnumDisplaySettings(_primaryDevice, bestIndex, targetMode) == 0) {
        calloc.free(targetMode);
        calloc.free(current);
        return;
      }

      if (targetMode.ref.dmDisplayFrequency == currentHz) {
        calloc.free(targetMode);
        calloc.free(current);
        return;
      }

      _savedBeforeSwitch = current;
      _applied = false;

      final result = ChangeDisplaySettings(targetMode, CDS_FULLSCREEN);
      calloc.free(targetMode);

      if (result == DISP_CHANGE_SUCCESSFUL) {
        _applied = true;
      } else {
        calloc.free(_savedBeforeSwitch!);
        _savedBeforeSwitch = null;
        if (kDebugMode) {
          debugPrint('[WindowsDisplayRefreshRate] ChangeDisplaySettings failed: $result');
        }
      }
    } catch (e, st) {
      debugPrint('[WindowsDisplayRefreshRate] apply failed: $e\n$st');
      if (_savedBeforeSwitch != null) {
        calloc.free(_savedBeforeSwitch!);
        _savedBeforeSwitch = null;
      } else {
        calloc.free(current);
      }
    }
  }
}
