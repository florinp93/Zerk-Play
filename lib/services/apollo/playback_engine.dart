import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../../core/emby/models/emby_playback_info.dart';
import '../../core/emby/models/emby_media_stream.dart';
import 'apollo_service.dart';

final class PlaybackEngine {
  PlaybackEngine({
    required ApolloService apollo,
    required Player player,
    required String itemId,
    required EmbyPlaybackInfo info,
  })  : _apollo = apollo,
        _player = player,
        _itemId = itemId,
        _info = info;

  final ApolloService _apollo;
  final Player _player;
  final String _itemId;
  final EmbyPlaybackInfo _info;

  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  Timer? _bufferingKeepAlive;
  Timer? _nextUpTimer;
  bool _started = false;
  bool _introSkipped = false;
  bool _nextUpDismissed = false;
  int? _introStartMs;
  int? _introEndMs;
  int? _creditsStartMs;
  String? _seriesId;
  final StreamController<String> _playNextRequestedController =
      StreamController<String>.broadcast();

  final ValueNotifier<bool> showSkipIntro = ValueNotifier<bool>(false);
  final ValueNotifier<int?> nextUpCountdownSeconds = ValueNotifier<int?>(null);
  final ValueNotifier<String?> nextUpEpisodeId = ValueNotifier<String?>(null);

  Stream<String> get playNextRequested => _playNextRequestedController.stream;

  bool _debugLoggedNoSeriesId = false;

  Future<void> start({
    int? resumePositionMs,
    int? subtitleStreamIndex,
    int? audioStreamIndex,
    int? introStartMs,
    int? introEndMs,
    int? creditsStartMs,
    String? seriesId,
  }) async {
    if (_started) return;
    _started = true;
    _introStartMs = introStartMs;
    _introEndMs = introEndMs;
    _creditsStartMs = creditsStartMs;
    _seriesId = seriesId;
    _debug(
      'start itemId=$_itemId resumeMs=$resumePositionMs audioIndex=$audioStreamIndex subtitleIndex=$subtitleStreamIndex '
      'intro=[$introStartMs,$introEndMs] creditsStartMs=$creditsStartMs seriesId=$seriesId',
    );

    if (seriesId != null && seriesId.isNotEmpty) {
      () async {
        try {
          final nextId = await _apollo.getNextUpEpisodeId(
            seriesId: seriesId,
            excludeItemId: _itemId,
          );
          if (nextId != null && nextId.isNotEmpty) {
            nextUpEpisodeId.value = nextId;
            _debug('nextUp prefetched nextEpisodeId=$nextId');
          }
        } catch (_) {}
      }();
    }

    await _initializePlayback(
      resumePositionMs: resumePositionMs,
      subtitleStreamIndex: subtitleStreamIndex,
      audioStreamIndex: audioStreamIndex,
    );

    _durationSub = _player.stream.duration.listen((duration) {
      _maybeSetCreditsFallback(duration);
    });
    _maybeSetCreditsFallback(_player.state.duration);

    _positionSub = _player.stream.position.listen(_handlePosition);

    _playingSub = _player.stream.playing.listen((playing) async {
      await _apollo.reportPlaybackProgress(
        itemId: _itemId,
        info: _info,
        positionTicks: _positionTicks(_player.state.position),
        isPaused: !playing,
        eventName: playing ? 'Unpause' : 'Pause',
      );
    });

    _bufferingSub = _player.stream.buffering.listen((buffering) async {
      if (buffering) {
        await _apollo.reportPlaybackProgress(
          itemId: _itemId,
          info: _info,
          positionTicks: _positionTicks(_player.state.position),
          isPaused: !_player.state.playing,
          eventName: 'timeupdate',
        );

        _bufferingKeepAlive?.cancel();
        _bufferingKeepAlive = Timer.periodic(const Duration(seconds: 10), (_) async {
          try {
            await _apollo.reportPlaybackProgress(
              itemId: _itemId,
              info: _info,
              positionTicks: _positionTicks(_player.state.position),
              isPaused: !_player.state.playing,
              eventName: 'timeupdate',
            );
          } catch (_) {}
        });
      } else {
        _bufferingKeepAlive?.cancel();
        _bufferingKeepAlive = null;
      }
    });

    _apollo.startProgressReporting(
      itemId: _itemId,
      info: _info,
      positionTicks: () => _positionTicks(_player.state.position),
      isPaused: () => !_player.state.playing,
    );

    () async {
      try {
        await _apollo.reportPlaybackProgress(
          itemId: _itemId,
          info: _info,
          positionTicks: _positionTicks(_player.state.position),
          isPaused: !_player.state.playing,
          eventName: _player.state.playing ? 'Unpause' : 'Pause',
        );
      } catch (_) {}
    }();
  }

  Future<void> reportSeekCompleted() async {
    await _apollo.reportPlaybackProgress(
      itemId: _itemId,
      info: _info,
      positionTicks: _positionTicks(_player.state.position),
      isPaused: !_player.state.playing,
      eventName: 'timeupdate',
    );
  }

  Future<void> skipIntro() async {
    final endMs = _introEndMs;
    if (endMs == null || endMs <= 0) return;
    _introSkipped = true;
    showSkipIntro.value = false;
    await _player.seek(Duration(milliseconds: endMs));
    await reportSeekCompleted();
  }

  Future<void> playNextNow() async {
    final seriesId = _seriesId;
    if (seriesId == null || seriesId.isEmpty) {
      _debug('playNextNow blocked: seriesId missing');
      return;
    }
    _nextUpDismissed = true;
    nextUpCountdownSeconds.value = null;
    _nextUpTimer?.cancel();
    _nextUpTimer = null;
    try {
      await _apollo.markPlayed(_itemId);
    } catch (_) {}

    String? nextId;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        nextId = await _apollo.getNextUpEpisodeId(
          seriesId: seriesId,
          excludeItemId: _itemId,
        );
      } catch (_) {}
      if (nextId != null && nextId.isNotEmpty && nextId != _itemId) break;
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (nextId == null || nextId.isEmpty) {
      _debug('playNextNow aborted: no next episode id');
      return;
    }
    if (nextId == _itemId) {
      _debug('playNextNow aborted: nextId equals current itemId=$_itemId');
      return;
    }

    nextUpEpisodeId.value = nextId;
    _debug('playNextNow emitting nextEpisodeId=$nextId');
    stop();
    _playNextRequestedController.add(nextId);
  }

  void continueWatching() {
    _nextUpDismissed = true;
    nextUpCountdownSeconds.value = null;
    _nextUpTimer?.cancel();
    _nextUpTimer = null;
  }

  void stop() {
    _apollo.stopProgressReporting();
    _bufferingKeepAlive?.cancel();
    _bufferingKeepAlive = null;
    _nextUpTimer?.cancel();
    _nextUpTimer = null;
    _playingSub?.cancel();
    _playingSub = null;
    _bufferingSub?.cancel();
    _bufferingSub = null;
    _positionSub?.cancel();
    _positionSub = null;
    _durationSub?.cancel();
    _durationSub = null;
  }

  void dispose() {
    stop();
    showSkipIntro.dispose();
    nextUpCountdownSeconds.dispose();
    nextUpEpisodeId.dispose();
    _playNextRequestedController.close();
  }

  Future<void> _initializePlayback({
    required int? resumePositionMs,
    required int? subtitleStreamIndex,
    required int? audioStreamIndex,
  }) async {
    await _waitForMediaOpen();

    final ms = (resumePositionMs ?? 0).clamp(0, 1 << 31);
    await _player.play();
    await _waitForPlaybackStart();
    await _player.pause();

    if (ms > 0) {
      await _player.seek(Duration(milliseconds: ms));
    }

    await _applyTracks(
      subtitleStreamIndex: subtitleStreamIndex,
      audioStreamIndex: audioStreamIndex,
    );

    try {
      await _apollo.reportPlaybackStart(
        itemId: _itemId,
        info: _info,
        positionTicks: ms * 10000,
      );
    } catch (_) {}

    await _player.play();
  }

  void _handlePosition(Duration position) {
    final posMs = position.inMilliseconds;
    final start = _introStartMs;
    final end = _introEndMs;
    if (!_introSkipped && start != null && end != null && end > start) {
      final visible = (posMs + 500) >= start && posMs < end;
      if (showSkipIntro.value != visible) {
        showSkipIntro.value = visible;
        _debug('intro visible=$visible posMs=$posMs intro=[$start,$end]');
      }
    } else if (showSkipIntro.value) {
      showSkipIntro.value = false;
      _debug('intro visible=false posMs=$posMs intro=[$start,$end]');
    }

    final creditsStart = _creditsStartMs;
    if (_nextUpDismissed) return;
    if (creditsStart == null || creditsStart <= 0) return;
    if (posMs < creditsStart) return;
    if (nextUpCountdownSeconds.value != null) return;

    final seriesId = _seriesId;
    if (seriesId == null || seriesId.isEmpty) {
      if (!_debugLoggedNoSeriesId) {
        _debugLoggedNoSeriesId = true;
        _debug(
          'nextUp blocked seriesId missing posMs=$posMs creditsStartMs=$creditsStart itemId=$_itemId',
        );
      }
      return;
    }

    nextUpCountdownSeconds.value = 10;
    _debug('nextUp countdown started posMs=$posMs creditsStartMs=$creditsStart seriesId=$seriesId');
    _nextUpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = nextUpCountdownSeconds.value;
      if (current == null) {
        timer.cancel();
        return;
      }
      final next = current - 1;
      if (next <= 0) {
        timer.cancel();
        nextUpCountdownSeconds.value = null;
        () async {
          _debug('nextUp autoplay fired');
          await playNextNow();
        }();
      } else {
        nextUpCountdownSeconds.value = next;
      }
    });
  }

  void _debug(String message) {
    if (!kDebugMode) return;
    debugPrint('[PlaybackEngine] $message');
  }

  void _maybeSetCreditsFallback(Duration duration) {
    if ((_creditsStartMs ?? 0) > 0) return;
    final ms = duration.inMilliseconds;
    if (ms <= 0) return;
    if (ms <= 30000) return;
    _creditsStartMs = ms - 30000;
    _debug('credits fallback durationMs=$ms creditsStartMs=$_creditsStartMs');
  }


  Future<void> _waitForMediaOpen() async {
    try {
      await Future.any<void>([
        _player.stream.duration
            .firstWhere((d) => d != Duration.zero)
            .timeout(const Duration(seconds: 10))
            .then((_) {}),
        _player.stream.videoParams
            .firstWhere((v) => (v.w ?? 0) > 0 && (v.h ?? 0) > 0)
            .timeout(const Duration(seconds: 10))
            .then((_) {}),
      ]);
    } catch (_) {}
  }

  Future<void> _waitForPlaybackStart() async {
    if (_player.state.playing) return;
    try {
      await _player.stream.playing
          .firstWhere((playing) => playing)
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<void> _applyTracks({
    required int? subtitleStreamIndex,
    required int? audioStreamIndex,
  }) async {
    try {
      await _player.setAudioTrack(AudioTrack.no());
      await _player.setSubtitleTrack(SubtitleTrack.no());
    } catch (_) {}

    final audioMeta =
        audioStreamIndex == null ? null : _findAudioStream(audioStreamIndex);
    if (audioMeta != null) {
      final tracks = await _waitTracks();
      final audioTrack = _matchAudioTrack(
        tracks.audio,
        embyIndex: audioMeta.index,
        language: audioMeta.language,
        title: audioMeta.title,
      );
      if (audioTrack != null) {
        try {
          await _player.setAudioTrack(audioTrack);
        } catch (_) {}
      }
    }

    final subMeta = subtitleStreamIndex == null
        ? null
        : _findSubtitleStream(subtitleStreamIndex);
    if (subMeta == null) {
      try {
        await _player.setSubtitleTrack(SubtitleTrack.no());
      } catch (_) {}
      return;
    }

    if (subMeta.isExternal && (subMeta.deliveryUrl ?? '').isNotEmpty) {
      final uri = _resolveSubtitleUri(
        serverUrl: _info.serverUrl,
        accessToken: _info.streamUrl.queryParameters['api_key'] ?? '',
        deliveryUrl: subMeta.deliveryUrl!,
      );
      try {
        await _player.setSubtitleTrack(
          SubtitleTrack.uri(
            uri.toString(),
            title: subMeta.title,
            language: subMeta.language,
          ),
        );
      } catch (_) {}
      return;
    }

    final isImageBased = subMeta.isTextSubtitleStream == false ||
        (_norm(subMeta.codec).contains('pgs'));
    if (isImageBased) {
      await Future.delayed(const Duration(seconds: 1));
    }

    final updatedTracks = await _waitTracks();
    final subtitleTrack = _matchSubtitleTrack(
      updatedTracks.subtitle,
      embyIndex: subMeta.index,
      language: subMeta.language,
      title: subMeta.title,
    );
    if (subtitleTrack != null) {
      try {
        await _player.setSubtitleTrack(subtitleTrack);
      } catch (_) {}
    }
  }

  Future<Tracks> _waitTracks() async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    Tracks best = _player.state.tracks;

    while (DateTime.now().isBefore(deadline)) {
      try {
        final next = await _player.stream.tracks
            .firstWhere((t) => _hasUsableTracks(t))
            .timeout(const Duration(milliseconds: 600));
        if (_trackCount(next) >= _trackCount(best)) {
          best = next;
        }
      } catch (_) {
        break;
      }
    }

    return best;
  }

  bool _hasUsableTracks(Tracks tracks) {
    final audio = tracks.audio.where((t) => t.id != 'auto' && t.id != 'no');
    final subtitle =
        tracks.subtitle.where((t) => t.id != 'auto' && t.id != 'no');
    return audio.isNotEmpty || subtitle.isNotEmpty;
  }

  EmbyAudioStream? _findAudioStream(int index) {
    for (final s in _info.audioStreams) {
      if (s.index == index) return s;
    }
    return null;
  }

  EmbySubtitleStream? _findSubtitleStream(int index) {
    for (final s in _info.subtitleStreams) {
      if (s.index == index) return s;
    }
    return null;
  }

  int _trackCount(Tracks tracks) {
    final a = tracks.audio.where((t) => t.id != 'auto' && t.id != 'no').length;
    final s =
        tracks.subtitle.where((t) => t.id != 'auto' && t.id != 'no').length;
    return a + s;
  }
}

int _positionTicks(Duration position) {
  return position.inMilliseconds * 10000;
}

AudioTrack? _matchAudioTrack(
  List<AudioTrack> tracks, {
  required int embyIndex,
  required String? language,
  required String? title,
}) {
  final candidates =
      tracks.where((t) => t.id != 'auto' && t.id != 'no').toList(growable: false);
  if (candidates.isEmpty) return null;

  final titleNorm = _norm(title);
  final desiredLang = _normLang(language);

  final hasLanguageMatch = desiredLang.isNotEmpty &&
      candidates.any((t) => _normLang(t.language) == desiredLang);

  int score(AudioTrack t) {
    var s = 0;
    final actualLang = _normLang(t.language);
    if (hasLanguageMatch) {
      if (actualLang == desiredLang) {
        s += 1000;
      } else {
        s -= 1000;
      }
    }

    final tTitle = _norm(t.title);
    if (titleNorm.isNotEmpty &&
        tTitle.isNotEmpty &&
        (tTitle.contains(titleNorm) || titleNorm.contains(tTitle))) {
      s += 20;
    }

    if (t.id == embyIndex.toString()) s += 1;
    return s;
  }

  candidates.sort((a, b) => score(b).compareTo(score(a)));
  return candidates.first;
}

SubtitleTrack? _matchSubtitleTrack(
  List<SubtitleTrack> tracks, {
  required int embyIndex,
  required String? language,
  required String? title,
}) {
  final candidates = tracks
      .where((t) => t.id != 'auto' && t.id != 'no')
      .toList(growable: false);
  if (candidates.isEmpty) return null;

  final titleNorm = _norm(title);
  final desiredLang = _normLang(language);

  final hasLanguageMatch = desiredLang.isNotEmpty &&
      candidates.any((t) => _normLang(t.language) == desiredLang);

  int score(SubtitleTrack t) {
    var s = 0;
    final actualLang = _normLang(t.language);
    if (hasLanguageMatch) {
      if (actualLang == desiredLang) {
        s += 1000;
      } else {
        s -= 1000;
      }
    }

    final tTitle = _norm(t.title);
    if (titleNorm.isNotEmpty &&
        tTitle.isNotEmpty &&
        (tTitle.contains(titleNorm) || titleNorm.contains(tTitle))) {
      s += 20;
    }

    if (t.id == embyIndex.toString()) s += 1;
    return s;
  }

  candidates.sort((a, b) => score(b).compareTo(score(a)));
  return candidates.first;
}

String _norm(String? value) => (value ?? '').toLowerCase().trim();

String _normLang(String? language) {
  final v = _norm(language);
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

Uri _resolveSubtitleUri({
  required Uri serverUrl,
  required String accessToken,
  required String deliveryUrl,
}) {
  final parsed = Uri.parse(deliveryUrl);
  final resolved = parsed.hasScheme ? parsed : serverUrl.resolveUri(parsed);
  return resolved.replace(
    queryParameters: {
      ...resolved.queryParameters,
      'api_key': resolved.queryParameters['api_key'] ?? accessToken,
    },
  );
}
