import 'dart:async';
import 'dart:math';
 
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
 
import '../../app/app.dart';
import '../../app/services/app_services.dart';
import '../../core/emby/models/emby_item.dart';
import '../../l10n/l10n.dart';
import '../../services/artemis/artemis_service.dart';
import '../widgets/ott_focusable.dart';
import '../widgets/ott_shimmer.dart';
 
final class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.initialQuery});
 
  final String initialQuery;
 
  @override
  State<SearchPage> createState() => _SearchPageState();
}
 
final class _SearchPageState extends State<SearchPage> with RouteAware {
  AppServices? _services;
  late final TextEditingController _controller;
  Timer? _debounce;
  String _query = '';
  Future<_SearchResults>? _future;
  PageRoute<dynamic>? _route;
 
  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery.trim();
    _controller = TextEditingController(text: _query);
    _controller.addListener(_onQueryChanged);
  }
 
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _services ??= AppServicesScope.of(context);
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && _route != route) {
      if (_route != null) appRouteObserver.unsubscribe(this);
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
    if (_future == null && _query.isNotEmpty) {
      _future = _search(_query);
    }
  }
 
  @override
  void dispose() {
    if (_route != null) appRouteObserver.unsubscribe(this);
    _debounce?.cancel();
    _debounce = null;
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didPopNext() => _refresh();

  void _refresh() {
    if (_query.isEmpty) return;
    setState(() {
      _future = _search(_query);
    });
  }
 
  void _onQueryChanged() {
    final next = _controller.text.trim();
    if (next == _query) return;
    _query = next;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _future = _query.isEmpty ? null : _search(_query);
      });
    });
  }
 
  Future<_SearchResults> _search(String query) async {
    final services = _services!;
    final libraryFuture = services.hermes.search(query: query, limit: 60);
    final requestableFuture = services.artemis.search(query: query, limit: 40).catchError((_) {
      return const <ArtemisRecommendationItem>[];
    });
    final res = await Future.wait<Object>([
      libraryFuture,
      requestableFuture,
    ]);
    return _SearchResults(
      library: res[0] as List<EmbyItem>,
      requestable: res[1] as List<ArtemisRecommendationItem>,
    );
  }
 
  @override
  Widget build(BuildContext context) {
    final services = _services;
    if (services == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
 
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surface,
                  scheme.surface.withValues(alpha: 0.0),
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
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
                    child: _SearchHeader(
                      controller: _controller,
                      onClear: () {
                        _controller.text = '';
                        _controller.selection = const TextSelection.collapsed(offset: 0);
                      },
                      onSubmitted: (value) {
                        final q = value.trim();
                        setState(() => _future = q.isEmpty ? null : _search(q));
                      },
                    ),
                  ),
                ),
                if (_future == null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
                      child: _SearchEmptyState(
                        onTryExample: (q) {
                          _controller.text = q;
                          _controller.selection =
                              TextSelection.collapsed(offset: _controller.text.length);
                          setState(() => _future = _search(q));
                        },
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
                    sliver: SliverToBoxAdapter(
                      child: FutureBuilder<_SearchResults>(
                        future: _future,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState != ConnectionState.done) {
                            return const _SearchGridSkeleton();
                          }
                          if (snapshot.hasError) {
                            return _SearchErrorState(error: snapshot.error);
                          }

                          final data = snapshot.data;
                          final library = data?.library ?? const <EmbyItem>[];
                          final requestable =
                              data?.requestable ?? const <ArtemisRecommendationItem>[];
                          if (library.isEmpty && requestable.isEmpty) {
                            return _SearchNoResults(query: _query);
                          }

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              const tileWidth = 340.0;
                              final cols = max(2, (constraints.maxWidth / tileWidth).floor());
                              final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: 16 / 10,
                              );

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (library.isNotEmpty) ...[
                                    _SectionHeader(
                                      title: l10n.availableSectionTitle,
                                      subtitle: l10n.availableSectionSubtitle,
                                      count: library.length,
                                    ),
                                    const SizedBox(height: 12),
                                    _SearchRail(
                                      itemCount: min(10, library.length),
                                      itemBuilder: (context, index) {
                                        final item = library[index];
                                        return _WideCard(
                                          child: _SearchResultCard(
                                            item: item,
                                            imageUri: services.hermes.thumbImageUri(
                                              item,
                                              maxWidth: 1200,
                                            ),
                                            onOpen: () => context.push('/details/${item.id}'),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    if (library.length > 10)
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        gridDelegate: gridDelegate,
                                        itemCount: library.length - 10,
                                        itemBuilder: (context, index) {
                                          final item = library[index + 10];
                                          return _SearchResultCard(
                                            item: item,
                                            imageUri: services.hermes.thumbImageUri(
                                              item,
                                              maxWidth: 1000,
                                            ),
                                            onOpen: () => context.push('/details/${item.id}'),
                                          );
                                        },
                                      ),
                                  ],
                                  if (library.isNotEmpty && requestable.isNotEmpty)
                                    const SizedBox(height: 26),
                                  if (requestable.isNotEmpty) ...[
                                    _SectionHeader(
                                      title: l10n.requestableSectionTitle,
                                      subtitle: l10n.requestableSectionSubtitle,
                                      count: requestable.length,
                                    ),
                                    const SizedBox(height: 12),
                                    _SearchRail(
                                      itemCount: min(10, requestable.length),
                                      itemBuilder: (context, index) {
                                        final item = requestable[index];
                                        final uri = _tmdbBackdropUri(item.backdropPath) ??
                                            _tmdbPosterUri(item.posterPath);
                                        return _WideCard(
                                          child: _ArtemisSearchResultCard(
                                            item: item,
                                            imageUri: uri,
                                            onOpen: () {
                                              context.push(
                                                '/request/${_encodeMediaType(item.mediaType)}/${item.tmdbId}',
                                                extra: item,
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    if (requestable.length > 10)
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        gridDelegate: gridDelegate,
                                        itemCount: requestable.length - 10,
                                        itemBuilder: (context, index) {
                                          final item = requestable[index + 10];
                                          final uri = _tmdbBackdropUri(item.backdropPath) ??
                                              _tmdbPosterUri(item.posterPath);
                                          return _ArtemisSearchResultCard(
                                            item: item,
                                            imageUri: uri,
                                            onOpen: () {
                                              context.push(
                                                '/request/${_encodeMediaType(item.mediaType)}/${item.tmdbId}',
                                                extra: item,
                                              );
                                            },
                                          );
                                        },
                                      ),
                                  ],
                                ],
                              );
                            },
                          );
                        },
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
 
final class _SearchResults {
  const _SearchResults({
    required this.library,
    required this.requestable,
  });

  final List<EmbyItem> library;
  final List<ArtemisRecommendationItem> requestable;
}

final class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.item,
    required this.imageUri,
    required this.onOpen,
  });
 
  final EmbyItem item;
  final Uri imageUri;
  final VoidCallback onOpen;
 
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final played = item.isPlayed;
    final resume = (item.playbackPositionTicks ?? 0) > 0 && !played;
    return SizedBox(
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
            left: 10,
            top: 10,
            child: IgnorePointer(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Badge(
                    label: l10n.badgeAvailable,
                    background: scheme.primary.withValues(alpha: 0.80),
                    foreground: scheme.onPrimary,
                  ),
                  if (played || resume) ...[
                    const SizedBox(width: 8),
                    _Badge(
                      label: played ? l10n.badgePlayed : l10n.badgeResume,
                      background: scheme.surfaceContainerHighest.withValues(alpha: 0.70),
                      foreground: scheme.onSurface,
                    ),
                  ],
                ],
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
 
final class _ArtemisSearchResultCard extends StatelessWidget {
  const _ArtemisSearchResultCard({
    required this.item,
    required this.imageUri,
    required this.onOpen,
  });

  final ArtemisRecommendationItem item;
  final Uri? imageUri;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final typeLabel = item.mediaType == MediaType.movie ? l10n.badgeMovie : l10n.badgeTv;
    return SizedBox(
      child: Stack(
        fit: StackFit.expand,
        children: [
          OttFocusableCard(
            onPressed: onOpen,
            borderRadius: 16,
            child: imageUri == null
                ? const ColoredBox(color: Colors.black12)
                : ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0, 0, 0, 1, 0,
                    ]),
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
                    Color(0xE6000000),
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 10,
            child: IgnorePointer(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Badge(
                    label: l10n.badgeRequest,
                    background: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
                    foreground: scheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  _Badge(
                    label: typeLabel,
                    background: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
                    foreground: scheme.onSurface,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Text(
              item.title,
              maxLines: 1,
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

final class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.onClear,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: scheme.onSurface.withValues(alpha: 0.65), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  border: InputBorder.none,
                  isDense: true,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: onSubmitted,
              ),
            ),
            IconButton(
              tooltip: l10n.clear,
              onPressed: onClear,
              icon: const Icon(Icons.close),
              visualDensity: VisualDensity.compact,
              splashRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}

final class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.70),
                    ),
              ),
            ],
          ),
        ),
        _Badge(
          label: '$count',
          background: scheme.surfaceContainerHighest.withValues(alpha: 0.70),
          foreground: scheme.onSurface,
        ),
      ],
    );
  }
}

final class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: ColoredBox(
        color: background,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
          ),
        ),
      ),
    );
  }
}

final class _SearchRail extends StatelessWidget {
  const _SearchRail({
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 0) return const SizedBox.shrink();
    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        clipBehavior: Clip.none,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: itemBuilder,
      ),
    );
  }
}

final class _WideCard extends StatelessWidget {
  const _WideCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      child: child,
    );
  }
}

final class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({
    required this.onTryExample,
  });

  final ValueChanged<String> onTryExample;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 44, color: scheme.onSurface.withValues(alpha: 0.55)),
            const SizedBox(height: 14),
            Text(
              l10n.searchEmptyTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.searchEmptySubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.72),
                  ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => onTryExample('Dune'),
                  child: Text(l10n.tryQuery('Dune')),
                ),
                OutlinedButton(
                  onPressed: () => onTryExample('Batman'),
                  child: Text(l10n.tryQuery('Batman')),
                ),
                OutlinedButton(
                  onPressed: () => onTryExample('One Piece'),
                  child: Text(l10n.tryQuery('One Piece')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _SearchNoResults extends StatelessWidget {
  const _SearchNoResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 44, color: scheme.onSurface.withValues(alpha: 0.55)),
            const SizedBox(height: 14),
            Text(
              l10n.noResults,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              query.trim().isEmpty ? l10n.tryDifferentTitle : l10n.nothingMatched(query),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.72),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _SearchErrorState extends StatelessWidget {
  const _SearchErrorState({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: scheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.searchFailed,
                    style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$error',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.75),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _SearchGridSkeleton extends StatelessWidget {
  const _SearchGridSkeleton();
 
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const itemWidth = 220.0;
        final cols = max(2, (constraints.maxWidth / itemWidth).floor());
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 16 / 9,
          ),
          itemCount: cols * 4,
          itemBuilder: (context, index) {
            return const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              child: OttSkeleton(borderRadius: 16),
            );
          },
        );
      },
    );
  }
}

Uri? _tmdbBackdropUri(String? path) {
  final p = (path ?? '').trim();
  if (p.isEmpty) return null;
  return Uri.parse('https://image.tmdb.org/t/p/w780$p');
}

Uri? _tmdbPosterUri(String? path) {
  final p = (path ?? '').trim();
  if (p.isEmpty) return null;
  return Uri.parse('https://image.tmdb.org/t/p/w500$p');
}

String _encodeMediaType(MediaType type) {
  switch (type) {
    case MediaType.movie:
      return 'movie';
    case MediaType.tv:
      return 'tv';
  }
}
 
