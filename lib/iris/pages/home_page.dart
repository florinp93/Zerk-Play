import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app.dart';
import '../../app/services/app_services.dart';
import '../../core/emby/models/emby_item.dart';
import '../../l10n/l10n.dart';
import '../../services/artemis/artemis_service.dart';
import '../player/playback_prefs.dart';
import '../widgets/ott_focusable.dart';
import '../widgets/ott_shimmer.dart';
import 'playback_page.dart';

final class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

final class _HomePageState extends State<HomePage> with RouteAware {
  Future<_HomeData>? _future;
  Future<ArtemisRecommendations>? _trendingFuture;
  final _random = Random();
  PageRoute<dynamic>? _route;
  ValueNotifier<int>? _homeRefreshTick;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppServicesScope.of(context);
    final tick = AppUiScope.of(context).homeRefreshTick;
    if (_homeRefreshTick != tick) {
      _homeRefreshTick?.removeListener(_onHomeRefreshTick);
      _homeRefreshTick = tick;
      _homeRefreshTick?.addListener(_onHomeRefreshTick);
    }
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && _route != route) {
      if (_route != null) appRouteObserver.unsubscribe(this);
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
    _future ??= _load(services);
    _trendingFuture ??= _loadTrending(services);
  }

  @override
  void dispose() {
    if (_route != null) appRouteObserver.unsubscribe(this);
    _homeRefreshTick?.removeListener(_onHomeRefreshTick);
    super.dispose();
  }

  @override
  void didPush() => _refresh();

  @override
  void didPopNext() => _refresh();

  void _refresh() {
    final services = AppServicesScope.of(context);
    setState(() {
      _future = _load(services);
      _trendingFuture = _loadTrending(services);
    });
  }

  void _onHomeRefreshTick() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refresh();
    });
  }

  Future<ArtemisRecommendations> _loadTrending(AppServices services) {
    return services.artemis.getRecommendations().catchError((e, st) {
      assert(() {
        debugPrint('[Home] Trending future failed: $e');
        debugPrint('$st');
        return true;
      }());
      return const ArtemisRecommendations(items: <ArtemisRecommendationItem>[]);
    });
  }

  Future<_HomeData> _load(AppServices services) async {
    final moviesFuture = services.hermes.getMovies();
    final showsFuture = services.hermes.getShows();
    final latestMoviesFuture = services.hermes.getLatestAddedMovies(limit: 30);
    final latestShowsFuture = services.hermes.getLatestAddedShows(limit: 30);
    final recentMoviesFuture = services.hermes.getRecentlyReleasedMovies(limit: 30);
    final recentShowsFuture = services.hermes.getRecentlyReleasedShows(limit: 30);
    final resumeFuture = services.hermes.getResumeItems(limit: 120);
    final recentEpisodesFuture = services.hermes.getRecentEpisodeActivityItems(limit: 240);

    final movies = await moviesFuture;
    final shows = await showsFuture;
    final latestMovies = await latestMoviesFuture;
    final latestShows = await latestShowsFuture;
    final recentMovies = await recentMoviesFuture;
    final recentShows = await recentShowsFuture;
    final resume = await resumeFuture;
    final recentEpisodes = await recentEpisodesFuture;

    final watched = <EmbyItem>[
      ...movies.where((e) => e.isPlayed),
      ...shows.where((e) => e.isPlayed),
    ];
    watched.shuffle(_random);

    EmbyItem? becauseSeed;
    EmbyItem? enjoySeed;
    if (watched.isNotEmpty) becauseSeed = watched.first;
    if (watched.length >= 2) {
      enjoySeed = watched[1];
    } else if (watched.isNotEmpty) {
      enjoySeed = watched.first;
    }

    List<EmbyItem> becauseItems = const <EmbyItem>[];
    if (becauseSeed != null) {
      try {
        becauseItems = await services.hermes.getSimilarItems(becauseSeed.id, limit: 30);
        becauseItems = becauseItems
            .where((e) => e.id != becauseSeed!.id)
            .take(15)
            .toList(growable: false);
      } catch (_) {
        becauseItems = const <EmbyItem>[];
      }
    }

    List<EmbyItem> enjoyItems = const <EmbyItem>[];
    if (enjoySeed != null) {
      try {
        enjoyItems = await services.hermes.getSimilarItems(enjoySeed.id, limit: 30);
        enjoyItems = enjoyItems
            .where((e) => e.id != enjoySeed!.id)
            .take(15)
            .toList(growable: false);
      } catch (_) {
        enjoyItems = const <EmbyItem>[];
      }
    }

    final topRatedMovies = movies
        .where((e) => (e.communityRating ?? 0) > 0)
        .toList(growable: false)
      ..sort((a, b) => (b.communityRating ?? 0).compareTo(a.communityRating ?? 0));

    final topRatedShows = shows
        .where((e) => (e.communityRating ?? 0) > 0)
        .toList(growable: false)
      ..sort((a, b) => (b.communityRating ?? 0).compareTo(a.communityRating ?? 0));

    final allShows = shows.toList(growable: false);
    allShows.shuffle(_random);
    final bingeSeed = allShows.isEmpty ? null : allShows.first;
    List<EmbyItem> bingeItems = const <EmbyItem>[];
    if (bingeSeed != null) {
      try {
        bingeItems = await services.hermes.getSimilarItems(bingeSeed.id, limit: 30);
        bingeItems = bingeItems
            .where((e) => e.id != bingeSeed.id)
            .take(15)
            .toList(growable: false);
      } catch (_) {
        bingeItems = const <EmbyItem>[];
      }
    }

    final resumeEpisodeBySeries = <String, EmbyItem>{};
    for (final r in resume) {
      if (r.type != 'Episode') continue;
      if ((r.playbackPositionTicks ?? 0) <= 0) continue;
      final sid = (r.seriesId ?? '').trim();
      if (sid.isEmpty) continue;
      resumeEpisodeBySeries.putIfAbsent(sid, () => r);
    }

    final seriesIdsByRecency = <String>[];
    final seenSeriesIds = <String>{};
    for (final e in recentEpisodes) {
      final sid = (e.seriesId ?? '').trim();
      if (sid.isEmpty || seenSeriesIds.contains(sid)) continue;
      seenSeriesIds.add(sid);
      seriesIdsByRecency.add(sid);
      if (seriesIdsByRecency.length >= 30) break;
    }

    final nextUpBySeries = <String, String?>{};
    await Future.wait<void>(
      seriesIdsByRecency.map((sid) async {
        try {
          nextUpBySeries[sid] = await services.apollo.getNextUpEpisodeId(seriesId: sid);
        } catch (_) {
          nextUpBySeries[sid] = null;
        }
      }),
    );

    final keepWatchingSeriesIds = seriesIdsByRecency
        .where((sid) => (nextUpBySeries[sid] ?? '').trim().isNotEmpty)
        .toList(growable: false);

    final seriesById = <String, EmbyItem>{};
    final seriesToFetch = <String>{
      ...resumeEpisodeBySeries.keys,
      ...keepWatchingSeriesIds,
    };
    await Future.wait<void>(
      seriesToFetch.map((id) async {
        try {
          seriesById[id] = await services.hermes.getItem(id);
        } catch (_) {}
      }),
    );

    final continueWatching = <_ContinueWatchingEntry>[];
    final seenSeriesIds2 = <String>{};
    final seenMovieIds = <String>{};

    for (final r in resume) {
      if ((r.playbackPositionTicks ?? 0) <= 0) continue;

      if (r.type == 'Movie') {
        if (r.id.isEmpty || seenMovieIds.contains(r.id)) continue;
        seenMovieIds.add(r.id);
        continueWatching.add(_ContinueWatchingEntry(displayItem: r, resumeItem: r));
        continue;
      }

      if (r.type == 'Episode') {
        final sid = (r.seriesId ?? '').trim();
        if (sid.isEmpty || seenSeriesIds2.contains(sid)) continue;
        final display = seriesById[sid] ?? r;
        if (display.id.isEmpty) continue;
        seenSeriesIds2.add(sid);
        continueWatching.add(_ContinueWatchingEntry(displayItem: display, resumeItem: r));
      }
    }

    for (final sid in keepWatchingSeriesIds) {
      if (seenSeriesIds2.contains(sid)) continue;
      final display = seriesById[sid];
      if (display == null || display.id.isEmpty) continue;
      final resumeEpisode = resumeEpisodeBySeries[sid];
      seenSeriesIds2.add(sid);
      continueWatching.add(
        _ContinueWatchingEntry(
          displayItem: display,
          resumeItem: resumeEpisode ?? display,
        ),
      );
    }

    return _HomeData(
      movies: movies,
      shows: shows,
      latestMovies: latestMovies,
      latestShows: latestShows,
      recentMovies: recentMovies,
      recentShows: recentShows,
      continueWatching: continueWatching,
      becauseTitle: becauseSeed?.name,
      becauseItems: becauseItems,
      enjoyTitle: enjoySeed == null ? null : '',
      enjoyItems: enjoyItems,
      bingeTitle: bingeSeed == null ? null : '',
      bingeItems: bingeItems,
      topRatedMovies: topRatedMovies.take(10).toList(growable: false),
      topRatedShows: topRatedShows.take(10).toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState != ConnectionState.done;
            final data = snapshot.data;
            final movies = data?.movies ?? const <EmbyItem>[];
            final shows = data?.shows ?? const <EmbyItem>[];
            final latestMovies = data?.latestMovies ?? const <EmbyItem>[];
            final latestShows = data?.latestShows ?? const <EmbyItem>[];
            final recentMovies = data?.recentMovies ?? const <EmbyItem>[];
            final recentShows = data?.recentShows ?? const <EmbyItem>[];
            final continueWatching = data?.continueWatching ?? const <_ContinueWatchingEntry>[];
            final trendingFuture = _trendingFuture;
            final becauseItems = data?.becauseItems ?? const <EmbyItem>[];
            final enjoyItems = data?.enjoyItems ?? const <EmbyItem>[];
            final bingeItems = data?.bingeItems ?? const <EmbyItem>[];
            final topRatedMovies = data?.topRatedMovies ?? const <EmbyItem>[];
            final topRatedShows = data?.topRatedShows ?? const <EmbyItem>[];

            final randomFeatured = _pickFeatured(movies: movies, shows: shows, count: 15);
            final becauseSeedName = data?.becauseTitle;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: loading
                        ? const _HeroCarouselSkeleton()
                        : _HeroCarousel(
                            items: randomFeatured,
                            onOpenDetails: (id) => context.push('/details/$id'),
                            onPlay: (item) => _playFromContinueWatching(
                              context: context,
                              services: services,
                              item: item,
                            ),
                          ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: _Section(
                      title: context.l10n.continueWatching,
                      child: loading
                          ? const _HorizontalThumbSkeleton()
                          : _ContinueWatchingRow(
                              items: continueWatching,
                              onOpenDetails: (id) => context.push('/details/$id'),
                              onPlay: (item) => _playFromContinueWatching(
                                context: context,
                                services: services,
                                item: item,
                              ),
                            ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 26),
                    child: _Section(
                      title: context.l10n.latestMovies,
                      onViewAll: () => context.push('/library/movies'),
                      child: loading
                          ? const _HorizontalPosterSkeleton()
                          : _PosterRow(
                              items: latestMovies,
                              onOpenDetails: (id) => context.push('/details/$id'),
                            ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 26),
                    child: _Section(
                      title: context.l10n.recentlyReleasedMovies,
                      onViewAll: () => context.push('/library/movies'),
                      child: loading
                          ? const _HorizontalPosterSkeleton()
                          : _PosterRow(
                              items: recentMovies,
                              onOpenDetails: (id) => context.push('/details/$id'),
                            ),
                    ),
                  ),
                ),
                if (!loading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 26),
                      child: FutureBuilder<ArtemisRecommendations>(
                        future: trendingFuture,
                        builder: (context, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return _Section(
                              title: context.l10n.trendingMovies,
                              child: const _HorizontalPosterSkeleton(),
                            );
                          }
                          if (snap.hasError) {
                            assert(() {
                              debugPrint('[Home] Trending Movies error: ${snap.error}');
                              debugPrint('${snap.stackTrace}');
                              return true;
                            }());
                            return _Section(
                              title: context.l10n.trendingMovies,
                              child: const _TrendingUnavailable(),
                            );
                          }
                          final items = (snap.data?.items ?? const <ArtemisRecommendationItem>[])
                              .where((e) => e.mediaType == MediaType.movie)
                              .toList(growable: false);
                          if (items.isEmpty) {
                            return _Section(
                              title: context.l10n.trendingMovies,
                              child: const _TrendingUnavailable(),
                            );
                          }
                          return _Section(
                            title: context.l10n.trendingMovies,
                            child: _TrendingRow(
                              items: items,
                              onOpen: (item) => _openTrendingItem(
                                context: context,
                                services: services,
                                item: item,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                if (!loading && topRatedMovies.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 34),
                      child: _Section(
                        title: context.l10n.topRatedMovies,
                        child: _TopRatedRow(
                          items: topRatedMovies,
                          onOpenDetails: (id) => context.push('/details/$id'),
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 26),
                    child: _Section(
                      title: context.l10n.latestSeries,
                      onViewAll: () => context.push('/library/series'),
                      child: loading
                          ? const _HorizontalPosterSkeleton()
                          : _PosterRow(
                              items: latestShows,
                              onOpenDetails: (id) => context.push('/details/$id'),
                            ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 26),
                    child: _Section(
                      title: context.l10n.recentlyReleasedSeries,
                      onViewAll: () => context.push('/library/series'),
                      child: loading
                          ? const _HorizontalPosterSkeleton()
                          : _PosterRow(
                              items: recentShows,
                              onOpenDetails: (id) => context.push('/details/$id'),
                            ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 26, bottom: 28),
                    child: loading
                        ? const SizedBox.shrink()
                        : FutureBuilder<ArtemisRecommendations>(
                            future: trendingFuture,
                            builder: (context, snap) {
                              if (snap.connectionState != ConnectionState.done) {
                                return _Section(
                                  title: context.l10n.trendingShows,
                                  child: const _HorizontalPosterSkeleton(),
                                );
                              }
                              if (snap.hasError) {
                                assert(() {
                                  debugPrint('[Home] Trending Shows error: ${snap.error}');
                                  debugPrint('${snap.stackTrace}');
                                  return true;
                                }());
                                return _Section(
                                  title: context.l10n.trendingShows,
                                  child: const _TrendingUnavailable(),
                                );
                              }
                              final items =
                                  (snap.data?.items ?? const <ArtemisRecommendationItem>[])
                                      .where((e) => e.mediaType == MediaType.tv)
                                      .toList(growable: false);
                              if (items.isEmpty) {
                                return _Section(
                                  title: context.l10n.trendingShows,
                                  child: const _TrendingUnavailable(),
                                );
                              }
                              return _Section(
                                title: context.l10n.trendingShows,
                                child: _TrendingRow(
                                  items: items,
                                  onOpen: (item) => _openTrendingItem(
                                    context: context,
                                    services: services,
                                    item: item,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                if (!loading && topRatedShows.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 34),
                      child: _Section(
                        title: context.l10n.topRatedSeries,
                        child: _TopRatedRow(
                          items: topRatedShows,
                          onOpenDetails: (id) => context.push('/details/$id'),
                        ),
                      ),
                    ),
                  ),
                if (!loading && becauseSeedName != null && becauseItems.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 34),
                      child: _Section(
                        title: context.l10n.becauseYouWatched(becauseSeedName),
                        child: _WideRow(
                          items: becauseItems,
                          onOpenDetails: (id) => context.push('/details/$id'),
                        ),
                      ),
                    ),
                  ),
                if (!loading && bingeItems.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 26),
                      child: _Section(
                        title: context.l10n.yourNextBinge,
                        child: _WideRow(
                          items: bingeItems,
                          onOpenDetails: (id) => context.push('/details/$id'),
                        ),
                      ),
                    ),
                  ),
                if (!loading && enjoyItems.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 26),
                      child: _Section(
                        title: context.l10n.youMightEnjoy,
                        child: _CinematicRow(
                          items: enjoyItems.take(12).toList(growable: false),
                          onOpenDetails: (id) => context.push('/details/$id'),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<EmbyItem> _pickFeatured({
    required List<EmbyItem> movies,
    required List<EmbyItem> shows,
    required int count,
  }) {
    final combined = <EmbyItem>[
      ...movies.where((m) => m.primaryImageTag != null),
      ...shows.where((s) => s.primaryImageTag != null),
    ];
    if (combined.isEmpty) return const <EmbyItem>[];
    combined.shuffle(_random);
    return combined.take(count).toList(growable: false);
  }

  Future<void> _playFromContinueWatching({
    required BuildContext context,
    required AppServices services,
    required EmbyItem item,
  }) async {
    try {
      await _withLoading(context, () async {
        final prefs = await PlaybackPrefs.load();
        if (item.type == 'Series') {
          final nextId = await services.apollo.getNextUpEpisodeId(seriesId: item.id);
          if (!context.mounted || nextId == null || nextId.isEmpty) return;
          final nextItem = await services.hermes.getItem(nextId);
          final nextInfo = await services.apollo.getPlaybackInfo(
            nextId,
            maxStreamingBitrate: prefs.maxStreamingBitrate(),
          );
          final audio = prefs.pickAudio(nextInfo.audioStreams);
          if (!context.mounted || audio == null) return;
          final subtitle = prefs.pickSubtitle(nextInfo.subtitleStreams);
          AppUiScope.of(context).lastPlaybackItemId.value = nextItem.id;
          context.push(
            '/play/${nextItem.id}',
            extra: PlaybackArgs(
              item: nextItem,
              playbackInfo: nextInfo,
              startPositionTicks: nextItem.playbackPositionTicks ?? 0,
              selectedAudio: audio,
              selectedSubtitle: subtitle,
            ),
          );
          return;
        }

        final playable = item.type == 'Movie' || item.type == 'Episode' || item.type == 'Video';
        if (!playable) {
          if (!context.mounted) return;
          context.push('/details/${item.id}');
          return;
        }

        final fullItem = await services.hermes.getItem(item.id);
        final info = await services.apollo.getPlaybackInfo(
          fullItem.id,
          maxStreamingBitrate: prefs.maxStreamingBitrate(),
        );
        final audio = prefs.pickAudio(info.audioStreams);
        if (!context.mounted || audio == null) return;
        final subtitle = prefs.pickSubtitle(info.subtitleStreams);
        AppUiScope.of(context).lastPlaybackItemId.value = fullItem.id;
        context.push(
          '/play/${fullItem.id}',
          extra: PlaybackArgs(
            item: fullItem,
            playbackInfo: info,
            startPositionTicks: fullItem.playbackPositionTicks ?? 0,
            selectedAudio: audio,
            selectedSubtitle: subtitle,
          ),
        );
      });
    } catch (_) {}
  }

  Future<void> _openTrendingItem({
    required BuildContext context,
    required AppServices services,
    required ArtemisRecommendationItem item,
  }) async {
    try {
      await _withLoading(context, () async {
        final libraryItem = await services.hermes.findByTmdbId(
          tmdbId: item.tmdbId,
          includeItemType: item.mediaType == MediaType.movie ? 'Movie' : 'Series',
        );
        if (!context.mounted) return;
        if (libraryItem != null) {
          context.push('/details/${libraryItem.id}');
          return;
        }
        final type = item.mediaType == MediaType.movie ? 'movie' : 'tv';
        context.push('/request/$type/${item.tmdbId}', extra: item);
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

final class _HomeData {
  const _HomeData({
    required this.movies,
    required this.shows,
    required this.latestMovies,
    required this.latestShows,
    required this.recentMovies,
    required this.recentShows,
    required this.continueWatching,
    required this.becauseTitle,
    required this.becauseItems,
    required this.enjoyTitle,
    required this.enjoyItems,
    required this.bingeTitle,
    required this.bingeItems,
    required this.topRatedMovies,
    required this.topRatedShows,
  });

  final List<EmbyItem> movies;
  final List<EmbyItem> shows;
  final List<EmbyItem> latestMovies;
  final List<EmbyItem> latestShows;
  final List<EmbyItem> recentMovies;
  final List<EmbyItem> recentShows;
  final List<_ContinueWatchingEntry> continueWatching;
  final String? becauseTitle;
  final List<EmbyItem> becauseItems;
  final String? enjoyTitle;
  final List<EmbyItem> enjoyItems;
  final String? bingeTitle;
  final List<EmbyItem> bingeItems;
  final List<EmbyItem> topRatedMovies;
  final List<EmbyItem> topRatedShows;
}

final class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.onViewAll});

  final String title;
  final Widget child;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
              if (onViewAll != null)
                TextButton(
                  onPressed: onViewAll,
                  child: Text(context.l10n.viewAll),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

final class _HeroCarouselSkeleton extends StatelessWidget {
  const _HeroCarouselSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: const AspectRatio(
          aspectRatio: 16 / 5,
          child: OttSkeleton(borderRadius: 22),
        ),
      ),
    );
  }
}

final class _HorizontalPosterSkeleton extends StatelessWidget {
  const _HorizontalPosterSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: OttSkeletonList(
        itemCount: 8,
        itemBuilder: (context, index) => const OttSkeleton(
          width: 160,
          height: 240,
          borderRadius: 16,
        ),
      ),
    );
  }
}

final class _HorizontalThumbSkeleton extends StatelessWidget {
  const _HorizontalThumbSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: OttSkeletonList(
        itemCount: 6,
        itemBuilder: (context, index) => const OttSkeleton(
          width: 320,
          height: 180,
          borderRadius: 16,
        ),
      ),
    );
  }
}

final class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel({
    required this.items,
    required this.onOpenDetails,
    required this.onPlay,
  });

  final List<EmbyItem> items;
  final ValueChanged<String> onOpenDetails;
  final ValueChanged<EmbyItem> onPlay;

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

final class _HeroCarouselState extends State<_HeroCarousel> {
  late final PageController _controller;
  Timer? _timer;
  var _page = 0;
  int? _lastPrefetchBase;
  int? _lastPrefetchItemCount;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
      _prefetchAround(_page);
    });
  }

  @override
  void didUpdateWidget(covariant _HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _page = _page.clamp(0, max(0, widget.items.length - 1));
      _lastPrefetchBase = null;
      _lastPrefetchItemCount = null;
      _startAutoScroll();
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefetchAround(_page));
    }
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = null;
    if (!mounted) return;
    if (widget.items.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 9), (_) async {
      final count = widget.items.length;
      if (!mounted || count <= 1) return;
      if (!_controller.hasClients) return;
      _page = (_page + 1) % count;
      _prefetchAround(_page);
      await _controller.animateToPage(
        _page,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _prefetchAround(int base) {
    if (!mounted) return;
    final items = widget.items;
    if (items.isEmpty) return;
    if (_lastPrefetchBase == base && _lastPrefetchItemCount == items.length) return;
    _lastPrefetchBase = base;
    _lastPrefetchItemCount = items.length;

    final services = AppServicesScope.of(context);
    final count = items.length;
    final maxOffset = min(2, count - 1);
    for (var offset = 0; offset <= maxOffset; offset++) {
      final i = (base + offset) % count;
      final item = items[i];
      final imageUri = services.hermes.thumbImageUri(item, maxWidth: 1600);
      precacheImage(NetworkImage(imageUri.toString()), context);
      final logoUri = services.hermes.logoImageUri(item, maxWidth: 900);
      if (logoUri != null) {
        precacheImage(NetworkImage(logoUri.toString()), context);
      }
    }
  }

  void _goTo(int index) {
    final count = widget.items.length;
    if (count <= 1) return;
    final next = index % count;
    _page = next;
    _startAutoScroll();
    _prefetchAround(next);
    if (!_controller.hasClients) return;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: 16 / 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _controller,
                onPageChanged: (i) {
                  _page = i;
                  _prefetchAround(i);
                },
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final imageUri = services.hermes.thumbImageUri(item, maxWidth: 1600);
                  final logoUri = services.hermes.logoImageUri(item, maxWidth: 900);
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        imageUri.toString(),
                        fit: BoxFit.cover,
                        alignment: Alignment.centerRight,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) =>
                            const ColoredBox(color: Colors.black12),
                      ),
                      const IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              stops: [0.0, 0.55, 1.0],
                              colors: [
                                Color(0xF2000000),
                                Color(0x99000000),
                                Color(0x00000000),
                              ],
                            ),
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
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const leftGutter = 22.0;
                            const navButtonSpace = 64.0;
                            const rightGutter = 22.0;
                            final maxTextWidth = min(760.0, constraints.maxWidth * 0.56);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 22),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const SizedBox(width: leftGutter + navButtonSpace),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: maxTextWidth),
                                    child: _HeroTextBlock(
                                      title: item.name,
                                      overview: (item.overview ?? '').trim(),
                                      logoUri: logoUri,
                                      onPlay: () => widget.onPlay(item),
                                      onMoreInfo: () => widget.onOpenDetails(item.id),
                                    ),
                                  ),
                                  const Spacer(),
                                  const SizedBox(width: rightGutter + navButtonSpace),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              Positioned(
                left: 12,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _HeroNavButton(
                    icon: Icons.chevron_left,
                    onPressed: () => _goTo((_page - 1) < 0 ? items.length - 1 : _page - 1),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _HeroNavButton(
                    icon: Icons.chevron_right,
                    onPressed: () => _goTo(_page + 1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _HeroNavButton extends StatelessWidget {
  const _HeroNavButton({required this.icon, required this.onPressed});

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

final class _HeroTextBlock extends StatelessWidget {
  const _HeroTextBlock({
    required this.title,
    required this.overview,
    required this.logoUri,
    required this.onPlay,
    required this.onMoreInfo,
  });

  final String title;
  final String overview;
  final Uri? logoUri;
  final VoidCallback onPlay;
  final VoidCallback onMoreInfo;

  @override
  Widget build(BuildContext context) {
    final logo = logoUri;
    final baseTitleStyle = Theme.of(context).textTheme.displayLarge ??
        Theme.of(context).textTheme.displayMedium ??
        const TextStyle(fontSize: 48);
    final titleStyle = baseTitleStyle.copyWith(
      fontWeight: FontWeight.w900,
      height: 1.02,
      shadows: const [
        Shadow(
          blurRadius: 18,
          color: Colors.black,
          offset: Offset(0, 2),
        ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (logo != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120, maxWidth: 640),
            child: Image.network(
              logo.toString(),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                return Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                );
              },
            ),
          )
        else
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
        if (overview.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            overview,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.90),
                  shadows: const [
                    Shadow(
                      blurRadius: 18,
                      color: Colors.black,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow),
              label: Text(context.l10n.play),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: onMoreInfo,
              icon: const Icon(Icons.info_outline),
              label: Text(context.l10n.moreInfo),
            ),
          ],
        ),
      ],
    );
  }
}

final class _PosterRow extends StatelessWidget {
  const _PosterRow({
    required this.items,
    required this.onOpenDetails,
  });

  final List<EmbyItem> items;
  final ValueChanged<String> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: _HorizontalRowList(
        height: 240,
        itemCount: min(30, items.length),
        itemBuilder: (context, index) {
          final item = items[index];
          return _PosterCard(
            item: item,
            imageUri: services.hermes.primaryImageUri(item, maxWidth: 360),
            onOpenDetails: () => onOpenDetails(item.id),
          );
        },
      ),
    );
  }
}

final class _TrendingRow extends StatelessWidget {
  const _TrendingRow({
    required this.items,
    required this.onOpen,
  });

  final List<ArtemisRecommendationItem> items;
  final ValueChanged<ArtemisRecommendationItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: _HorizontalRowList(
        height: 180,
        itemCount: min(30, items.length),
        itemBuilder: (context, index) {
          final item = items[index];
          return _TrendingPosterCard(
            item: item,
            imageUri: _tmdbBackdropUri(item.backdropPath) ?? _tmdbPosterUri(item.posterPath),
            onOpen: () => onOpen(item),
          );
        },
      ),
    );
  }
}

final class _TrendingUnavailable extends StatelessWidget {
  const _TrendingUnavailable();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Center(
        child: Text(
          context.l10n.trendingUnavailable,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70),
              ),
        ),
      ),
    );
  }
}

final class _TrendingPosterCard extends StatelessWidget {
  const _TrendingPosterCard({
    required this.item,
    required this.imageUri,
    required this.onOpen,
  });

  final ArtemisRecommendationItem item;
  final Uri? imageUri;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 180,
      child: Stack(
        fit: StackFit.expand,
        children: [
          OttFocusableCard(
            onPressed: onOpen,
            borderRadius: 16,
            child: imageUri == null
                ? const ColoredBox(color: Colors.black12)
                : Image.network(
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
                    Color(0xE6000000),
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
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _WideRow extends StatelessWidget {
  const _WideRow({
    required this.items,
    required this.onOpenDetails,
  });

  final List<EmbyItem> items;
  final ValueChanged<String> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: _HorizontalRowList(
        height: 210,
        itemCount: min(20, items.length),
        itemBuilder: (context, index) {
          final item = items[index];
          return _WideCard(
            title: item.name,
            imageUri: services.hermes.thumbImageUri(item, maxWidth: 1000),
            onOpen: () => onOpenDetails(item.id),
          );
        },
      ),
    );
  }
}

final class _WideCard extends StatelessWidget {
  const _WideCard({
    required this.title,
    required this.imageUri,
    required this.onOpen,
  });

  final String title;
  final Uri imageUri;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 380,
      height: 210,
      child: Stack(
        fit: StackFit.expand,
        children: [
          OttFocusableCard(
            onPressed: onOpen,
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
                    Color(0xE6000000),
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
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _CinematicRow extends StatelessWidget {
  const _CinematicRow({
    required this.items,
    required this.onOpenDetails,
  });

  final List<EmbyItem> items;
  final ValueChanged<String> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: _HorizontalRowList(
        height: 236,
        itemCount: min(14, items.length),
        itemBuilder: (context, index) {
          final item = items[index];
          return _CinematicCard(
            title: item.name,
            imageUri: services.hermes.thumbImageUri(item, maxWidth: 1400),
            onOpen: () => onOpenDetails(item.id),
          );
        },
      ),
    );
  }
}

final class _CinematicCard extends StatelessWidget {
  const _CinematicCard({
    required this.title,
    required this.imageUri,
    required this.onOpen,
  });

  final String title;
  final Uri imageUri;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      height: 236,
      child: Stack(
        fit: StackFit.expand,
        children: [
          OttFocusableCard(
            onPressed: onOpen,
            borderRadius: 18,
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
                    Color(0xEE000000),
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _TopRatedRow extends StatelessWidget {
  const _TopRatedRow({
    required this.items,
    required this.onOpenDetails,
  });

  final List<EmbyItem> items;
  final ValueChanged<String> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: _HorizontalRowList(
        height: 270,
        itemCount: min(10, items.length),
        itemBuilder: (context, index) {
          final item = items[index];
          return _TopRatedCard(
            rank: index + 1,
            title: item.name,
            rating: item.communityRating,
            imageUri: services.hermes.thumbImageUri(item, maxWidth: 1600),
            onOpen: () => onOpenDetails(item.id),
          );
        },
      ),
    );
  }
}

final class _TopRatedCard extends StatelessWidget {
  const _TopRatedCard({
    required this.rank,
    required this.title,
    required this.rating,
    required this.imageUri,
    required this.onOpen,
  });

  final int rank;
  final String title;
  final double? rating;
  final Uri imageUri;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final r = rating;
    final ratingText = r == null ? '' : r.toStringAsFixed(1);
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 520,
      height: 270,
      child: Stack(
        fit: StackFit.expand,
        children: [
          OttFocusableCard(
            onPressed: onOpen,
            borderRadius: 20,
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
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: [0.0, 0.55, 1.0],
                  colors: [
                    Color(0x00000000),
                    Color(0xB3000000),
                    Color(0xF0000000),
                  ],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$rank',
                  maxLines: 1,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 220,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: -8,
                        color: Colors.white.withValues(alpha: 0.26),
                      ),
                ),
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
                    Color(0xF0000000),
                    Color(0x40000000),
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
          ),
          if (ratingText.isNotEmpty)
            Positioned(
              right: 16,
              top: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 18, color: scheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      ratingText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

Uri? _tmdbPosterUri(String? path) {
  final p = (path ?? '').trim();
  if (p.isEmpty) return null;
  return Uri.parse('https://image.tmdb.org/t/p/w342$p');
}

Uri? _tmdbBackdropUri(String? path) {
  final p = (path ?? '').trim();
  if (p.isEmpty) return null;
  return Uri.parse('https://image.tmdb.org/t/p/w780$p');
}

final class _ContinueWatchingEntry {
  const _ContinueWatchingEntry({required this.displayItem, required this.resumeItem});

  final EmbyItem displayItem;
  final EmbyItem resumeItem;
}

final class _ContinueWatchingRow extends StatelessWidget {
  const _ContinueWatchingRow({
    required this.items,
    required this.onOpenDetails,
    required this.onPlay,
  });

  final List<_ContinueWatchingEntry> items;
  final ValueChanged<String> onOpenDetails;
  final ValueChanged<EmbyItem> onPlay;

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: _HorizontalRowList(
        height: 180,
        itemCount: min(30, items.length),
        itemBuilder: (context, index) {
          final entry = items[index];
          final progress = _progressFactor(entry.resumeItem);
          return _ContinueWatchingCard(
            item: entry.displayItem,
            hasProgress: (entry.resumeItem.playbackPositionTicks ?? 0) > 0,
            progress: progress,
            imageUri: services.hermes.thumbImageUri(entry.displayItem, maxWidth: 900),
            onOpenDetails: () => onOpenDetails(entry.displayItem.id),
            onPlay: () => onPlay(entry.displayItem),
          );
        },
      ),
    );
  }
}

final class _ContinueWatchingCard extends StatelessWidget {
  const _ContinueWatchingCard({
    required this.item,
    required this.hasProgress,
    required this.progress,
    required this.imageUri,
    required this.onOpenDetails,
    required this.onPlay,
  });

  final EmbyItem item;
  final bool hasProgress;
  final double progress;
  final Uri imageUri;
  final VoidCallback onOpenDetails;
  final VoidCallback onPlay;

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
                    Color(0xD6000000),
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
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (hasProgress) ...[
                        const SizedBox(height: 6),
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: Colors.transparent,
                  child: InkResponse(
                    onTap: onPlay,
                    radius: 24,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                      ),
                      child: const Icon(Icons.play_arrow, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _PosterCard extends StatelessWidget {
  const _PosterCard({
    required this.item,
    required this.imageUri,
    required this.onOpenDetails,
  });

  final EmbyItem item;
  final Uri imageUri;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final hasProgress = (item.playbackPositionTicks ?? 0) > 0;
    final progress = _progressFactor(item);
    return SizedBox(
      width: 160,
      height: 240,
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
                    Color(0xE6000000),
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: hasProgress ? 12 : 10,
            child: Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (hasProgress)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 4,
                color: Colors.white.withValues(alpha: 0.14),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

double _progressFactor(EmbyItem item) {
  final pos = (item.playbackPositionTicks ?? 0).clamp(0, 1 << 62);
  if (pos <= 0) return 0;
  final pct = item.playedPercentage;
  if (pct != null && pct > 0) {
    return (pct / 100).clamp(0.0, 1.0);
  }
  final rt = (item.runTimeTicks ?? 0).clamp(0, 1 << 62);
  if (rt <= 0) return 0.6;
  return (pos / rt).clamp(0.0, 1.0);
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
      height: widget.height + 28,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            itemCount: widget.itemCount,
            padding: const EdgeInsets.symmetric(vertical: 14),
            clipBehavior: Clip.none,
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
                child: _HeroNavButton(
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
                child: _HeroNavButton(
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

