import 'package:shared_preferences/shared_preferences.dart';

import '../../core/emby/models/emby_media_stream.dart';
import '../../core/emby/models/emby_playback_info.dart';

enum PlaybackQualityPreference { auto, p2160, p1080, p720 }

enum SubtitlePreferenceMode { off, auto, language }

final class PlaybackPrefs {
  const PlaybackPrefs({
    required this.qualityPreference,
    required this.audioLanguage,
    required this.subtitleMode,
    required this.subtitleLanguage,
    required this.volume,
  });

  final PlaybackQualityPreference qualityPreference;
  final String audioLanguage;
  final SubtitlePreferenceMode subtitleMode;
  final String subtitleLanguage;
  final double volume;

  PlaybackPrefs copyWith({
    PlaybackQualityPreference? qualityPreference,
    String? audioLanguage,
    SubtitlePreferenceMode? subtitleMode,
    String? subtitleLanguage,
    double? volume,
  }) {
    return PlaybackPrefs(
      qualityPreference: qualityPreference ?? this.qualityPreference,
      audioLanguage: audioLanguage ?? this.audioLanguage,
      subtitleMode: subtitleMode ?? this.subtitleMode,
      subtitleLanguage: subtitleLanguage ?? this.subtitleLanguage,
      volume: volume ?? this.volume,
    );
  }

  static const defaults = PlaybackPrefs(
    qualityPreference: PlaybackQualityPreference.auto,
    audioLanguage: '',
    subtitleMode: SubtitlePreferenceMode.auto,
    subtitleLanguage: '',
    volume: 70,
  );

  static const _kQuality = 'playback_quality';
  static const _kAudioLang = 'playback_audio_lang';
  static const _kSubMode = 'playback_sub_mode';
  static const _kSubLang = 'playback_sub_lang';
  static const _kVolume = 'playback_volume';

  static Future<PlaybackPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    final qualityRaw = (prefs.getString(_kQuality) ?? '').trim();
    final audioLang = (prefs.getString(_kAudioLang) ?? '').trim();
    final subModeRaw = (prefs.getString(_kSubMode) ?? '').trim();
    final subLang = (prefs.getString(_kSubLang) ?? '').trim();
    final volumeRaw = prefs.getDouble(_kVolume) ?? (prefs.getInt(_kVolume)?.toDouble());
    final volume = (volumeRaw ?? defaults.volume).clamp(0.0, 100.0);

    return PlaybackPrefs(
      qualityPreference: _parseQuality(qualityRaw) ?? defaults.qualityPreference,
      audioLanguage: audioLang,
      subtitleMode: _parseSubtitleMode(subModeRaw) ?? defaults.subtitleMode,
      subtitleLanguage: subLang,
      volume: volume,
    );
  }

  static Future<void> save(PlaybackPrefs value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kQuality, _encodeQuality(value.qualityPreference));
    await prefs.setString(_kAudioLang, value.audioLanguage.trim());
    await prefs.setString(_kSubMode, _encodeSubtitleMode(value.subtitleMode));
    await prefs.setString(_kSubLang, value.subtitleLanguage.trim());
    await prefs.setDouble(_kVolume, value.volume.clamp(0.0, 100.0));
  }

  int? maxStreamingBitrate() {
    switch (qualityPreference) {
      case PlaybackQualityPreference.auto:
        return null;
      case PlaybackQualityPreference.p2160:
        return 80000000;
      case PlaybackQualityPreference.p1080:
        return 20000000;
      case PlaybackQualityPreference.p720:
        return 8000000;
    }
  }

  Uri pickStreamUrl(EmbyPlaybackInfo info) {
    return info.streamUrl;
  }

  EmbyAudioStream? pickAudio(List<EmbyAudioStream> audio) {
    if (audio.isEmpty) return null;
    final desired = _normLang(audioLanguage);
    if (desired.isNotEmpty) {
      for (final a in audio) {
        if (_normLang(a.language) == desired) return a;
        if (_titleMatchesLang(a.title, desired)) return a;
      }
    }
    final defaults = audio.where((a) => a.isDefault).toList(growable: false);
    if (defaults.isNotEmpty) return defaults.first;
    return audio.first;
  }

  EmbySubtitleStream? pickSubtitle(List<EmbySubtitleStream> subtitles) {
    if (subtitleMode == SubtitlePreferenceMode.off) return null;
    if (subtitles.isEmpty) return null;

    final desired = subtitleMode == SubtitlePreferenceMode.language
        ? _normLang(subtitleLanguage)
        : '';
    if (desired.isNotEmpty) {
      for (final s in subtitles) {
        if (_normLang(s.language) == desired) return s;
        if (_titleMatchesLang(s.title, desired)) return s;
      }
    }

    final defaults = subtitles.where((s) => s.isDefault).toList(growable: false);
    if (defaults.isNotEmpty) return defaults.first;
    return null;
  }
}

bool _titleMatchesLang(String? title, String desiredLang) {
  final t = (title ?? '').toLowerCase();
  if (t.isEmpty) return false;
  if (desiredLang == 'en') {
    return t.contains('english') || t.contains('eng') || t.contains('[en]') || t.contains('(en)');
  }
  if (desiredLang == 'ro') {
    return t.contains('romanian') ||
        t.contains('romana') ||
        t.contains('română') ||
        t.contains('romana') ||
        t.contains('rum') ||
        t.contains('ron') ||
        t.contains('[ro]') ||
        t.contains('(ro)');
  }
  return false;
}

PlaybackQualityPreference? _parseQuality(String raw) {
  switch (raw.toLowerCase()) {
    case 'auto':
      return PlaybackQualityPreference.auto;
    case '4k':
    case '2160p':
      return PlaybackQualityPreference.p2160;
    case '1080p':
      return PlaybackQualityPreference.p1080;
    case '720p':
      return PlaybackQualityPreference.p720;
    case 'direct':
    case 'transcode':
      return PlaybackQualityPreference.auto;
  }
  return null;
}

String _encodeQuality(PlaybackQualityPreference value) {
  switch (value) {
    case PlaybackQualityPreference.auto:
      return 'auto';
    case PlaybackQualityPreference.p2160:
      return '2160p';
    case PlaybackQualityPreference.p1080:
      return '1080p';
    case PlaybackQualityPreference.p720:
      return '720p';
  }
}

SubtitlePreferenceMode? _parseSubtitleMode(String raw) {
  switch (raw.toLowerCase()) {
    case 'off':
      return SubtitlePreferenceMode.off;
    case 'auto':
      return SubtitlePreferenceMode.auto;
    case 'language':
      return SubtitlePreferenceMode.language;
  }
  return null;
}

String _encodeSubtitleMode(SubtitlePreferenceMode value) {
  switch (value) {
    case SubtitlePreferenceMode.off:
      return 'off';
    case SubtitlePreferenceMode.auto:
      return 'auto';
    case SubtitlePreferenceMode.language:
      return 'language';
  }
}

String _normLang(String? language) {
  final v = (language ?? '').toLowerCase().trim();
  if (v.isEmpty) return '';
  final base = v.split(RegExp('[_-]')).first;
  final base2 = base.replaceAll(RegExp(r'[^a-z]'), '');
  if (base2.isEmpty) return '';
  final mapped = _iso3ToIso2[base2];
  if (mapped != null) return mapped;
  if (base2.length >= 2) return base2.substring(0, 2);
  return base2;
}

const Map<String, String> _iso3ToIso2 = {
  'ron': 'ro',
  'rum': 'ro',
  'eng': 'en',
  'fre': 'fr',
  'fra': 'fr',
  'ger': 'de',
  'deu': 'de',
  'spa': 'es',
  'ita': 'it',
  'por': 'pt',
  'jpn': 'ja',
  'chi': 'zh',
  'zho': 'zh',
  'dut': 'nl',
  'nld': 'nl',
  'nor': 'no',
  'dan': 'da',
  'fin': 'fi',
  'swe': 'sv',
  'pol': 'pl',
  'rus': 'ru',
  'ukr': 'uk',
};
