import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tv_media3/flutter_tv_media3.dart';

import '../../core/emby/models/emby_media_stream.dart';
import '../../core/emby/models/emby_playback_info.dart';
import 'apollo_service.dart';

/// Bridges flutter_tv_media3's ExoPlayer controller to the Emby session
/// reporting layer (ApolloService). Handles converting Emby data into
/// PlaylistMediaItem format and wiring playback state events to Emby
/// progress/start/stop reports. Also manages skip-intro, credits detection,
/// and next-up countdown for TV playback.
final class TvPlaybackBridge {
  TvPlaybackBridge({
    required this.apollo,
  });

  final ApolloService apollo;

  final FtvMedia3PlayerController controller = FtvMedia3PlayerController();

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<PlaybackState>? _playbackSub;
  Timer? _nextUpTimer;

  String? _currentItemId;
  EmbyPlaybackInfo? _currentInfo;

  // --- Intro / Credits / Next-up state ---
  int? _introStartMs;
  int? _introEndMs;
  int? _creditsStartMs;
  String? _seriesId;
  bool _introSkipped = false;
  bool _nextUpDismissed = false;

  bool _loggedNextUpNoSeries = false;
  bool _loggedNextUpNoDuration = false;

  final ValueNotifier<bool> showSkipIntro = ValueNotifier<bool>(false);
  final ValueNotifier<int?> nextUpCountdownSeconds = ValueNotifier<int?>(null);
  final ValueNotifier<String?> nextUpEpisodeId = ValueNotifier<String?>(null);

  final StreamController<String> _playNextRequestedController =
      StreamController<String>.broadcast();
  Stream<String> get playNextRequested => _playNextRequestedController.stream;

  StreamSubscription<String>? _overlayActionSub;

  // --- Still watching state ---
  static const int stillWatchingThreshold = 3;
  int _consecutiveAutoPlays = 0;
  final ValueNotifier<bool> showStillWatching = ValueNotifier<bool>(false);

  // --- Initial track selection state ---
  EmbySubtitleStream? _pendingSubtitle;
  bool _initialTrackSelectionDone = false;

  /// Request that the bridge auto-selects the given embedded subtitle track
  /// once ExoPlayer has finished parsing media tracks.
  void setInitialTrackSelection({EmbySubtitleStream? subtitle}) {
    _pendingSubtitle = subtitle;
    _initialTrackSelectionDone = false;
  }

  /// Build a [PlaylistMediaItem] from Emby data for the TV ExoPlayer.
  PlaylistMediaItem buildMediaItem({
    required String itemId,
    required String title,
    required EmbyPlaybackInfo info,
    required int startPositionTicks,
    String? subtitle,
    String? thumbnailUrl,
  }) {
    final streamUrl = info.streamUrl.toString();

    final subtitles = <MediaItemSubtitle>[];
    for (final sub in info.subtitleStreams) {
      if (!sub.isExternal) continue;
      final url = sub.deliveryUrl;
      if (url == null || url.isEmpty) continue;
      final resolvedUrl = _resolveSubtitleUrl(info, url);
      subtitles.add(MediaItemSubtitle(
        url: resolvedUrl,
        language: sub.language ?? '',
        label: sub.title ?? sub.language ?? 'Track ${sub.index}',
        mimeType: _embySubtitleMime(sub),
      ));
    }

    final audioLabels = <String, String>{};
    for (final audio in info.audioStreams) {
      final label = _buildAudioLabel(audio);
      audioLabels[audio.index.toString()] = label;
    }

    return PlaylistMediaItem(
      id: itemId,
      url: streamUrl,
      title: title,
      subTitle: subtitle,
      episodeImg: thumbnailUrl,
      placeholderImg: thumbnailUrl,
      startPosition: startPositionTicks > 0
          ? (startPositionTicks ~/ 10000000)
          : null,
      audioTrackLabels: audioLabels.isNotEmpty ? audioLabels : null,
      subtitles: subtitles.isNotEmpty ? subtitles : null,
      saveWatchTime: _buildSaveWatchTime(itemId, info),
    );
  }

  /// Configure intro/credits/next-up parameters. Call after [startReporting].
  void configureSegments({
    int? introStartMs,
    int? introEndMs,
    int? creditsStartMs,
    String? seriesId,
    int? durationMs,
  }) {
    _introStartMs = introStartMs;
    _introEndMs = introEndMs;
    _creditsStartMs = creditsStartMs;
    _seriesId = seriesId;
    _introSkipped = false;
    _nextUpDismissed = false;

    if ((_creditsStartMs ?? 0) <= 0 && durationMs != null && durationMs > 30000) {
      // Fallback: trigger ~90 s before end so the countdown lands inside the
      // typical credits window (most TV shows start credits 1-4 min from end).
      _creditsStartMs = durationMs - 90000;
    }

    if (seriesId != null && seriesId.isNotEmpty) {
      _prefetchNextUp(seriesId);
    } else {
      debugPrint(
        '[TvPlaybackBridge] configureSegments: empty seriesId; Play Next countdown will not start',
      );
    }

    _loggedNextUpNoSeries = false;
    _loggedNextUpNoDuration = false;
  }

  /// Skip the intro and seek to its end.
  Future<void> skipIntro() async {
    final endMs = _introEndMs;
    if (endMs == null || endMs <= 0) return;
    _introSkipped = true;
    showSkipIntro.value = false;
    controller.seekTo(positionSeconds: endMs ~/ 1000);
  }

  /// Immediately play the next episode.
  Future<void> playNextNow() async {
    final seriesId = _seriesId;
    if (seriesId == null || seriesId.isEmpty) return;
    _nextUpDismissed = true;
    nextUpCountdownSeconds.value = null;
    _nextUpTimer?.cancel();
    _nextUpTimer = null;

    _consecutiveAutoPlays++;
    if (_consecutiveAutoPlays >= stillWatchingThreshold) {
      showStillWatching.value = true;
      return;
    }

    try { await apollo.markPlayed(_currentItemId!); } catch (_) {}

    String? nextId;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        nextId = await apollo.getNextUpEpisodeId(
          seriesId: seriesId,
          excludeItemId: _currentItemId,
        );
      } catch (_) {}
      if (nextId != null && nextId.isNotEmpty && nextId != _currentItemId) break;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (nextId == null || nextId.isEmpty || nextId == _currentItemId) return;

    nextUpEpisodeId.value = nextId;
    _playNextRequestedController.add(nextId);
  }

  /// Dismiss the next-up countdown.
  void continueWatching() {
    _nextUpDismissed = true;
    nextUpCountdownSeconds.value = null;
    _nextUpTimer?.cancel();
    _nextUpTimer = null;
  }

  /// Acknowledge the "still watching?" prompt, reset the counter,
  /// and resume the next-episode transition.
  Future<void> confirmStillWatching() async {
    _consecutiveAutoPlays = 0;
    showStillWatching.value = false;

    try { await apollo.markPlayed(_currentItemId!); } catch (_) {}

    final seriesId = _seriesId;
    if (seriesId == null || seriesId.isEmpty) return;

    String? nextId;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        nextId = await apollo.getNextUpEpisodeId(
          seriesId: seriesId,
          excludeItemId: _currentItemId,
        );
      } catch (_) {}
      if (nextId != null && nextId.isNotEmpty && nextId != _currentItemId) break;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (nextId == null || nextId.isEmpty || nextId == _currentItemId) return;

    nextUpEpisodeId.value = nextId;
    _playNextRequestedController.add(nextId);
  }

  /// Decline the "still watching?" prompt — stop playback.
  void declineStillWatching() {
    showStillWatching.value = false;
    controller.stop();
  }

  /// Queue a new episode into the existing player without restarting the Activity.
  /// Returns the new playlist index, or null if queueing failed.
  Future<int?> queueAndPlayNext({
    required PlaylistMediaItem mediaItem,
    required String itemId,
    required EmbyPlaybackInfo info,
    int? introStartMs,
    int? introEndMs,
    int? creditsStartMs,
    String? seriesId,
    int? durationMs,
  }) async {
    try {
      await stopReporting();

      await controller.addMediaItems(items: [mediaItem]);
      final newIndex = controller.playerState.playlist.length - 1;
      await controller.playSelectedIndex(index: newIndex);

      startReporting(itemId: itemId, info: info);
      configureSegments(
        introStartMs: introStartMs,
        introEndMs: introEndMs,
        creditsStartMs: creditsStartMs,
        seriesId: seriesId,
        durationMs: durationMs,
      );

      return newIndex;
    } catch (e) {
      if (kDebugMode) debugPrint('[TvPlaybackBridge] queueAndPlayNext error: $e');
      return null;
    }
  }

  /// Start Emby session reporting.
  ///
  /// Mirrors the desktop [PlaybackEngine] pattern: explicitly reports playback
  /// start to Emby and uses [ApolloService.startProgressReporting] for the
  /// periodic keepalive instead of relying on native stream events.
  void startReporting({
    required String itemId,
    required EmbyPlaybackInfo info,
    int startPositionTicks = 0,
  }) {
    _currentItemId = itemId;
    _currentInfo = info;
    _lastPositionTicks = startPositionTicks;
    _lastIsPaused = false;
    _hasReceivedFirstPosition = false;

    apollo.reportPlaybackStart(
      itemId: itemId,
      info: info,
      positionTicks: startPositionTicks,
    ).catchError((_) {});

    apollo.startProgressReporting(
      itemId: itemId,
      info: info,
      positionTicks: () => _lastPositionTicks,
      isPaused: () => _lastIsPaused,
    );

    _stateSub?.cancel();
    _stateSub = controller.playerStateStream.listen(_onPlayerStateChanged);

    _playbackSub?.cancel();
    _playbackSub = controller.playbackStateStream.listen(_onPlaybackState);

    _overlayActionSub?.cancel();
    _overlayActionSub = controller.overlayActionTriggered.listen(_onOverlayAction);

    showSkipIntro.addListener(_syncActionButton);
    nextUpCountdownSeconds.addListener(_syncActionButton);
    showStillWatching.addListener(_syncActionButton);
  }

  /// Report playback stopped and clean up listeners.
  Future<void> stopReporting() async {
    _stateSub?.cancel();
    _stateSub = null;
    _playbackSub?.cancel();
    _playbackSub = null;
    _overlayActionSub?.cancel();
    _overlayActionSub = null;
    showSkipIntro.removeListener(_syncActionButton);
    nextUpCountdownSeconds.removeListener(_syncActionButton);
    showStillWatching.removeListener(_syncActionButton);
    apollo.stopProgressReporting();
    _nextUpTimer?.cancel();
    _nextUpTimer = null;

    showSkipIntro.value = false;
    nextUpCountdownSeconds.value = null;
    showStillWatching.value = false;
    _introSkipped = false;
    _nextUpDismissed = false;
    controller.clearActionButton().catchError((_) {});

    final itemId = _currentItemId;
    final info = _currentInfo;
    if (itemId != null && info != null) {
      debugPrint('[TvPlaybackBridge] reportStopped: item=$itemId, positionTicks=$_lastPositionTicks');
      try {
        await apollo.reportStopped(
          itemId: itemId,
          info: info,
          positionTicks: _lastPositionTicks,
        );
        debugPrint('[TvPlaybackBridge] reportStopped: success');
      } catch (e) {
        debugPrint('[TvPlaybackBridge] reportStopped failed: $e');
      }
    }

    _currentItemId = null;
    _currentInfo = null;
  }

  void dispose() {
    _stateSub?.cancel();
    _playbackSub?.cancel();
    _overlayActionSub?.cancel();
    apollo.stopProgressReporting();
    _nextUpTimer?.cancel();
    showSkipIntro.dispose();
    nextUpCountdownSeconds.dispose();
    nextUpEpisodeId.dispose();
    showStillWatching.dispose();
    _playNextRequestedController.close();
  }

  // --- Private ---

  int _lastPositionTicks = 0;
  bool _lastIsPaused = true;

  void _syncActionButton() {
    if (showStillWatching.value) {
      controller.setActionButton(id: 'still_watching', label: 'Still Watching?').catchError((_) {});
      return;
    }
    if (showSkipIntro.value) {
      controller.setActionButton(id: 'skip_intro', label: 'Skip Intro').catchError((_) {});
      return;
    }
    final countdown = nextUpCountdownSeconds.value;
    if (countdown != null) {
      controller.setActionButton(id: 'play_next', label: 'Play Next (${countdown}s)').catchError((_) {});
      return;
    }
    controller.clearActionButton().catchError((_) {});
  }

  void _onOverlayAction(String actionId) {
    switch (actionId) {
      case 'skip_intro':
        skipIntro();
        break;
      case 'play_next':
        playNextNow();
        break;
      case 'still_watching':
        confirmStillWatching();
        break;
    }
  }

  void _onPlayerStateChanged(PlayerState state) {
    if (_currentItemId == null || _currentInfo == null) return;
    _lastIsPaused = state.stateValue != StateValue.playing;
    if (!_initialTrackSelectionDone) {
      _tryInitialTrackSelection(state);
    }
  }

  void _tryInitialTrackSelection(PlayerState state) {
    final subTracks = state.subtitleTracks;
    if (subTracks.isEmpty) return;
    _initialTrackSelectionDone = true;

    final desired = _pendingSubtitle;
    _pendingSubtitle = null;
    if (desired == null) return;

    if (desired.isExternal) return;

    final match = _matchEmbeddedSubtitle(desired, subTracks);
    if (match != null) {
      debugPrint('[TvPlaybackBridge] Auto-selecting subtitle: ${match.label}');
      controller.selectSubtitleTrack(track: match);
    }
  }

  /// Returns the ISO-639-1 language code of the subtitle track that is
  /// currently selected in the player, or null if none is active.
  ///
  /// Reads the live [controller.playerState] so it reflects manual track
  /// changes the user makes through the overlay UI.  Falls back to the
  /// language of [_pendingSubtitle] if ExoPlayer tracks aren't available yet.
  String? get currentSubtitleLanguage {
    final selected = controller.playerState.subtitleTracks
        .where((t) => t.isSelected && !t.isExternal)
        .map((t) => _normLang(t.language))
        .where((l) => l.isNotEmpty)
        .firstOrNull;
    if (selected != null) return selected;
    final pending = _normLang(_pendingSubtitle?.language);
    return pending.isNotEmpty ? pending : null;
  }

  /// Picks the best [EmbySubtitleStream] from [streams] for [preferredLang].
  ///
  /// Priority: exact language match → English fallback → null.
  /// External (delivery) streams are included so they work the same way as
  /// embedded ones do on the first episode.
  EmbySubtitleStream? pickSubtitleForLanguage(
    List<EmbySubtitleStream> streams,
    String? preferredLang,
  ) {
    if (streams.isEmpty) return null;
    final want = _normLang(preferredLang);

    EmbySubtitleStream? exactMatch;
    EmbySubtitleStream? englishMatch;
    for (final s in streams) {
      final lang = _normLang(s.language);
      if (want.isNotEmpty && lang == want) {
        exactMatch ??= s;
      }
      if (lang == 'en') {
        englishMatch ??= s;
      }
    }
    return exactMatch ?? englishMatch;
  }

  SubtitleTrack? _matchEmbeddedSubtitle(
    EmbySubtitleStream desired,
    List<SubtitleTrack> tracks,
  ) {
    final desiredLang = _normLang(desired.language);
    final desiredTitle = (desired.title ?? '').toLowerCase().trim();

    SubtitleTrack? langMatch;
    for (final track in tracks) {
      if (track.isExternal) continue;
      final trackLabel = (track.label ?? '').toLowerCase().trim();

      if (desiredTitle.isNotEmpty && trackLabel == desiredTitle) return track;

      final trackLang = _normLang(track.language);
      if (desiredLang.isNotEmpty && trackLang == desiredLang) {
        langMatch ??= track;
      }
    }
    return langMatch;
  }

  static String _normLang(String? language) {
    final v = (language ?? '').toLowerCase().trim();
    if (v.isEmpty) return '';
    final base = v.split(RegExp('[_-]')).first.replaceAll(RegExp(r'[^a-z]'), '');
    if (base.isEmpty) return '';
    const iso3To2 = <String, String>{
      'ron': 'ro', 'rum': 'ro', 'eng': 'en', 'fre': 'fr', 'fra': 'fr',
      'ger': 'de', 'deu': 'de', 'spa': 'es', 'ita': 'it', 'por': 'pt',
      'jpn': 'ja', 'chi': 'zh', 'zho': 'zh', 'dut': 'nl', 'nld': 'nl',
      'nor': 'no', 'dan': 'da', 'fin': 'fi', 'swe': 'sv', 'pol': 'pl',
      'rus': 'ru', 'ukr': 'uk',
    };
    return iso3To2[base] ?? (base.length >= 2 ? base.substring(0, 2) : base);
  }

  bool _hasReceivedFirstPosition = false;

  void _onPlaybackState(PlaybackState state) {
    final posSec = state.position;
    _lastPositionTicks = posSec * 10000000;
    if (!_hasReceivedFirstPosition && posSec > 0) {
      _hasReceivedFirstPosition = true;
      debugPrint('[TvPlaybackBridge] First position: ${posSec}s');
    }
    final posMs = posSec * 1000;
    final durationMs = state.duration * 1000;
    _checkIntroOverlay(posMs);
    _checkCreditsAndNextUp(posMs, durationMs);
  }

  SaveWatchTimeSeconds _buildSaveWatchTime(
    String itemId,
    EmbyPlaybackInfo info,
  ) {
    return ({
      required String id,
      required int duration,
      required int position,
      required int playIndex,
    }) async {
      _lastPositionTicks = position * 10000000;
      try {
        await apollo.reportPlaybackProgress(
          itemId: itemId,
          info: info,
          positionTicks: _lastPositionTicks,
          isPaused: false,
          eventName: 'timeupdate',
        );
      } catch (e) {
        if (kDebugMode) debugPrint('[TvPlaybackBridge] saveWatchTime error: $e');
      }
    };
  }

  String _resolveSubtitleUrl(EmbyPlaybackInfo info, String deliveryUrl) {
    final parsed = Uri.parse(deliveryUrl);
    final resolved = parsed.hasScheme
        ? parsed
        : info.serverUrl.resolveUri(parsed);
    final accessToken = info.streamUrl.queryParameters['api_key'] ?? '';
    if (accessToken.isNotEmpty) {
      return resolved.replace(
        queryParameters: {
          ...resolved.queryParameters,
          'api_key': accessToken,
        },
      ).toString();
    }
    return resolved.toString();
  }

  /// Maps Emby subtitle codec hints to MIME types understood by ExoPlayer / Media3.
  String? _embySubtitleMime(EmbySubtitleStream sub) {
    final codec = (sub.codec ?? '').toLowerCase();
    if (codec.contains('ssa') || codec.contains('ass')) {
      return 'text/x-ssa';
    }
    if (codec.contains('subrip') || codec == 'srt') {
      return 'application/x-subrip';
    }
    if (codec.contains('vtt') || codec.contains('webvtt')) {
      return 'text/vtt';
    }
    return null;
  }

  String _buildAudioLabel(EmbyAudioStream audio) {
    final parts = <String>[];
    if (audio.title != null && audio.title!.isNotEmpty) {
      parts.add(audio.title!);
    } else if (audio.language != null && audio.language!.isNotEmpty) {
      parts.add(audio.language!);
    }
    if (audio.codec != null && audio.codec!.isNotEmpty) {
      parts.add(audio.codec!.toUpperCase());
    }
    if (audio.channels != null && audio.channels! > 0) {
      parts.add(_channelLabel(audio.channels!));
    }
    return parts.isNotEmpty ? parts.join(' - ') : 'Track ${audio.index}';
  }

  String _channelLabel(int channels) {
    return switch (channels) {
      1 => 'Mono',
      2 => 'Stereo',
      6 => '5.1',
      8 => '7.1',
      _ => '${channels}ch',
    };
  }

  // --- Intro / Credits / Next-up helpers ---

  void _checkIntroOverlay(int positionMs) {
    final end = _introEndMs;
    if (end != null && end > 0 && positionMs >= end) {
      if (showSkipIntro.value && kDebugMode) {
        debugPrint(
          '[TvPlaybackBridge] intro ended: clearing skip chip posMs=$positionMs endMs=$end',
        );
      }
      showSkipIntro.value = false;
      _introSkipped = true;
      return;
    }

    if (_introSkipped) return;

    final start = _introStartMs;
    if (start == null || end == null || end <= start) return;

    final inIntro = (positionMs + 500) >= start && positionMs < end;
    final wasShowing = showSkipIntro.value;
    if (showSkipIntro.value != inIntro) {
      showSkipIntro.value = inIntro;
      if (kDebugMode && wasShowing != inIntro) {
        debugPrint(
          '[TvPlaybackBridge] skip intro visibility inIntro=$inIntro posMs=$positionMs start=$start end=$end',
        );
      }
    }
  }

  static const _nextUpCountdownDuration = 10;

  void _checkCreditsAndNextUp(int positionMs, int durationMs) {
    if (_nextUpDismissed) return;
    final creditsMs = _creditsStartMs;
    if (creditsMs == null || creditsMs <= 0) return;
    if (positionMs < creditsMs) return;

    if (durationMs <= 0) {
      if (!_loggedNextUpNoDuration) {
        _loggedNextUpNoDuration = true;
        debugPrint(
          '[TvPlaybackBridge] Play Next: duration not ready yet (durationMs=0) at posMs=$positionMs',
        );
      }
      return;
    }
    if (_seriesId == null || _seriesId!.isEmpty) {
      if (!_loggedNextUpNoSeries) {
        _loggedNextUpNoSeries = true;
        debugPrint(
          '[TvPlaybackBridge] Play Next: missing seriesId at credits (posMs=$positionMs)',
        );
      }
      return;
    }

    if (_nextUpTimer == null) {
      _startNextUpCountdown(_nextUpCountdownDuration);
    }
  }

  void _startNextUpCountdown(int totalSeconds) {
    if (_nextUpDismissed) return;
    var remaining = totalSeconds;
    nextUpCountdownSeconds.value = remaining;

    _nextUpTimer?.cancel();
    _nextUpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      if (remaining <= 0 || _nextUpDismissed) {
        timer.cancel();
        _nextUpTimer = null;
        if (!_nextUpDismissed && remaining <= 0) {
          playNextNow();
        }
        return;
      }
      nextUpCountdownSeconds.value = remaining;
    });
  }

  Future<void> _prefetchNextUp(String seriesId) async {
    try {
      final nextId = await apollo.getNextUpEpisodeId(
        seriesId: seriesId,
        excludeItemId: _currentItemId,
      );
      if (nextId != null && nextId.isNotEmpty && nextId != _currentItemId) {
        nextUpEpisodeId.value = nextId;
      }
    } catch (_) {}
  }
}
