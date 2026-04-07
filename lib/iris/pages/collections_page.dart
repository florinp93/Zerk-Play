import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app.dart';
import '../../app/services/app_services.dart';
import '../../core/emby/models/emby_item.dart';
import '../../l10n/l10n.dart';
import '../widgets/ott_focusable.dart';
import '../widgets/ott_shimmer.dart';

final class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

final class _CollectionsPageState extends State<CollectionsPage> with RouteAware {
  Future<List<EmbyItem>>? _future;
  PageRoute<dynamic>? _route;

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
    _future ??= services.hermes.getCollections(limit: 80);
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
      _future = services.hermes.getCollections(limit: 80);
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<EmbyItem>>(
          future: _future,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState != ConnectionState.done;
            final collections = snapshot.data ?? const <EmbyItem>[];

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
                    child: Row(
                      children: [
                        Text(
                          l10n.collections,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (loading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 22),
                      child: _CollectionSkeleton(),
                    ),
                  )
                else if (snapshot.hasError)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Text('${snapshot.error}'),
                    ),
                  )
                else if (collections.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Text(l10n.noCollectionsFound),
                    ),
                  )
                else
                  SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final twoCols = constraints.crossAxisExtent >= 900;
                      final cols = twoCols ? 2 : 1;
                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            crossAxisSpacing: 22,
                            mainAxisSpacing: 22,
                            mainAxisExtent: 500,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            childCount: collections.length,
                            (context, index) {
                              final c = collections[index];
                              return _CollectionSection(
                                collection: c,
                                services: services,
                                onOpenMovie: (id) => context.push('/details/$id'),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 22)),
              ],
            );
          },
        ),
      ),
    );
  }
}

final class _CollectionSection extends StatefulWidget {
  const _CollectionSection({
    required this.collection,
    required this.services,
    required this.onOpenMovie,
  });

  final EmbyItem collection;
  final AppServices services;
  final ValueChanged<String> onOpenMovie;

  @override
  State<_CollectionSection> createState() => _CollectionSectionState();
}

final class _CollectionSectionState extends State<_CollectionSection> {
  Future<List<EmbyItem>>? _moviesFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _moviesFuture ??= widget.services.hermes.getCollectionMovies(widget.collection.id, limit: 60);
  }

  @override
  Widget build(BuildContext context) {
    final collection = widget.collection;
    final services = widget.services;
    final backdropUri = services.hermes.thumbImageUri(collection, maxWidth: 1800);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              backdropUri.toString(),
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) => const ColoredBox(color: Colors.black12),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: [0.0, 0.62, 1.0],
                    colors: [
                      Color(0xF2000000),
                      Color(0x99000000),
                      Color(0x00000000),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
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
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CollectionHeader(collection: collection, services: services),
                const SizedBox(height: 14),
                FutureBuilder<List<EmbyItem>>(
                  future: _moviesFuture,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const _RowSkeleton();
                    }
                    if (snap.hasError) return const SizedBox.shrink();
                    final movies = (snap.data ?? const <EmbyItem>[])
                        .where((e) => e.type == 'Movie')
                        .toList(growable: false);
                    if (movies.isEmpty) return const SizedBox.shrink();
                    return _HorizontalRowList(
                      height: 240,
                      itemCount: movies.length,
                      itemBuilder: (context, index) {
                        final movie = movies[index];
                        return _MoviePosterCard(
                          title: movie.name,
                          imageUri: services.hermes.primaryImageUri(movie, maxWidth: 420),
                          onPressed: () => widget.onOpenMovie(movie.id),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _CollectionHeader extends StatelessWidget {
  const _CollectionHeader({required this.collection, required this.services});

  final EmbyItem collection;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final logoUri = services.hermes.logoImageUri(collection, maxWidth: 900);
    final overview = (collection.overview ?? '').trim();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (logoUri != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 110, maxWidth: 640),
              child: Image.network(
                logoUri.toString(),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) => Text(
                  collection.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                ),
              ),
            )
          else
            Text(
              collection.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
            ),
          if (overview.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              overview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.88),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _MoviePosterCard extends StatelessWidget {
  const _MoviePosterCard({
    required this.title,
    required this.imageUri,
    required this.onPressed,
  });

  final String title;
  final Uri imageUri;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 240,
      child: OttFocusableCard(
        onPressed: onPressed,
        borderRadius: 16,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUri.toString(),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) => const ColoredBox(color: Colors.black12),
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
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
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
              left: 0,
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
              right: 0,
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

final class _CollectionSkeleton extends StatelessWidget {
  const _CollectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCols = constraints.maxWidth >= 900;
        final cols = twoCols ? 2 : 1;
        final rows = twoCols ? 2 : 3;
        return Column(
          children: [
            for (var r = 0; r < rows; r++) ...[
              Row(
                children: [
                  for (var c = 0; c < cols; c++) ...[
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: const SizedBox(
                          height: 500,
                          child: OttSkeleton(borderRadius: 22),
                        ),
                      ),
                    ),
                    if (c != cols - 1) const SizedBox(width: 22),
                  ],
                ],
              ),
              const SizedBox(height: 22),
            ],
          ],
        );
      },
    );
  }
}

final class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: OttSkeletonList(
        itemCount: 6,
        itemBuilder: (context, index) => const OttSkeleton(
          width: 160,
          height: 240,
          borderRadius: 16,
        ),
      ),
    );
  }
}
