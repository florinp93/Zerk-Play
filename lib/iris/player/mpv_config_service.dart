import 'dart:convert';
import 'dart:io';

import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves and loads [mpv.conf] from app support directory into libmpv.
final class MpvConfigService {
  MpvConfigService._();

  static const String fileName = 'mpv.conf';

  static Future<String> configFilePath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, fileName);
  }

  /// Ensures the config file exists (creates an active-defaults template if missing).
  static Future<File> ensureConfigFile() async {
    final path = await configFilePath();
    final file = File(path);
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      await file.writeAsString(_defaultTemplate, encoding: utf8);
    }
    return file;
  }

  /// Reads current config text from disk.
  static Future<String> readConfigText() async {
    final file = await ensureConfigFile();
    return file.readAsString(encoding: utf8);
  }

  static Future<void> writeConfigText(String text) async {
    final path = await configFilePath();
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(text, encoding: utf8);
  }

  /// Parses [text] into a key→value map. Strips comments; ignores blank lines.
  static Map<String, String> parseConf(String text) {
    final result = <String, String>{};
    for (final raw in text.split('\n')) {
      var line = raw.trimRight();
      final ci = line.indexOf('#');
      if (ci >= 0) line = line.substring(0, ci).trim();
      final si = line.indexOf(';');
      if (si == 0) continue;
      if (si > 0) line = line.substring(0, si).trim();
      if (line.isEmpty) continue;
      final eq = line.indexOf('=');
      if (eq <= 0) continue;
      final key = line.substring(0, eq).trim();
      var val = line.substring(eq + 1).trim();
      if (key.isEmpty) continue;
      if ((val.startsWith('"') && val.endsWith('"')) ||
          (val.startsWith("'") && val.endsWith("'"))) {
        val = val.substring(1, val.length - 1);
      }
      result[key] = val;
    }
    return result;
  }

  static const Set<String> _omitIfEmpty = {'audio-spdif', 'audio-device', 'af'};

  /// Serialises [values] to conf text, grouping known keys by section.
  /// Unrecognised keys are appended under a "# Custom" header (preserving them).
  static String buildConf(Map<String, String> values) {
    final sb = StringBuffer()
      ..writeln('# Zerk Play — mpv configuration')
      ..writeln('# Managed by Settings → Player / MPV  |  https://mpv.io/manual/master/')
      ..writeln();

    final written = <String>{};

    void section(String header, Set<String> keys) {
      final entries = keys.where((k) {
        if (!values.containsKey(k)) return false;
        if (_omitIfEmpty.contains(k) && (values[k] ?? '').isEmpty) return false;
        return true;
      }).toList();
      if (entries.isEmpty) return;
      sb.writeln(header);
      for (final k in entries) {
        sb.writeln('$k=${values[k]}');
      }
      sb.writeln();
      written.addAll(entries);
    }

    section('# Video', _videoKeys);
    section('# Audio', _audioKeys);
    section('# Subtitles', _subtitleKeys);
    section('# Network & Cache', _networkKeys);

    final custom = values.entries.where((e) => !written.contains(e.key)).toList();
    if (custom.isNotEmpty) {
      sb.writeln('# Custom');
      for (final e in custom) {
        sb.writeln('${e.key}=${e.value}');
      }
    }

    return sb.toString();
  }

  /// Loads user [mpv.conf] into the player. Tries `load-config-file` first; falls back to
  /// setting properties line-by-line.
  static Future<void> loadUserConfigIntoPlayer(Player player) async {
    final platform = player.platform;
    if (platform == null) return;
    final dynamic pl = platform;

    await ensureConfigFile();
    final path = await configFilePath();
    final abs = p.normalize(File(path).absolute.path);

    try {
      await pl.command(['load-config-file', abs]);
    } catch (_) {
      final text = await readConfigText();
      await _applyConfLines(pl, text);
    }
  }

  static Future<void> _applyConfLines(dynamic pl, String content) async {
    for (final entry in parseConf(content).entries) {
      try {
        await pl.setProperty(entry.key, entry.value);
      } catch (_) {}
    }
  }

  // ── Section key sets (used by buildConf for organised output) ────────────

  static const Set<String> _videoKeys = {
    'hwdec', 'gpu-api', 'vo', 'video-sync', 'interpolation', 'tscale',
    'scale', 'dscale', 'cscale', 'correct-downscaling', 'linear-downscaling',
    'sigmoid-upscaling', 'dither', 'deband', 'deband-iterations',
    'deband-threshold', 'deband-range', 'deband-grain',
    'hdr-compute-peak', 'target-colorspace-hint', 'tone-mapping',
    'hr-seek', 'hr-seek-framedrop', 'save-position-on-quit',
  };

  static const Set<String> _audioKeys = {
    'audio-pitch-correction', 'audio-normalize-downmix', 'volume-max', 'audio-delay',
    'audio-spdif', 'audio-device',
  };

  static const Set<String> _subtitleKeys = {
    'sub-ass-override', 'sub-font-size', 'sub-scale', 'sub-margin-y', 'sub-margin-x',
    'sub-border-size', 'sub-shadow-offset', 'sub-blur', 'sub-pos', 'sub-delay',
    'sub-fix-timing',
  };

  static const Set<String> _networkKeys = {
    'network-timeout', 'tls-verify', 'cache', 'cache-secs',
    'demuxer-max-bytes', 'demuxer-max-back-bytes', 'demuxer-readahead-secs',
    'cache-on-disk',
  };

  // ── Default template (active values, not comments) ───────────────────────

  static const String _defaultTemplate =
      '# Zerk Play — mpv configuration\n'
      '# Managed by Settings → Player / MPV  |  https://mpv.io/manual/master/\n'
      '\n'
      '# Video\n'
      'hwdec=d3d11va\n'
      'gpu-api=d3d11\n'
      '# video-sync=display-resample and interpolation=yes give smoother motion\n'
      '# but significantly increase CPU/GPU load — enable only if your system can handle it.\n'
      '# video-sync=display-resample\n'
      '# interpolation=yes\n'
      '# tscale=oversample\n'
      'scale=spline36\n'
      'dscale=bilinear\n'
      'dither=fruit\n'
      'hdr-compute-peak=no\n'
      'tone-mapping=auto\n'
      'hr-seek=yes\n'
      'hr-seek-framedrop=no\n'
      '\n'
      '# Audio\n'
      'audio-pitch-correction=yes\n'
      'volume-max=130\n'
      '# Passthrough: set audio-spdif to pass Dolby/DTS bitstream to your receiver.\n'
      '# E.g. for Atmos/TrueHD: audio-spdif=truehd,eac3,ac3,dts\n'
      '# audio-spdif=\n'
      '\n'
      '# Subtitles\n'
      'sub-ass-override=no\n'
      'sub-font-size=55\n'
      'sub-scale=1.0\n'
      'sub-margin-y=36\n'
      'sub-margin-x=25\n'
      'sub-border-size=3.0\n'
      'sub-shadow-offset=0.0\n'
      'sub-blur=0.0\n'
      '\n'
      '# Network & Cache\n'
      'network-timeout=5\n'
      'cache=yes\n'
      'cache-secs=30\n'
      'demuxer-max-bytes=33554432\n'
      'demuxer-max-back-bytes=33554432\n';
}
