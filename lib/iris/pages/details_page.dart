import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app.dart';
import '../../app/services/app_services.dart';
import '../../core/emby/models/emby_item.dart';
import '../../core/emby/models/emby_media_stream.dart';
import '../../core/emby/models/emby_playback_info.dart';
import '../../core/emby/models/emby_media_source.dart';
import '../../l10n/l10n.dart';
import '../player/playback_prefs.dart';
import '../widgets/ott_focusable.dart';
import '../widgets/ott_shimmer.dart';
import 'playback_page.dart';
import 'show_details_prefs.dart';

final class DetailsPage extends StatefulWidget {
  const DetailsPage({super.key, required this.itemId});

  final String itemId;

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

final class _DetailsPageState extends State<DetailsPage> with RouteAware {
  Future<_DetailsData>? _future;
  Future<List<EmbyItem>>? _similarFuture;
  String? _selectedMediaSourceId;
  EmbyAudioStream? _selectedAudio;
  EmbySubtitleStream? _selectedSubtitle;
  bool _markPlayed = false;
  PageRoute<dynamic>? _route;

  @override
  void didUpdateWidget(covariant DetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemId != widget.itemId) {
      _future = null;
      _similarFuture = null;
      _selectedMediaSourceId = null;
      _selectedAudio = null;
      _selectedSubtitle = null;
      _markPlayed = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppServicesScope.of(context);
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && _route != route) {
      if (_route != null) appRouteObserver.unsubscribe(this);
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
    _future ??= _load(services);
    _similarFuture ??= services.hermes.getSimilarItems(widget.itemId, limit: 15);
  }

  @override
  void dispose() {
    if (_route != null) appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() => _refresh();

  void _refresh() {
    final services = AppServicesScope.of(context);
    setState(() {
      _future = _load(services);
      _similarFuture = services.hermes.getSimilarItems(widget.itemId, limit: 15);
      _selectedMediaSourceId = null;
      _selectedAudio = null;
      _selectedSubtitle = null;
      _markPlayed = false;
    });
  }

  Future<_DetailsData> _load(AppServices services) async {
    final prefs = await PlaybackPrefs.load();
    final item = await services.hermes.getItem(widget.itemId);

    if (item.type == 'Series') {
      final playbackItem = await _resolveSeriesPlaybackItem(services: services, series: item);
      if (playbackItem == null) {
        return _DetailsData(
          item: item,
          playbackItem: null,
          playbackInfo: null,
          playbackPrefs: prefs,
        );
      }
      final playbackInfo = await services.apollo.getPlaybackInfo(
        playbackItem.id,
        maxStreamingBitrate: prefs.maxStreamingBitrate(),
      );
      return _DetailsData(
        item: item,
        playbackItem: playbackItem,
        playbackInfo: playbackInfo,
        playbackPrefs: prefs,
      );
    }

    if (!_isPlayable(item.type)) {
      return _DetailsData(
        item: item,
        playbackItem: null,
        playbackInfo: null,
        playbackPrefs: prefs,
      );
    }
    final playbackInfo = await services.apollo.getPlaybackInfo(
      item.id,
      maxStreamingBitrate: prefs.maxStreamingBitrate(),
    );
    return _DetailsData(
      item: item,
      playbackItem: item,
      playbackInfo: playbackInfo,
      playbackPrefs: prefs,
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);
    return FutureBuilder<_DetailsData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: _DetailsSkeleton());
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('${snapshot.error}')),
          );
        }

        final data = snapshot.data!;
        final item = data.item;
        final playbackInfo = data.playbackInfo;
        final prefs = data.playbackPrefs;
        final playbackItem = data.playbackItem;

        final desiredMediaSourceId = playbackInfo == null
            ? null
            : (_selectedMediaSourceId ?? _preferredMediaSourceId(info: playbackInfo, prefs: prefs));
        final effectivePlaybackInfo = playbackInfo == null
            ? null
            : (desiredMediaSourceId == null
                ? playbackInfo
                : playbackInfo.selectMediaSource(desiredMediaSourceId));

        final imageUri = services.hermes.thumbImageUri(item, maxWidth: 1600);
        final progressTicks = (playbackItem?.playbackPositionTicks ?? 0);
        final hasProgress = progressTicks > 0;

        final audio = effectivePlaybackInfo == null
            ? null
            : (_selectedAudio ?? prefs.pickAudio(effectivePlaybackInfo.audioStreams));
        final subtitle = effectivePlaybackInfo == null
            ? null
            : (_selectedSubtitle ?? prefs.pickSubtitle(effectivePlaybackInfo.subtitleStreams));

        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imageUri.toString(),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(color: Colors.black12),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xFF0B0D10),
                      Color(0xF20B0D10),
                      Color(0xB30B0D10),
                      Color(0x400B0D10),
                      Color(0x000B0D10),
                    ],
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: _GlassPanel(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Poster(
                                  imageUri: services.hermes.primaryImageUri(item, maxWidth: 600),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (item.productionYear != null ||
                                          (effectivePlaybackInfo != null &&
                                              _infoTags(
                                                info: effectivePlaybackInfo,
                                                audio: audio,
                                              ).isNotEmpty))
                                        _YearAndTags(
                                          year: item.productionYear,
                                          tags: effectivePlaybackInfo == null
                                              ? const <String>[]
                                              : _infoTags(
                                                  info: effectivePlaybackInfo,
                                                  audio: audio,
                                                ),
                                        ),
                                      const SizedBox(height: 12),
                                      if ((item.overview ?? '').trim().isNotEmpty)
                                        Text(
                                          item.overview!,
                                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.86),
                                              ),
                                        ),
                                      const SizedBox(height: 18),
                                      if (effectivePlaybackInfo != null) ...[
                                        Row(
                                          children: [
                                            FilledButton.icon(
                                              onPressed: audio == null
                                                  ? null
                                                  : () => _startPlayback(
                                                        context: context,
                                                        item: playbackItem ?? item,
                                                        playbackInfo: effectivePlaybackInfo,
                                                        startPositionTicks:
                                                            hasProgress ? progressTicks : 0,
                                                        audio: audio,
                                                        subtitle: subtitle,
                                                      ),
                                              icon: const Icon(Icons.play_arrow),
                                              label: Text(
                                                hasProgress ? context.l10n.resume : context.l10n.play,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            OutlinedButton.icon(
                                              onPressed: () async {
                                                final next = !_markPlayed;
                                                setState(() => _markPlayed = next);
                                                try {
                                                  final id = (playbackItem ?? item).id;
                                                  if (next) {
                                                    await services.apollo.markPlayed(id);
                                                  } else {
                                                    await services.apollo.markUnplayed(id);
                                                  }
                                                } catch (_) {}
                                              },
                                              icon: Icon(
                                                _markPlayed
                                                    ? Icons.check_circle
                                                    : Icons.circle_outlined,
                                              ),
                                              label: Text(
                                                _markPlayed
                                                    ? context.l10n.watched
                                                    : context.l10n.markAsWatched,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (hasProgress) ...[
                                          const SizedBox(height: 12),
                                          OutlinedButton.icon(
                                            onPressed: audio == null
                                                ? null
                                                : () => _startPlayback(
                                                      context: context,
                                                      item: playbackItem ?? item,
                                                      playbackInfo: effectivePlaybackInfo,
                                                      startPositionTicks: 0,
                                                      audio: audio,
                                                      subtitle: subtitle,
                                                    ),
                                            icon: const Icon(Icons.restart_alt),
                                            label: Text(context.l10n.startFromBeginning),
                                          ),
                                        ],
                                        const SizedBox(height: 14),
                                        _PlaybackOptions(
                                          playbackInfo: effectivePlaybackInfo,
                                          selectedAudio: audio,
                                          selectedSubtitle: subtitle,
                                          onMediaSourceChanged: (v) => setState(() {
                                            _selectedMediaSourceId = v;
                                            _selectedAudio = null;
                                            _selectedSubtitle = null;
                                          }),
                                          onAudioChanged: (v) =>
                                              setState(() => _selectedAudio = v),
                                          onSubtitleChanged: (v) =>
                                              setState(() => _selectedSubtitle = v),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 22, bottom: 28),
                        child: _SeriesAndEpisodes(item: item),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 28),
                        child: _SimilarSection(
                          future: _similarFuture,
                          onOpenDetails: (id) => context.push('/details/$id'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String? _preferredMediaSourceId({
    required EmbyPlaybackInfo info,
    required PlaybackPrefs prefs,
  }) {
    if (info.mediaSources.isEmpty) return null;

    int? heightOf(EmbyMediaSource s) {
      final h = s.video?.height;
      if (h != null && h > 0) return h;
      final name = (s.name ?? '').toLowerCase();
      final match = RegExp(r'(\d{3,4})p').firstMatch(name);
      if (match != null) {
        final v = int.tryParse(match.group(1) ?? '');
        if (v != null && v > 0) return v;
      }
      if (name.contains('2160') || name.contains('4k')) return 2160;
      if (name.contains('1080')) return 1080;
      if (name.contains('720')) return 720;
      return null;
    }

    int targetHeight;
    switch (prefs.qualityPreference) {
      case PlaybackQualityPreference.p2160:
        targetHeight = 2160;
        break;
      case PlaybackQualityPreference.p1080:
        targetHeight = 1080;
        break;
      case PlaybackQualityPreference.p720:
        targetHeight = 720;
        break;
      case PlaybackQualityPreference.auto:
        targetHeight = 1080;
        break;
    }

    EmbyMediaSource? bestAtOrBelow;
    var bestAtOrBelowHeight = -1;
    EmbyMediaSource? bestAbove;
    var bestAboveHeight = 1 << 30;

    for (final s in info.mediaSources) {
      final h = heightOf(s) ?? 0;
      if (h <= 0) continue;
      if (h <= targetHeight) {
        if (h > bestAtOrBelowHeight) {
          bestAtOrBelowHeight = h;
          bestAtOrBelow = s;
        }
      } else {
        if (h < bestAboveHeight) {
          bestAboveHeight = h;
          bestAbove = s;
        }
      }
    }

    return (bestAtOrBelow ?? bestAbove ?? info.mediaSources.first).id;
  }
}

final class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const OttSkeleton(width: 240, height: 360, borderRadius: 18),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const OttSkeleton(width: 420, height: 34, borderRadius: 12),
                  const SizedBox(height: 12),
                  const OttSkeleton(width: 120, height: 18, borderRadius: 10),
                  const SizedBox(height: 18),
                  const OttSkeleton(width: double.infinity, height: 18, borderRadius: 10),
                  const SizedBox(height: 10),
                  const OttSkeleton(width: double.infinity, height: 18, borderRadius: 10),
                  const SizedBox(height: 10),
                  const OttSkeleton(width: 340, height: 18, borderRadius: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _Poster extends StatelessWidget {
  const _Poster({required this.imageUri});

  final Uri imageUri;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 360,
      child: OttFocusableCard(
        onPressed: null,
        borderRadius: 18,
        child: Image.network(
          imageUri.toString(),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const ColoredBox(color: Colors.black12),
        ),
      ),
    );
  }
}

final class _YearAndTags extends StatelessWidget {
  const _YearAndTags({required this.year, required this.tags});

  final int? year;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final yearStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.82),
          fontWeight: FontWeight.w700,
        );

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (year != null) Text('$year', style: yearStyle),
        for (final t in tags) _InfoTag(text: t),
      ],
    );
  }
}

final class _InfoTag extends StatelessWidget {
  const _InfoTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface.withValues(alpha: 0.90),
            ),
      ),
    );
  }
}

final class _PlaybackOptions extends StatelessWidget {
  const _PlaybackOptions({
    required this.playbackInfo,
    required this.selectedAudio,
    required this.selectedSubtitle,
    required this.onMediaSourceChanged,
    required this.onAudioChanged,
    required this.onSubtitleChanged,
  });

  final EmbyPlaybackInfo playbackInfo;
  final EmbyAudioStream? selectedAudio;
  final EmbySubtitleStream? selectedSubtitle;
  final ValueChanged<String> onMediaSourceChanged;
  final ValueChanged<EmbyAudioStream?> onAudioChanged;
  final ValueChanged<EmbySubtitleStream?> onSubtitleChanged;

  @override
  Widget build(BuildContext context) {
    final audioItems = playbackInfo.audioStreams;
    final subtitleItems = playbackInfo.subtitleStreams;
    final sources = playbackInfo.mediaSources;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sources.length > 1) ...[
          DropdownButtonFormField<EmbyMediaSource>(
            key: ValueKey(playbackInfo.mediaSourceId),
            initialValue: playbackInfo.activeMediaSource,
            decoration: InputDecoration(labelText: context.l10n.quality),
            items: sources
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(_mediaSourceLabel(s)),
                  ),
                )
                .toList(growable: false),
            onChanged: (v) {
              if (v == null) return;
              onMediaSourceChanged(v.id);
            },
          ),
          const SizedBox(height: 12),
        ],
        DropdownButtonFormField<EmbyAudioStream>(
          initialValue: selectedAudio,
          decoration: InputDecoration(labelText: context.l10n.audio),
          items: audioItems
              .map(
                (a) => DropdownMenuItem(
                  value: a,
                  child: Text(_audioLabel(a)),
                ),
              )
              .toList(growable: false),
          onChanged: onAudioChanged,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<EmbySubtitleStream?>(
          initialValue: selectedSubtitle,
          decoration: InputDecoration(labelText: context.l10n.subtitles),
          items: <DropdownMenuItem<EmbySubtitleStream?>>[
            DropdownMenuItem(
              value: null,
              child: Text(context.l10n.off),
            ),
            ...subtitleItems.map(
              (s) => DropdownMenuItem(
                value: s,
                child: Text(_subtitleLabel(s)),
              ),
            ),
          ],
          onChanged: onSubtitleChanged,
        ),
      ],
    );
  }
}

final class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: surface.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}

final class _SeriesAndEpisodes extends StatelessWidget {
  const _SeriesAndEpisodes({required this.item});

  final EmbyItem item;

  @override
  Widget build(BuildContext context) {
    if (item.type == 'Series') return _SeriesBrowser(series: item);
    if (item.type == 'Season') return _SeasonBrowser(season: item);
    return const SizedBox.shrink();
  }
}

final class _SeriesBrowser extends StatefulWidget {
  const _SeriesBrowser({required this.series});

  final EmbyItem series;

  @override
  State<_SeriesBrowser> createState() => _SeriesBrowserState();
}

final class _SeriesBrowserState extends State<_SeriesBrowser> {
  Future<List<EmbyItem>>? _seasonsFuture;
  Future<String?>? _lastWatchedSeasonIdFuture;
  String? _selectedSeasonId;
  EpisodesLayout _episodesLayout = EpisodesLayout.list;
  bool _episodesLayoutLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppServicesScope.of(context);
    _seasonsFuture ??= services.hermes.getSeasons(widget.series.id);
    _lastWatchedSeasonIdFuture ??= _loadLastWatchedSeasonId(services);
    if (!_episodesLayoutLoaded) {
      _episodesLayoutLoaded = true;
      ShowDetailsPrefs.loadEpisodesLayout().then((value) {
        if (!mounted) return;
        setState(() => _episodesLayout = value);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: _GlassPanel(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Seasons & Episodes',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.listView,
                    onPressed: () async {
                      setState(() => _episodesLayout = EpisodesLayout.list);
                      await ShowDetailsPrefs.saveEpisodesLayout(EpisodesLayout.list);
                    },
                    icon: Icon(
                      Icons.view_agenda,
                      color: _episodesLayout == EpisodesLayout.list
                          ? scheme.primary
                          : scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.gridView,
                    onPressed: () async {
                      setState(() => _episodesLayout = EpisodesLayout.grid);
                      await ShowDetailsPrefs.saveEpisodesLayout(EpisodesLayout.grid);
                    },
                    icon: Icon(
                      Icons.grid_view,
                      color: _episodesLayout == EpisodesLayout.grid
                          ? scheme.primary
                          : scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<EmbyItem>>(
                future: _seasonsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const OttSkeleton(width: 320, height: 56, borderRadius: 14);
                  }
                  if (snapshot.hasError) return Text('${snapshot.error}');
                  final seasons = snapshot.data ?? const <EmbyItem>[];
                  if (seasons.isEmpty) return Text(context.l10n.noSeasonsFound);
                  return FutureBuilder<String?>(
                    future: _lastWatchedSeasonIdFuture,
                    builder: (context, snap) {
                      final lastWatchedSeasonId = snap.data;

                      final preferredId =
                          (lastWatchedSeasonId ?? '').isNotEmpty ? lastWatchedSeasonId : null;
                      final resolvedId = _selectedSeasonId ?? preferredId ?? seasons.first.id;
                      final selected = seasons.firstWhere(
                        (s) => s.id == resolvedId,
                        orElse: () => seasons.first,
                      );

                      if (_selectedSeasonId == null &&
                          preferredId != null &&
                          preferredId != selected.id) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() => _selectedSeasonId = preferredId);
                        });
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<EmbyItem>(
                            key: ValueKey(selected.id),
                            initialValue: selected,
                            decoration: InputDecoration(labelText: context.l10n.season),
                            items: seasons
                                .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                                .toList(growable: false),
                            onChanged: (v) => setState(() => _selectedSeasonId = v?.id),
                          ),
                          const SizedBox(height: 14),
                          _EpisodesList(
                            parentId: selected.id,
                            showDetailsFor: widget.series.id,
                            layout: _episodesLayout,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _loadLastWatchedSeasonId(AppServices services) async {
    try {
      final resume = await services.hermes.getResumeItems(limit: 200);
      for (final r in resume) {
        if (r.type != 'Episode') continue;
        if ((r.seriesId ?? '') != widget.series.id) continue;
        if ((r.playbackPositionTicks ?? 0) <= 0) continue;
        final sid = (r.seasonId ?? '').trim();
        if (sid.isNotEmpty) return sid;
      }

      final episodes = await services.hermes.getRecentEpisodeActivityItems(limit: 600);
      for (final e in episodes) {
        if ((e.seriesId ?? '') != widget.series.id) continue;
        final sid = (e.seasonId ?? '').trim();
        if (sid.isNotEmpty) return sid;
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}

final class _SeasonBrowser extends StatefulWidget {
  const _SeasonBrowser({required this.season});

  final EmbyItem season;

  @override
  State<_SeasonBrowser> createState() => _SeasonBrowserState();
}

final class _SeasonBrowserState extends State<_SeasonBrowser> {
  EpisodesLayout _episodesLayout = EpisodesLayout.list;
  bool _episodesLayoutLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_episodesLayoutLoaded) return;
    _episodesLayoutLoaded = true;
    ShowDetailsPrefs.loadEpisodesLayout().then((value) {
      if (!mounted) return;
      setState(() => _episodesLayout = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: _GlassPanel(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.episodes,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.listView,
                    onPressed: () async {
                      setState(() => _episodesLayout = EpisodesLayout.list);
                      await ShowDetailsPrefs.saveEpisodesLayout(EpisodesLayout.list);
                    },
                    icon: Icon(
                      Icons.view_agenda,
                      color: _episodesLayout == EpisodesLayout.list
                          ? scheme.primary
                          : scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.gridView,
                    onPressed: () async {
                      setState(() => _episodesLayout = EpisodesLayout.grid);
                      await ShowDetailsPrefs.saveEpisodesLayout(EpisodesLayout.grid);
                    },
                    icon: Icon(
                      Icons.grid_view,
                      color: _episodesLayout == EpisodesLayout.grid
                          ? scheme.primary
                          : scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _EpisodesList(
                parentId: widget.season.id,
                showDetailsFor: widget.season.id,
                layout: _episodesLayout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _EpisodesList extends StatefulWidget {
  const _EpisodesList({
    required this.parentId,
    required this.showDetailsFor,
    required this.layout,
  });

  final String parentId;
  final String showDetailsFor;
  final EpisodesLayout layout;

  @override
  State<_EpisodesList> createState() => _EpisodesListState();
}

final class _EpisodesListState extends State<_EpisodesList> {
  Future<List<EmbyItem>>? _future;
  final Map<String, bool> _playedOverrides = {};

  @override
  void didUpdateWidget(covariant _EpisodesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parentId != widget.parentId) {
      final services = AppServicesScope.of(context);
      setState(() {
        _future = services.hermes.getEpisodes(widget.parentId);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppServicesScope.of(context);
    _future ??= services.hermes.getEpisodes(widget.parentId);
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);
    final future = _future ??= services.hermes.getEpisodes(widget.parentId);
    return FutureBuilder<List<EmbyItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.connectionState == ConnectionState.active) {
          return Column(
            children: [
              for (var i = 0; i < 6; i++) ...[
                const _EpisodeRowSkeleton(),
                const SizedBox(height: 12),
              ],
            ],
          );
        }
        if (snapshot.hasError) return Text('${snapshot.error}');
        final episodes = snapshot.data ?? const <EmbyItem>[];
        if (episodes.isEmpty) return Text(context.l10n.noEpisodesFound);

        if (widget.layout == EpisodesLayout.grid) {
          return LayoutBuilder(
            builder: (context, constraints) {
              const minTile = 340.0;
              final cols = max(1, (constraints.maxWidth / minTile).floor());
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 16 / 13,
                ),
                itemCount: episodes.length,
                itemBuilder: (context, index) {
                  final ep = episodes[index];
                  return _EpisodeGridTile(
                    episode: ep,
                    isWatched: _playedOverrides[ep.id] ?? ep.isPlayed,
                    onOpenDetails: () => context.push('/details/${ep.id}'),
                    onPlay: () =>
                        _playEpisode(context: context, services: services, episodeId: ep.id),
                    onToggleWatched: () => _toggleWatched(ep),
                  );
                },
              );
            },
          );
        }

        return Column(
          children: [
            for (final ep in episodes)
              _EpisodeTile(
                episode: ep,
                isWatched: _playedOverrides[ep.id] ?? ep.isPlayed,
                onOpenDetails: () => context.push('/details/${ep.id}'),
                onPlay: () => _playEpisode(context: context, services: services, episodeId: ep.id),
                onToggleWatched: () => _toggleWatched(ep),
              ),
          ],
        );
      },
    );
  }

  Future<void> _toggleWatched(EmbyItem episode) async {
    final services = AppServicesScope.of(context);
    final current = _playedOverrides[episode.id] ?? episode.isPlayed;
    final next = !current;
    setState(() => _playedOverrides[episode.id] = next);
    try {
      if (next) {
        await services.apollo.markPlayed(episode.id);
      } else {
        await services.apollo.markUnplayed(episode.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _playedOverrides[episode.id] = current);
    }
  }

  Future<void> _playEpisode({
    required BuildContext context,
    required AppServices services,
    required String episodeId,
  }) async {
    try {
      await _withLoading(context, () async {
        final prefs = await PlaybackPrefs.load();
        final item = await services.hermes.getItem(episodeId);
        final info = await services.apollo.getPlaybackInfo(
          episodeId,
          maxStreamingBitrate: prefs.maxStreamingBitrate(),
        );
        final audio = prefs.pickAudio(info.audioStreams);
        if (!context.mounted || audio == null) return;
        final subtitle = prefs.pickSubtitle(info.subtitleStreams);
        AppUiScope.of(context).lastPlaybackItemId.value = item.id;
        context.push(
          '/play/${item.id}',
          extra: PlaybackArgs(
            item: item,
            playbackInfo: info,
            startPositionTicks: item.playbackPositionTicks ?? 0,
            selectedAudio: audio,
            selectedSubtitle: subtitle,
          ),
        );
      });
    } catch (_) {}
  }

  Future<void> _withLoading(BuildContext context, Future<void> Function() action) async {
    if (!context.mounted) return;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const OttSkeleton(width: 220, height: 20, borderRadius: 10),
            ),
          );
        },
      ),
    );
    try {
      await action();
    } finally {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

final class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.episode,
    required this.isWatched,
    required this.onOpenDetails,
    required this.onPlay,
    required this.onToggleWatched,
  });

  final EmbyItem episode;
  final bool isWatched;
  final VoidCallback onOpenDetails;
  final VoidCallback onPlay;
  final VoidCallback onToggleWatched;

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);
    final hasProgress = (episode.playbackPositionTicks ?? 0) > 0;
    final imageUri = services.hermes.thumbImageUri(episode, maxWidth: 960);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OttFocusableCard(
        onPressed: onOpenDetails,
        borderRadius: 16,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.52),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 320,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColorFiltered(
                          colorFilter: isWatched
                              ? const ColorFilter.matrix(<double>[
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0, 0, 0, 1, 0,
                                ])
                              : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                          child: Opacity(
                            opacity: isWatched ? 0.78 : 1,
                            child: Image.network(
                              imageUri.toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const ColoredBox(color: Colors.black12),
                            ),
                          ),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Color(0xCC000000),
                                Color(0x00000000),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    if ((episode.overview ?? '').trim().isNotEmpty)
                      Text(
                        episode.overview!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.78),
                            ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: onPlay,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(hasProgress ? context.l10n.resume : context.l10n.play),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: onToggleWatched,
                          icon: Icon(isWatched ? Icons.check_circle : Icons.circle_outlined),
                          label: Text(
                            isWatched ? context.l10n.watched : context.l10n.markAsWatched,
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: onOpenDetails,
                          child: Text(context.l10n.details),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _EpisodeGridTile extends StatelessWidget {
  const _EpisodeGridTile({
    required this.episode,
    required this.isWatched,
    required this.onOpenDetails,
    required this.onPlay,
    required this.onToggleWatched,
  });

  final EmbyItem episode;
  final bool isWatched;
  final VoidCallback onOpenDetails;
  final VoidCallback onPlay;
  final VoidCallback onToggleWatched;

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);
    final hasProgress = (episode.playbackPositionTicks ?? 0) > 0;
    final imageUri = services.hermes.thumbImageUri(episode, maxWidth: 960);

    return OttFocusableCard(
      onPressed: onOpenDetails,
      borderRadius: 16,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.52),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColorFiltered(
                      colorFilter: isWatched
                          ? const ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0, 0, 0, 1, 0,
                            ])
                          : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                      child: Opacity(
                        opacity: isWatched ? 0.78 : 1,
                        child: Image.network(
                          imageUri.toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const ColoredBox(color: Colors.black12),
                        ),
                      ),
                    ),
                    const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Color(0xCC000000),
                              Color(0x00000000),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Text(
                        episode.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton.filledTonal(
                  iconSize: 18,
                  tooltip: hasProgress ? context.l10n.resume : context.l10n.play,
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  iconSize: 18,
                  tooltip: isWatched ? context.l10n.watched : context.l10n.markAsWatched,
                  onPressed: onToggleWatched,
                  icon: Icon(isWatched ? Icons.check_circle : Icons.circle_outlined),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  iconSize: 18,
                  tooltip: context.l10n.details,
                  onPressed: onOpenDetails,
                  icon: const Icon(Icons.info_outline),
                ),
                const Spacer(),
                if (hasProgress)
                  Text(
                    'In progress',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
                        ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _EpisodeRowSkeleton extends StatelessWidget {
  const _EpisodeRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: const SizedBox(
              width: 320,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: OttSkeleton(borderRadius: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OttSkeleton(width: double.infinity, height: 18, borderRadius: 10),
                SizedBox(height: 10),
                OttSkeleton(width: double.infinity, height: 14, borderRadius: 10),
                SizedBox(height: 8),
                OttSkeleton(width: 240, height: 14, borderRadius: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _startPlayback({
  required BuildContext context,
  required EmbyItem item,
  required EmbyPlaybackInfo playbackInfo,
  required int startPositionTicks,
  required EmbyAudioStream audio,
  required EmbySubtitleStream? subtitle,
}) async {
  AppUiScope.of(context).lastPlaybackItemId.value = item.id;
  context.push(
    '/play/${item.id}',
    extra: PlaybackArgs(
      item: item,
      playbackInfo: playbackInfo,
      startPositionTicks: startPositionTicks,
      selectedAudio: audio,
      selectedSubtitle: subtitle,
    ),
  );
}

bool _isPlayable(String type) {
  return type == 'Movie' || type == 'Episode' || type == 'Video';
}

final class _SimilarSection extends StatelessWidget {
  const _SimilarSection({
    required this.future,
    required this.onOpenDetails,
  });

  final Future<List<EmbyItem>>? future;
  final ValueChanged<String> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final future = this.future;
    if (future == null) return const SizedBox.shrink();
    final services = AppServicesScope.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.youMightAlsoLike, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          FutureBuilder<List<EmbyItem>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _SimilarRowSkeleton();
              }
              if (snapshot.hasError) return const SizedBox.shrink();
              final items = snapshot.data ?? const <EmbyItem>[];
              if (items.isEmpty) return const SizedBox.shrink();
              return FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: _HorizontalRowList(
                  height: 180,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _SimilarCard(
                      item: item,
                      imageUri: services.hermes.thumbImageUri(item, maxWidth: 900),
                      onOpenDetails: () => onOpenDetails(item.id),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

final class _SimilarRowSkeleton extends StatelessWidget {
  const _SimilarRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: OttSkeletonList(
        itemCount: 5,
        itemBuilder: (context, index) => const SizedBox(
          width: 320,
          height: 180,
          child: OttSkeleton(borderRadius: 16),
        ),
      ),
    );
  }
}

final class _SimilarCard extends StatelessWidget {
  const _SimilarCard({
    required this.item,
    required this.imageUri,
    required this.onOpenDetails,
  });

  final EmbyItem item;
  final Uri imageUri;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 180,
      child: Stack(
        fit: StackFit.expand,
        children: [
          OttFocusableCard(
            onPressed: onOpenDetails,
            borderRadius: 16,
            child: Image.network(
              imageUri.toString(),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: Colors.black12),
            ),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xCC000000),
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _HorizontalRowList extends StatefulWidget {
  const _HorizontalRowList({
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
  });

  final double height;
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  State<_HorizontalRowList> createState() => _HorizontalRowListState();
}

final class _HorizontalRowListState extends State<_HorizontalRowList> {
  final _controller = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateNav);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateNav());
  }

  @override
  void dispose() {
    _controller.removeListener(_updateNav);
    _controller.dispose();
    super.dispose();
  }

  void _updateNav() {
    if (!_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    final offset = _controller.offset;
    final left = offset > 0;
    final right = offset < max;
    if (left == _canScrollLeft && right == _canScrollRight) return;
    setState(() {
      _canScrollLeft = left;
      _canScrollRight = right;
    });
  }

  Future<void> _scrollBy(double delta) async {
    if (!_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    final next = (_controller.offset + delta).clamp(0.0, max);
    await _controller.animateTo(
      next,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount <= 0) return const SizedBox.shrink();
    final viewportWidth = _controller.hasClients
        ? _controller.position.viewportDimension
        : MediaQuery.sizeOf(context).width;
    final jump = viewportWidth * 0.85;
    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            itemCount: widget.itemCount,
            padding: EdgeInsets.zero,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: widget.itemBuilder,
          ),
          if (_canScrollLeft)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _RowNavButton(
                  icon: Icons.chevron_left,
                  onPressed: () => _scrollBy(-jump),
                ),
              ),
            ),
          if (_canScrollRight)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerRight,
                child: _RowNavButton(
                  icon: Icons.chevron_right,
                  onPressed: () => _scrollBy(jump),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class _RowNavButton extends StatelessWidget {
  const _RowNavButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.46),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Icon(icon, size: 30),
        ),
      ),
    );
  }
}

final class _DetailsData {
  const _DetailsData({
    required this.item,
    required this.playbackItem,
    required this.playbackInfo,
    required this.playbackPrefs,
  });

  final EmbyItem item;
  final EmbyItem? playbackItem;
  final EmbyPlaybackInfo? playbackInfo;
  final PlaybackPrefs playbackPrefs;
}

Future<EmbyItem?> _resolveSeriesPlaybackItem({
  required AppServices services,
  required EmbyItem series,
}) async {
  try {
    final nextId = await services.apollo.getNextUpEpisodeId(seriesId: series.id);
    if (nextId != null && nextId.isNotEmpty) {
      return await services.hermes.getItem(nextId);
    }
  } catch (_) {}

  try {
    final seasons = await services.hermes.getSeasons(series.id);
    if (seasons.isEmpty) return null;
    final firstSeason = seasons.first;
    final episodes = await services.hermes.getEpisodes(firstSeason.id);
    if (episodes.isEmpty) return null;
    return episodes.first;
  } catch (_) {
    return null;
  }
}

String _audioLabel(EmbyAudioStream a) {
  final title = (a.title ?? '').trim();
  if (title.isNotEmpty) return title;
  final parts = <String>[];
  if ((a.language ?? '').isNotEmpty) parts.add(a.language!);
  if ((a.codec ?? '').isNotEmpty) parts.add(a.codec!);
  if (a.channels != null) parts.add('${a.channels}ch');
  return parts.isEmpty ? 'Audio ${a.index}' : parts.join(' • ');
}

String _subtitleLabel(EmbySubtitleStream s) {
  final title = (s.title ?? '').trim();
  if (title.isNotEmpty) return title;
  final parts = <String>[];
  if ((s.language ?? '').isNotEmpty) parts.add(s.language!);
  if ((s.codec ?? '').isNotEmpty) parts.add(s.codec!);
  if (s.isForced) parts.add('Forced');
  if (s.isExternal) parts.add('External');
  return parts.isEmpty ? 'Subtitle ${s.index}' : parts.join(' • ');
}

String _mediaSourceLabel(EmbyMediaSource s) {
  final parts = <String>[];
  final name = (s.name ?? '').trim();
  if (name.isNotEmpty) parts.add(name);

  final v = s.video;
  if (v != null) {
    final res = _resolutionTag(v.height);
    if (name.isEmpty && res.isNotEmpty) parts.add(res);
    final range = _videoRangeTag(v.videoRange);
    if (range.isNotEmpty) parts.add(range);
    final codec = _videoCodecTag(v.codec);
    if (codec.isNotEmpty) parts.add(codec);
  }

  final container = (s.container ?? '').trim();
  if (container.isNotEmpty) parts.add(container.toUpperCase());
  return parts.isEmpty ? s.id : parts.join(' • ');
}

List<String> _infoTags({
  required EmbyPlaybackInfo info,
  required EmbyAudioStream? audio,
}) {
  final out = <String>[];
  final source = info.activeMediaSource;

  final quality = _qualityTag(_resolutionTag(source.video?.height));
  if (quality.isNotEmpty) out.add(quality);

  final range = _videoRangeTag(source.video?.videoRange);
  if (range.isNotEmpty) out.add(range);

  final vCodec = _videoCodecTag(source.video?.codec);
  if (vCodec.isNotEmpty) out.add(vCodec);

  final container = (source.container ?? '').trim();
  if (container.isNotEmpty) out.add(container.toUpperCase());

  final aTag = _audioTag(audio);
  if (aTag.isNotEmpty) out.add(aTag);

  return out;
}

String _qualityTag(String resolution) {
  switch (resolution) {
    case '4K':
      return '4K';
    case '1080p':
      return 'HD-1080p';
    case '720p':
      return 'HD-720p';
    default:
      return resolution;
  }
}

String _resolutionTag(int? height) {
  final h = height ?? 0;
  if (h >= 2160) return '4K';
  if (h >= 1440) return '1440p';
  if (h >= 1080) return '1080p';
  if (h >= 720) return '720p';
  if (h >= 480) return '480p';
  return '';
}

String _videoRangeTag(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return '';
  final upper = v.toUpperCase();
  if (upper == 'SDR') return 'SDR';
  if (upper.startsWith('HDR')) {
    return upper.replaceAll(' ', '');
  }
  return upper;
}

String _videoCodecTag(String? codec) {
  final c = (codec ?? '').trim().toLowerCase();
  if (c.isEmpty) return '';
  switch (c) {
    case 'h264':
      return 'H.264';
    case 'hevc':
    case 'h265':
      return 'HEVC';
    case 'av1':
      return 'AV1';
  }
  return c.toUpperCase();
}

String _audioTag(EmbyAudioStream? audio) {
  if (audio == null) return '';
  final codecRaw = (audio.codec ?? '').trim().toLowerCase();
  String codec;
  switch (codecRaw) {
    case 'truehd':
      codec = 'TRUEHD';
      break;
    case 'eac3':
      codec = 'EAC3';
      break;
    case 'ac3':
      codec = 'AC3';
      break;
    case 'dca':
      codec = 'DTS';
      break;
    case 'aac':
      codec = 'AAC';
      break;
    default:
      codec = codecRaw.isEmpty ? '' : codecRaw.toUpperCase();
  }

  final channels = audio.channels;
  String? ch;
  if (channels != null && channels > 0) {
    switch (channels) {
      case 1:
        ch = '1.0';
        break;
      case 2:
        ch = '2.0';
        break;
      case 6:
        ch = '5.1';
        break;
      case 8:
        ch = '7.1';
        break;
      default:
        ch = '${channels}ch';
    }
  }

  if (codec.isEmpty && ch == null) return '';
  if (codec.isEmpty) return ch!;
  if (ch == null) return codec;
  return '$codec $ch';
}
