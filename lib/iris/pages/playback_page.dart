import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../app/app.dart';
import '../../app/services/app_services.dart';
import '../../core/emby/models/emby_item.dart';
import '../../core/emby/models/emby_media_stream.dart';
import '../../core/emby/models/emby_playback_info.dart';
import '../../l10n/l10n.dart';
import '../../services/apollo/playback_engine.dart';
import '../player/playback_prefs.dart';
import '../player/subtitle_prefs.dart';
import '../widgets/ott_shimmer.dart';

enum _AspectMode {
  fit,
  cover,
  fill,
  ratio16x9,
  ratio4x3,
}

final class PlaybackArgs {
  const PlaybackArgs({
    required this.item,
    required this.playbackInfo,
    required this.startPositionTicks,
    required this.selectedAudio,
    required this.selectedSubtitle,
    this.startFullscreen = false,
  });

  final EmbyItem item;
  final EmbyPlaybackInfo playbackInfo;
  final int startPositionTicks;
  final EmbyAudioStream selectedAudio;
  final EmbySubtitleStream? selectedSubtitle;
  final bool startFullscreen;
}

final class PlaybackPage extends StatefulWidget {
  const PlaybackPage({
    super.key,
    required this.itemId,
    required this.args,
  });

  final String itemId;
  final PlaybackArgs? args;

  @override
  State<PlaybackPage> createState() => _PlaybackPageState();
}

final class _PlaybackPageState extends State<PlaybackPage> with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _controller;

  AppServices? _services;
  PlaybackEngine? _engine;
  StreamSubscription<String>? _playNextSub;
  StreamSubscription<double>? _volumeSub;
  Timer? _volumeSaveDebounce;
  PlaybackPrefs? _playbackPrefs;
  EmbyItem? _item;
  EmbyPlaybackInfo? _info;
  ValueNotifier<SubtitlePrefs>? _subtitlePrefs;
  Object? _error;
  bool _started = false;
  bool _preparing = true;
  bool _loadingNext = false;
  bool _isFullscreen = false;
  double? _seekingSeconds;
  final ValueNotifier<bool> _controlsVisible = ValueNotifier<bool>(true);
  final ValueNotifier<_AspectMode> _aspectMode = ValueNotifier<_AspectMode>(_AspectMode.fit);
  Timer? _controlsHideTimer;
  bool _reportedStopped = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(
      _player,
      configuration: _isWindows
          ? const VideoControllerConfiguration(hwdec: 'd3d11va')
          : const VideoControllerConfiguration(),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _services ??= AppServicesScope.of(context);
    if (_started) return;
    _started = true;
    _start();
  }

  Future<void> _start() async {
    try {
      final services = _services!;
      final prefs = ValueNotifier(await SubtitlePrefs.load());
      _subtitlePrefs = prefs;
      final playbackPrefs = await PlaybackPrefs.load();
      _playbackPrefs = playbackPrefs;

      final args = widget.args;
      final startFullscreen = args?.startFullscreen ?? false;
      final item = args?.item ?? await services.hermes.getItem(widget.itemId);
      final info = args?.playbackInfo ??
          await services.apollo.getPlaybackInfo(
            item.id,
            maxStreamingBitrate: playbackPrefs.maxStreamingBitrate(),
          );
      final selectedAudio = args?.selectedAudio ?? playbackPrefs.pickAudio(info.audioStreams);
      final selectedSubtitle =
          args?.selectedSubtitle ?? playbackPrefs.pickSubtitle(info.subtitleStreams);
      final startTicks = args?.startPositionTicks ?? (item.playbackPositionTicks ?? 0);

      if (selectedAudio == null) {
        throw StateError('No audio tracks available for playback.');
      }

      if (!mounted) return;
      AppUiScope.of(context).lastPlaybackItemId.value = item.id;
      setState(() {
        _item = item;
        _info = info;
      });

      await _player.open(
        Media(playbackPrefs.pickStreamUrl(info).toString()),
        play: false,
      );
      await _prepareMpvForPlayback();
      try {
        await _player.setVolume(playbackPrefs.volume);
      } catch (_) {}
      _volumeSub ??= _player.stream.volume.listen(_onVolumeChanged);

      final engine = PlaybackEngine(
        apollo: services.apollo,
        player: _player,
        itemId: item.id,
        info: info,
      );
      _engine = engine;
      _playNextSub = engine.playNextRequested.listen((nextItemId) async {
        final services = _services;
        if (services == null) return;

        try {
          if (mounted) setState(() => _loadingNext = true);
          final nextItem = await services.hermes.getItem(nextItemId);
          final nextPlaybackInfo = await services.apollo.getPlaybackInfo(
            nextItemId,
            maxStreamingBitrate: playbackPrefs.maxStreamingBitrate(),
          );

          final nextAudio = (playbackPrefs.audioLanguage.trim().isEmpty)
              ? _pickNextAudio(
                  nextPlaybackInfo: nextPlaybackInfo,
                  preferred: selectedAudio,
                )
              : (playbackPrefs.pickAudio(nextPlaybackInfo.audioStreams) ?? selectedAudio);
          final nextSubtitle = (playbackPrefs.subtitleMode == SubtitlePreferenceMode.auto)
              ? _pickNextSubtitle(
                  nextPlaybackInfo: nextPlaybackInfo,
                  preferred: selectedSubtitle,
                )
              : playbackPrefs.pickSubtitle(nextPlaybackInfo.subtitleStreams);

          if (!mounted) return;
          AppUiScope.of(context).lastPlaybackItemId.value = nextItem.id;
          context.pushReplacement(
            '/play/${nextItem.id}',
            extra: PlaybackArgs(
              item: nextItem,
              playbackInfo: nextPlaybackInfo,
              startPositionTicks: 0,
              selectedAudio: nextAudio,
              selectedSubtitle: nextSubtitle,
              startFullscreen: _isFullscreen,
            ),
          );
        } catch (_) {
        } finally {
          if (mounted) setState(() => _loadingNext = false);
        }
      });
      await engine.start(
        resumePositionMs: startTicks > 0 ? startTicks ~/ 10000 : null,
        audioStreamIndex: selectedAudio.index,
        subtitleStreamIndex: selectedSubtitle?.index,
        introStartMs: item.introStartTicks == null
            ? null
            : item.introStartTicks! ~/ 10000,
        introEndMs:
            item.introEndTicks == null ? null : item.introEndTicks! ~/ 10000,
        creditsStartMs: item.creditsStartTicks == null
            ? null
            : item.creditsStartTicks! ~/ 10000,
        seriesId: item.type == 'Episode' ? item.seriesId : null,
      );
      if (mounted) {
        setState(() => _preparing = false);
        _markUserActivity();
      }
      if (startFullscreen && mounted && !_isFullscreen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _isFullscreen) return;
          _enterFullscreen(item: item, prefs: prefs);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _prepareMpvForPlayback() async {
    if (!_isWindows) return;
    final platform = _player.platform;
    if (platform == null) return;
    try {
      final dynamic p = platform;
      await p.setProperty('hwdec', 'd3d11va');
      await p.setProperty('video-sync', 'display-resample');
      await p.setProperty('gpu-api', 'd3d11');
      await p.setProperty('interpolation', 'yes');
    } catch (_) {}
  }

  bool get _isWindows => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Future<void> _onPointerSignal(PointerSignalEvent event) async {
    _markUserActivity();
    if (event is! PointerScrollEvent) return;
    final delta = event.scrollDelta.dy;
    if (delta == 0) return;
    final current = _player.state.volume;
    final step = delta > 0 ? -4.0 : 4.0;
    final next = (current + step).clamp(0.0, 100.0);
    try {
      await _player.setVolume(next);
    } catch (_) {}
    _showVolumeHud(next);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playNextSub?.cancel();
    _playNextSub = null;
    _volumeSub?.cancel();
    _volumeSub = null;
    _volumeSaveDebounce?.cancel();
    _volumeSaveDebounce = null;
    _controlsHideTimer?.cancel();
    _controlsHideTimer = null;
    _engine?.dispose();
    _reportStoppedIfNeeded();
    _subtitlePrefs?.dispose();
    _controlsVisible.dispose();
    _aspectMode.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached || state == AppLifecycleState.paused) {
      _reportStoppedIfNeeded();
    }
  }

  void _reportStoppedIfNeeded() {
    if (_reportedStopped) return;
    final services = _services;
    final info = _info;
    final item = _item;
    if (services == null || info == null || item == null) return;
    _reportedStopped = true;
    try {
      services.apollo.stopProgressReporting();
    } catch (_) {}
    () async {
      try {
        await services.apollo.reportStopped(
          itemId: item.id,
          info: info,
          positionTicks: _positionTicks(_player.state.position),
        );
      } catch (_) {}
    }();
  }

  void _markUserActivity() {
    if (!mounted) return;
    if (!_controlsVisible.value) {
      _controlsVisible.value = true;
    }
    _controlsHideTimer?.cancel();
    if (_preparing) return;
    if (_seekingSeconds != null) return;
    _controlsHideTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (_seekingSeconds != null) return;
      _controlsVisible.value = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.playback)),
        body: Center(child: Text('$error')),
      );
    }

    final item = _item;
    final prefs = _subtitlePrefs;
    if (item == null || prefs == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _exitToUi(itemId: item.id);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _withPlaybackShortcuts(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _markUserActivity(),
            onPointerMove: (_) => _markUserActivity(),
            onPointerSignal: _onPointerSignal,
            child: MouseRegion(
              onHover: (_) => _markUserActivity(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!_isFullscreen)
                    ValueListenableBuilder<_AspectMode>(
                      valueListenable: _aspectMode,
                      builder: (context, mode, _) {
                        final (fit, aspectRatio) = _aspectParams(mode);
                        return Video(
                          controller: _controller,
                          fit: fit,
                          aspectRatio: aspectRatio,
                          controls: NoVideoControls,
                          subtitleViewConfiguration:
                              const SubtitleViewConfiguration(visible: false),
                        );
                      },
                    )
                  else
                    const ColoredBox(color: Colors.black),
                  if (!_isFullscreen)
                    Positioned.fill(
                      child: _PlayerInputLayer(
                        player: _player,
                        onToggleFullscreen: () => _enterFullscreen(item: item, prefs: prefs),
                      ),
                    ),
                  if (_preparing) const Center(child: CircularProgressIndicator()),
                  _SubtitleOverlay(player: _player, prefs: prefs),
                  Positioned(
                    right: 16,
                    bottom: 132,
                    child: _PlaybackOverlays(
                      engine: _engine,
                      loadingNext: _loadingNext,
                      services: _services,
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _controlsVisible,
                    builder: (context, visible, _) {
                      return IgnorePointer(
                        ignoring: !visible,
                        child: AnimatedOpacity(
                          opacity: visible ? 1 : 0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (!_isFullscreen)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  child: SafeArea(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 8, top: 8),
                                      child: _TopNavControls(
                                        onBack: () => _exitToUi(itemId: item.id),
                                        onHome: () => _exitToHome(itemId: item.id),
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: _BottomControlsBar(
                                  player: _player,
                                  engine: _engine,
                                  prefs: prefs,
                                  seekingSeconds: _seekingSeconds,
                                  onSeekingSecondsChanged: (v) {
                                    setState(() => _seekingSeconds = v);
                                    _markUserActivity();
                                  },
                                  onSeekCommitted: () {
                                    setState(() => _seekingSeconds = null);
                                    _markUserActivity();
                                  },
                                  onShowAspectRatio: () =>
                                      _showAspectRatioPicker(context, _aspectMode),
                                  onToggleFullscreen: () =>
                                      _enterFullscreen(item: item, prefs: prefs),
                                  isFullscreen: false,
                                  controlsVisible: visible,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _exitToUi({required String itemId}) {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final lastId = AppUiScope.of(context).lastPlaybackItemId.value ?? itemId;
    final router = GoRouter.of(rootNavigator.context);

    if (_isFullscreen) {
      rootNavigator.pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (rootNavigator.canPop()) {
          rootNavigator.pop();
        } else {
          router.go('/details/$lastId');
        }
      });
      return;
    }

    if (rootNavigator.canPop()) {
      rootNavigator.pop();
    } else {
      router.go('/details/$lastId');
    }
  }

  void _exitToHome({required String itemId}) {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    if (_isFullscreen) {
      rootNavigator.pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        rootNavigator.pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final router = GoRouter.of(rootNavigator.context);
          router.go('/');
        });
      });
      return;
    }

    rootNavigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = GoRouter.of(rootNavigator.context);
      router.go('/');
    });
  }

  Future<void> _enterFullscreen({
    required EmbyItem item,
    required ValueNotifier<SubtitlePrefs> prefs,
  }) async {
    if (_isFullscreen) return;
    if (!mounted) return;
    var nativeEntered = false;
    setState(() => _isFullscreen = true);
    _markUserActivity();
    try {
      await defaultEnterNativeFullscreen();
      nativeEntered = true;
      if (!mounted) return;
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          opaque: true,
          pageBuilder: (context, a1, a2) {
            return Scaffold(
              backgroundColor: Colors.black,
              body: _withPlaybackShortcuts(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => _markUserActivity(),
                  onPointerMove: (_) => _markUserActivity(),
                  onPointerSignal: _onPointerSignal,
                  child: MouseRegion(
                    onHover: (_) => _markUserActivity(),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ValueListenableBuilder<_AspectMode>(
                          valueListenable: _aspectMode,
                          builder: (context, mode, _) {
                            final (fit, aspectRatio) = _aspectParams(mode);
                            return Video(
                              controller: _controller,
                              fit: fit,
                              aspectRatio: aspectRatio,
                              controls: NoVideoControls,
                              subtitleViewConfiguration:
                                  const SubtitleViewConfiguration(visible: false),
                            );
                          },
                        ),
                        Positioned.fill(
                          child: _PlayerInputLayer(
                            player: _player,
                            onToggleFullscreen: () => Navigator.of(context).pop(),
                          ),
                        ),
                        if (_preparing) const Center(child: CircularProgressIndicator()),
                        _SubtitleOverlay(player: _player, prefs: prefs),
                        Positioned(
                          right: 16,
                          bottom: 132,
                          child: _PlaybackOverlays(
                            engine: _engine,
                            loadingNext: _loadingNext,
                            services: _services,
                          ),
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: _controlsVisible,
                          builder: (context, visible, _) {
                            return IgnorePointer(
                              ignoring: !visible,
                              child: AnimatedOpacity(
                                opacity: visible ? 1 : 0,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      child: SafeArea(
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 8, top: 8),
                                          child: _TopNavControls(
                                            onBack: () => _exitToUi(itemId: item.id),
                                            onHome: () => _exitToHome(itemId: item.id),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: _BottomControlsBar(
                                        player: _player,
                                        engine: _engine,
                                        prefs: prefs,
                                        seekingSeconds: _seekingSeconds,
                                        onSeekingSecondsChanged: (v) {
                                          setState(() => _seekingSeconds = v);
                                          _markUserActivity();
                                        },
                                        onSeekCommitted: () {
                                          setState(() => _seekingSeconds = null);
                                          _markUserActivity();
                                        },
                                        onShowAspectRatio: () =>
                                            _showAspectRatioPicker(context, _aspectMode),
                                        onToggleFullscreen: () => Navigator.of(context).pop(),
                                        isFullscreen: true,
                                        controlsVisible: visible,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    } finally {
      if (nativeEntered) {
        await defaultExitNativeFullscreen();
      }
      if (mounted) setState(() => _isFullscreen = false);
    }
  }

  void _showVolumeHud(double value) {
    _onVolumeChanged(value);
  }
  
  Widget _withPlaybackShortcuts({required Widget child}) {
    return FocusableActionDetector(
      autofocus: true,
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.arrowLeft): const _SeekIntent(-10),
        const SingleActivator(LogicalKeyboardKey.arrowRight): const _SeekIntent(10),
        const SingleActivator(LogicalKeyboardKey.space): const _TogglePlayIntent(),
      },
      actions: <Type, Action<Intent>>{
        _SeekIntent: CallbackAction<_SeekIntent>(
          onInvoke: (_SeekIntent intent) {
            _seekBySeconds(intent.seconds);
            return null;
          },
        ),
        _TogglePlayIntent: CallbackAction<_TogglePlayIntent>(
          onInvoke: (intent) async {
            _markUserActivity();
            try {
              await _player.playOrPause();
            } catch (_) {}
            return null;
          },
        ),
      },
      child: child,
    );
  }

  Future<void> _seekBySeconds(int deltaSeconds) async {
    _markUserActivity();
    final pos = _player.state.position;
    final duration = _player.state.duration;
    var target = pos + Duration(seconds: deltaSeconds);
    if (target.isNegative) target = Duration.zero;
    if (duration.inMilliseconds > 0 && target > duration) target = duration;
    try {
      await _player.seek(target);
    } catch (_) {}
  }


  void _onVolumeChanged(double value) {
    final v = value.clamp(0.0, 100.0);
    final current = _playbackPrefs;
    if (current == null) return;
    _playbackPrefs = current.copyWith(volume: v);
    _volumeSaveDebounce?.cancel();
    _volumeSaveDebounce = Timer(const Duration(milliseconds: 250), () async {
      final prefs = _playbackPrefs;
      if (prefs == null) return;
      await PlaybackPrefs.save(prefs);
    });
  }
}

int _positionTicks(Duration position) {
  return position.inMilliseconds * 10000;
}

final class _SeekIntent extends Intent {
  const _SeekIntent(this.seconds);

  final int seconds;
}

final class _TogglePlayIntent extends Intent {
  const _TogglePlayIntent();
}

final class _PlayerInputLayer extends StatelessWidget {
  const _PlayerInputLayer({
    required this.player,
    required this.onToggleFullscreen,
  });

  final Player player;
  final VoidCallback onToggleFullscreen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        try {
          await player.playOrPause();
        } catch (_) {}
      },
      onDoubleTap: onToggleFullscreen,
      child: const SizedBox.expand(),
    );
  }
}

final class _SeekBar extends StatelessWidget {
  const _SeekBar({
    required this.player,
    required this.engine,
    required this.seekingSeconds,
    required this.onSeekingSecondsChanged,
    required this.onSeekCommitted,
    required this.active,
  });

  final Player player;
  final PlaybackEngine? engine;
  final double? seekingSeconds;
  final ValueChanged<double?> onSeekingSecondsChanged;
  final VoidCallback onSeekCommitted;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final positionStream = active
        ? Stream<Duration>.periodic(
            const Duration(milliseconds: 200),
            (_) => player.state.position,
          )
        : const Stream<Duration>.empty();
    return StreamBuilder<Duration>(
      stream: player.stream.duration,
      initialData: player.state.duration,
      builder: (context, durationSnap) {
        final duration = durationSnap.data ?? Duration.zero;
        final durationMs = duration.inMilliseconds;
        if (durationMs <= 0) return const SizedBox.shrink();

        return StreamBuilder<Duration>(
          stream: positionStream,
          initialData: player.state.position,
          builder: (context, positionSnap) {
            final pos = positionSnap.data ?? Duration.zero;
            final currentSeconds = seekingSeconds ?? (pos.inMilliseconds / 1000.0);
            final valueSeconds = currentSeconds.clamp(0.0, durationMs / 1000.0);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    overlayShape: SliderComponentShape.noOverlay,
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
                    thumbColor: Colors.white,
                    valueIndicatorColor: Colors.black.withValues(alpha: 0.75),
                  ),
                  child: Slider(
                    min: 0,
                    max: durationMs / 1000.0,
                    value: valueSeconds,
                    onChanged: (v) => onSeekingSecondsChanged(v),
                    onChangeEnd: (v) async {
                      try {
                        await player.seek(Duration(milliseconds: (v * 1000).round()));
                      } catch (_) {}
                      try {
                        await engine?.reportSeekCompleted();
                      } catch (_) {}
                      onSeekCommitted();
                    },
                  ),
                ),
                DefaultTextStyle(
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ) ??
                      const TextStyle(color: Colors.white70),
                  child: Row(
                    children: [
                      _TimeChip(text: _fmt(Duration(milliseconds: (valueSeconds * 1000).round()))),
                      const Spacer(),
                      _TimeChip(text: _fmt(duration)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

final class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(text),
    );
  }
}

String _fmt(Duration d) {
  final totalSeconds = d.inSeconds;
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

final class _PlaybackOverlays extends StatelessWidget {
  const _PlaybackOverlays({
    required this.engine,
    required this.loadingNext,
    required this.services,
  });

  final PlaybackEngine? engine;
  final bool loadingNext;
  final AppServices? services;

  @override
  Widget build(BuildContext context) {
    final engine = this.engine;
    if (engine == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (loadingNext)
          _GlassPanel(
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: const OttSkeleton(width: 160, height: 14, borderRadius: 10),
          ),
        ValueListenableBuilder<bool>(
          valueListenable: engine.showSkipIntro,
          builder: (context, show, _) {
            if (!show) return const SizedBox.shrink();
            return FilledButton(
              onPressed: engine.skipIntro,
              child: Text(context.l10n.skipIntro),
            );
          },
        ),
        const SizedBox(height: 12),
        _NextUpCard(engine: engine, services: services),
      ],
    );
  }
}

final class _NextUpCard extends StatefulWidget {
  const _NextUpCard({required this.engine, required this.services});

  final PlaybackEngine engine;
  final AppServices? services;

  @override
  State<_NextUpCard> createState() => _NextUpCardState();
}

final class _NextUpCardState extends State<_NextUpCard> {
  String? _episodeId;
  int? _seconds;
  int? _totalSeconds;
  Future<EmbyItem>? _future;

  @override
  void initState() {
    super.initState();
    widget.engine.nextUpEpisodeId.addListener(_sync);
    widget.engine.nextUpCountdownSeconds.addListener(_sync);
    _sync();
  }

  @override
  void didUpdateWidget(covariant _NextUpCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engine != widget.engine) {
      oldWidget.engine.nextUpEpisodeId.removeListener(_sync);
      oldWidget.engine.nextUpCountdownSeconds.removeListener(_sync);
      widget.engine.nextUpEpisodeId.addListener(_sync);
      widget.engine.nextUpCountdownSeconds.addListener(_sync);
      _episodeId = null;
      _seconds = null;
      _totalSeconds = null;
      _future = null;
      _sync();
    }
  }

  @override
  void dispose() {
    widget.engine.nextUpEpisodeId.removeListener(_sync);
    widget.engine.nextUpCountdownSeconds.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    final nextId = widget.engine.nextUpEpisodeId.value;
    final nextSeconds = widget.engine.nextUpCountdownSeconds.value;
    final services = widget.services;

    var changed = false;

    if (nextId != _episodeId) {
      _episodeId = nextId;
      _totalSeconds = null;
      _future = (services == null || nextId == null || nextId.isEmpty)
          ? null
          : services.hermes.getItem(nextId);
      changed = true;
    }

    if (nextSeconds != _seconds) {
      _seconds = nextSeconds;
      if (nextSeconds != null) {
        final total = _totalSeconds;
        if (total == null || nextSeconds > total) {
          _totalSeconds = nextSeconds;
        }
      } else {
        _totalSeconds = null;
      }
      changed = true;
    }

    if (changed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    final id = _episodeId;
    final seconds = _seconds;
    final future = _future;
    if (services == null || id == null || id.isEmpty || seconds == null || future == null) {
      return const SizedBox.shrink();
    }

    final total = (_totalSeconds ?? seconds).clamp(1, 3600);
    final pct = (1 - (seconds / total)).clamp(0.0, 1.0);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: _GlassPanel(
        borderRadius: 20,
        padding: const EdgeInsets.all(14),
        child: FutureBuilder<EmbyItem>(
          future: future,
          builder: (context, snap) {
            final item = snap.data;
            final title = (item?.name ?? context.l10n.nextUp).trim();
            final thumbUri = item == null ? null : services.hermes.thumbImageUri(item, maxWidth: 720);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 176,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: thumbUri == null
                          ? const ColoredBox(color: Colors.black12)
                          : _NextUpThumbProgress(imageUri: thumbUri, progress: pct),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.nextUpIn(seconds),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: widget.engine.playNextNow,
                              child: Text(context.l10n.playNext),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: widget.engine.continueWatching,
                              child: Text(context.l10n.dismiss),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

final class _NextUpThumbProgress extends StatelessWidget {
  const _NextUpThumbProgress({required this.imageUri, required this.progress});

  final Uri imageUri;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: Opacity(
            opacity: 0.82,
            child: Image.network(
              imageUri.toString(),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: Colors.black12),
            ),
          ),
        ),
        ClipRect(
          clipper: _LeftRevealClipper(p),
          child: Image.network(
            imageUri.toString(),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
        ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _LeftRevealClipper extends CustomClipper<Rect> {
  const _LeftRevealClipper(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) {
    final p = progress.clamp(0.0, 1.0);
    return Rect.fromLTWH(0, 0, size.width * p, size.height);
  }

  @override
  bool shouldReclip(covariant _LeftRevealClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}

final class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    required this.borderRadius,
    required this.padding,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withValues(alpha: 0.62),
                Colors.black.withValues(alpha: 0.38),
              ],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: child,
        ),
      ),
    );
  }
}

final class _BottomControlsBar extends StatelessWidget {
  const _BottomControlsBar({
    required this.player,
    required this.engine,
    required this.prefs,
    required this.seekingSeconds,
    required this.onSeekingSecondsChanged,
    required this.onSeekCommitted,
    required this.onShowAspectRatio,
    required this.onToggleFullscreen,
    required this.isFullscreen,
    required this.controlsVisible,
  });

  final Player player;
  final PlaybackEngine? engine;
  final ValueNotifier<SubtitlePrefs> prefs;
  final double? seekingSeconds;
  final ValueChanged<double?> onSeekingSecondsChanged;
  final VoidCallback onSeekCommitted;
  final VoidCallback onShowAspectRatio;
  final VoidCallback onToggleFullscreen;
  final bool isFullscreen;
  final bool controlsVisible;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x00000000),
              Color(0xB3000000),
              Color(0xE6000000),
            ],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 26, 14, 10),
        child: _GlassPanel(
          borderRadius: 20,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              StreamBuilder<bool>(
                stream: player.stream.playing,
                initialData: player.state.playing,
                builder: (context, snap) {
                  final playing = snap.data ?? false;
                  return _ControlIcon(
                    tooltip: playing ? context.l10n.pause : context.l10n.play,
                    icon: playing ? Icons.pause : Icons.play_arrow,
                    onPressed: () async {
                      try {
                        await player.playOrPause();
                      } catch (_) {}
                    },
                  );
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _SeekBar(
                    player: player,
                    engine: engine,
                    seekingSeconds: seekingSeconds,
                    onSeekingSecondsChanged: onSeekingSecondsChanged,
                    onSeekCommitted: onSeekCommitted,
                    active: controlsVisible,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _VolumeControl(player: player),
              const SizedBox(width: 10),
              _ControlIcon(
                tooltip: context.l10n.audio,
                icon: Icons.audiotrack,
                onPressed: () => _showAudioPicker(context, player),
              ),
              const SizedBox(width: 4),
              _ControlIcon(
                tooltip: context.l10n.subtitles,
                icon: Icons.closed_caption,
                onPressed: () => _showSubtitlesDialog(context, player, prefs),
              ),
              const SizedBox(width: 4),
              _ControlIcon(
                tooltip: 'Aspect ratio',
                icon: Icons.aspect_ratio,
                onPressed: onShowAspectRatio,
              ),
              const SizedBox(width: 4),
              _ControlIcon(
                tooltip: isFullscreen ? context.l10n.exitFullscreen : context.l10n.fullscreen,
                icon: isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                onPressed: onToggleFullscreen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _VolumeControl extends StatelessWidget {
  const _VolumeControl({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: player.stream.volume,
      initialData: player.state.volume,
      builder: (context, snap) {
        final v = (snap.data ?? player.state.volume).clamp(0.0, 100.0);
        final icon = v <= 0 ? Icons.volume_off : Icons.volume_up;
        return Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.85)),
              const SizedBox(width: 8),
              SizedBox(
                width: 140,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    overlayShape: SliderComponentShape.noOverlay,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    min: 0,
                    max: 100,
                    value: v,
                    onChanged: (next) async {
                      try {
                        await player.setVolume(next);
                      } catch (_) {}
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 52,
                child: Text(
                  context.l10n.volumePercent(v.round()),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

final class _TopNavControls extends StatelessWidget {
  const _TopNavControls({
    required this.onBack,
    required this.onHome,
  });

  final VoidCallback onBack;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ControlIcon(
            tooltip: context.l10n.back,
            icon: Icons.arrow_back,
            onPressed: onBack,
          ),
          _ControlIcon(
            tooltip: context.l10n.home,
            icon: Icons.home,
            onPressed: onHome,
          ),
        ],
      ),
    );
  }
}

final class _ControlIcon extends StatelessWidget {
  const _ControlIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final baseColor = enabled ? Colors.white.withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.55);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: enabled ? 0.08 : 0.04),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Icon(
            icon,
            size: 22,
            color: baseColor,
          ),
        ),
      ),
    );
  }
}

final class _SubtitleOverlay extends StatelessWidget {
  const _SubtitleOverlay({required this.player, required this.prefs});

  final Player player;
  final ValueNotifier<SubtitlePrefs> prefs;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: StreamBuilder<List<String>>(
          stream: player.stream.subtitle,
          initialData: player.state.subtitle,
          builder: (context, snapshot) {
            final lines = snapshot.data ?? const <String>[];
            final text = lines.join('\n').trim();
            if (text.isEmpty) return const SizedBox.shrink();

            return ValueListenableBuilder<SubtitlePrefs>(
              valueListenable: prefs,
              builder: (context, value, _) {
                final showBg = value.backgroundVisible;
                final bg =
                    Colors.black.withValues(alpha: value.backgroundOpacity.clamp(0, 1));
                final fillColor = Color(value.color);
                final outlineWidth = value.borderSize.clamp(0, 20);
                final outlineColor = Color(value.borderColor);
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 88 + value.marginY.clamp(0, 240),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: showBg ? bg : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          if (outlineWidth > 0)
                            Text(
                              text,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: value.fontFamily,
                                fontSize: value.fontSize,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                                fontFamilyFallback: const ['Roboto', 'Arimo'],
                                foreground: Paint()
                                  ..style = PaintingStyle.stroke
                                  ..strokeWidth = outlineWidth.toDouble()
                                  ..color = outlineColor
                                  ..strokeJoin = StrokeJoin.round,
                              ),
                            ),
                          Text(
                            text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: value.fontFamily,
                              fontSize: value.fontSize,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              fontFamilyFallback: const ['Roboto', 'Arimo'],
                              color: fillColor,
                              shadows: const [
                                Shadow(
                                  blurRadius: 14,
                                  color: Colors.black,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

Future<void> _showAudioPicker(BuildContext context, Player player) async {
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(context.l10n.audio),
        content: StreamBuilder<Tracks>(
          stream: player.stream.tracks,
          initialData: player.state.tracks,
          builder: (context, snap) {
            final tracks = snap.data ?? player.state.tracks;
            final items = tracks.audio.where((t) => t.id != 'auto' && t.id != 'no').toList();
            if (items.isEmpty) return Text(context.l10n.noAudioTracksFound);
            return SizedBox(
              width: 520,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final t in items)
                    ListTile(
                      title: Text(
                        ((t.language ?? '').trim().isNotEmpty)
                            ? t.language!.trim()
                            : ((t.title ?? '').trim().isNotEmpty
                                ? t.title!.trim()
                                : context.l10n.audioTrack(t.id)),
                      ),
                      onTap: () async {
                        try {
                          await player.setAudioTrack(t);
                        } catch (_) {}
                        if (context.mounted) context.pop();
                      },
                    ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

Future<void> _showSubtitlesDialog(
  BuildContext context,
  Player player,
  ValueNotifier<SubtitlePrefs> prefs,
) async {
  const baseFontSize = 75.0;
  const minFontSizePct = 50.0;
  const maxFontSizePct = 150.0;
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(context.l10n.subtitles),
        content: SizedBox(
          width: 620,
          height: 560,
          child: Column(
            children: [
              StreamBuilder<Tracks>(
                stream: player.stream.tracks,
                initialData: player.state.tracks,
                builder: (context, snap) {
                  final tracks = snap.data ?? player.state.tracks;
                  final items = tracks.subtitle
                      .where((t) => t.id != 'auto' && t.id != 'no')
                      .toList(growable: false);

                  final baseNames = <String, int>{};
                  for (final t in items) {
                    final base = _subtitleTrackBaseName(t);
                    baseNames[base] = (baseNames[base] ?? 0) + 1;
                  }

                  return StreamBuilder<Track>(
                    stream: player.stream.track,
                    initialData: player.state.track,
                    builder: (context, snap2) {
                      final selected = (snap2.data ?? player.state.track).subtitle;
                      SubtitleTrack? selectedValue;
                      if (selected.id != 'no' && selected.id != 'auto') {
                        for (final t in items) {
                          if (t == selected) {
                            selectedValue = t;
                            break;
                          }
                        }
                      }

                      return DropdownButtonFormField<SubtitleTrack?>(
                        key: ValueKey('${selected.id}|${selected.uri}|${selected.data}'),
                        initialValue: selectedValue,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: context.l10n.subtitles),
                        items: [
                          DropdownMenuItem<SubtitleTrack?>(
                            value: null,
                            child: Row(
                              children: [
                                Expanded(child: Text(context.l10n.off)),
                                if (selected.id == 'no') const Icon(Icons.check),
                              ],
                            ),
                          ),
                          for (final t in items)
                            DropdownMenuItem<SubtitleTrack?>(
                              value: t,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _subtitleTrackLabel(
                                        t,
                                        disambiguate:
                                            (baseNames[_subtitleTrackBaseName(t)] ?? 0) > 1,
                                      ),
                                    ),
                                  ),
                                  if (t == selected) const Icon(Icons.check),
                                ],
                              ),
                            ),
                        ],
                        onChanged: (v) async {
                          try {
                            await player.setSubtitleTrack(v ?? SubtitleTrack.no());
                          } catch (_) {}
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 14),
              const Divider(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: ValueListenableBuilder<SubtitlePrefs>(
                    valueListenable: prefs,
                    builder: (context, value, _) {
                      final fontSizePct = ((value.fontSize / baseFontSize) * 100)
                          .clamp(minFontSizePct, maxFontSizePct);
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(context.l10n.fontSize)),
                              Text(fontSizePct.toStringAsFixed(0)),
                            ],
                          ),
                          Slider(
                            min: minFontSizePct,
                            max: maxFontSizePct,
                            value: fontSizePct,
                            onChanged: (v) {
                              final next = value.copyWith(fontSize: baseFontSize * (v / 100));
                              prefs.value = next;
                              SubtitlePrefs.save(next);
                            },
                          ),
                          SwitchListTile(
                            value: value.backgroundVisible,
                            onChanged: (v) {
                              final next = value.copyWith(backgroundVisible: v);
                              prefs.value = next;
                              SubtitlePrefs.save(next);
                            },
                            title: Text(context.l10n.background),
                            contentPadding: EdgeInsets.zero,
                          ),
                          Row(
                            children: [
                              Expanded(child: Text(context.l10n.backgroundOpacity)),
                              Text('${(value.backgroundOpacity * 100).round()}%'),
                            ],
                          ),
                          Slider(
                            min: 0.1,
                            max: 0.9,
                            value: value.backgroundOpacity.clamp(0.1, 0.9),
                            onChanged: value.backgroundVisible
                                ? (v) {
                                    final next = value.copyWith(backgroundOpacity: v);
                                    prefs.value = next;
                                    SubtitlePrefs.save(next);
                                  }
                                : null,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await SubtitlePrefs.reset();
              prefs.value = SubtitlePrefs.defaults;
            },
            child: Text(context.l10n.reset),
          ),
          TextButton(onPressed: () => context.pop(), child: Text(context.l10n.close)),
        ],
      );
    },
  );
}

String _subtitleTrackBaseName(SubtitleTrack t) {
  final lang = _languageDisplayName(t.language);
  if (lang.isNotEmpty) return lang;
  final title = (t.title ?? '').trim();
  if (title.isNotEmpty) return title;
  return t.id;
}

String _subtitleTrackLabel(SubtitleTrack t, {required bool disambiguate}) {
  final base = _subtitleTrackBaseName(t);
  if (!disambiguate) return base;

  final extras = <String>[];
  final title = (t.title ?? '').trim();
  if (title.isNotEmpty && title != base) extras.add(title);
  final codec = (t.codec ?? '').trim();
  if (codec.isNotEmpty) extras.add(codec.toUpperCase());
  if (t.uri || t.data) extras.add('External');
  if (extras.isEmpty) return base;
  return '$base • ${extras.join(' • ')}';
}

String _languageDisplayName(String? raw) {
  final v = (raw ?? '').trim();
  if (v.isEmpty) return '';
  final tag = v.replaceAll('_', '-');
  final parts = tag.split('-');
  final lang = parts.first.toLowerCase();
  final name = _languageNames[lang];
  if (name == null) return tag;
  if (parts.length == 1) return name;

  final region = parts[1].toUpperCase();
  if (region == '419') return '$name (Latin America)';
  final regionName = _regionNames[region];
  if (regionName != null) return '$name ($regionName)';
  return '$name ($region)';
}

const Map<String, String> _languageNames = {
  'ar': 'Arabic',
  'bg': 'Bulgarian',
  'cs': 'Czech',
  'da': 'Danish',
  'de': 'German',
  'el': 'Greek',
  'en': 'English',
  'es': 'Spanish',
  'et': 'Estonian',
  'fi': 'Finnish',
  'fr': 'French',
  'he': 'Hebrew',
  'hi': 'Hindi',
  'hr': 'Croatian',
  'hu': 'Hungarian',
  'id': 'Indonesian',
  'it': 'Italian',
  'ja': 'Japanese',
  'ko': 'Korean',
  'lt': 'Lithuanian',
  'lv': 'Latvian',
  'ms': 'Malay',
  'nl': 'Dutch',
  'no': 'Norwegian',
  'pl': 'Polish',
  'pt': 'Portuguese',
  'ro': 'Romanian',
  'ru': 'Russian',
  'sk': 'Slovak',
  'sl': 'Slovenian',
  'sv': 'Swedish',
  'th': 'Thai',
  'tr': 'Turkish',
  'uk': 'Ukrainian',
  'vi': 'Vietnamese',
  'zh': 'Chinese',
};

const Map<String, String> _regionNames = {
  'BR': 'Brazil',
  'PT': 'Portugal',
  'ES': 'Spain',
  'FR': 'France',
  'US': 'United States',
  'GB': 'United Kingdom',
};

(BoxFit, double?) _aspectParams(_AspectMode mode) {
  return switch (mode) {
    _AspectMode.fit => (BoxFit.contain, null),
    _AspectMode.cover => (BoxFit.cover, null),
    _AspectMode.fill => (BoxFit.fill, null),
    _AspectMode.ratio16x9 => (BoxFit.contain, 16 / 9),
    _AspectMode.ratio4x3 => (BoxFit.contain, 4 / 3),
  };
}

String _aspectModeLabel(_AspectMode mode) {
  return switch (mode) {
    _AspectMode.fit => 'Fit',
    _AspectMode.cover => 'Zoom',
    _AspectMode.fill => 'Stretch',
    _AspectMode.ratio16x9 => '16:9',
    _AspectMode.ratio4x3 => '4:3',
  };
}

Future<void> _showAspectRatioPicker(
  BuildContext context,
  ValueNotifier<_AspectMode> mode,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Aspect ratio'),
        content: SizedBox(
          width: 420,
          child: ValueListenableBuilder<_AspectMode>(
            valueListenable: mode,
            builder: (context, value, _) {
              return ListView(
                shrinkWrap: true,
                children: [
                  for (final m in _AspectMode.values)
                    ListTile(
                      title: Text(_aspectModeLabel(m)),
                      trailing: value == m ? const Icon(Icons.check) : null,
                      onTap: () {
                        mode.value = m;
                        context.pop();
                      },
                    ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

EmbyAudioStream _pickNextAudio({
  required EmbyPlaybackInfo nextPlaybackInfo,
  required EmbyAudioStream preferred,
}) {
  final preferredLang = _normLang(preferred.language);
  if (preferredLang.isNotEmpty) {
    for (final a in nextPlaybackInfo.audioStreams) {
      if (_normLang(a.language) == preferredLang) return a;
    }
  }
  final defaults = nextPlaybackInfo.audioStreams.where((a) => a.isDefault).toList(growable: false);
  if (defaults.isNotEmpty) return defaults.first;
  return nextPlaybackInfo.audioStreams.isEmpty ? preferred : nextPlaybackInfo.audioStreams.first;
}

EmbySubtitleStream? _pickNextSubtitle({
  required EmbyPlaybackInfo nextPlaybackInfo,
  required EmbySubtitleStream? preferred,
}) {
  if (preferred == null) return null;
  final preferredLang = _normLang(preferred.language);
  if (preferredLang.isNotEmpty) {
    for (final s in nextPlaybackInfo.subtitleStreams) {
      if (_normLang(s.language) == preferredLang) return s;
    }
  }
  final defaults =
      nextPlaybackInfo.subtitleStreams.where((s) => s.isDefault).toList(growable: false);
  if (defaults.isNotEmpty) return defaults.first;
  return nextPlaybackInfo.subtitleStreams.isEmpty ? null : nextPlaybackInfo.subtitleStreams.first;
}

String _normLang(String? language) {
  final v = (language ?? '').toLowerCase().trim();
  if (v.isEmpty) return '';
  final base = v.split(RegExp('[_-]')).first;
  final base2 = base.replaceAll(RegExp(r'[^a-z]'), '');
  if (base2.length >= 2) return base2.substring(0, 2);
  return base2;
}
