import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app.dart';
import '../../app/app.dart';
import '../../app/services/app_services.dart';
import '../../core/emby/models/emby_item.dart';
import '../widgets/ott_focusable.dart';
import '../widgets/ott_shimmer.dart';
import '../widgets/tv_sidebar_shell.dart' show isTvPlatform;

typedef _CollectionData = ({EmbyItem collection, List<EmbyItem> items});

final class CollectionDetailPage extends StatefulWidget {
  const CollectionDetailPage({super.key, required this.collectionId});

  final String collectionId;

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

final class _CollectionDetailPageState extends State<CollectionDetailPage> {
  Future<_CollectionData>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load(AppServicesScope.of(context));
  }

  Future<_CollectionData> _load(AppServices services) async {
    final results = await Future.wait([
      services.hermes.getItem(widget.collectionId),
      services.hermes.getCollectionItems(widget.collectionId),
    ]);
    return (
      collection: results[0] as EmbyItem,
      items: results[1] as List<EmbyItem>,
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);
    return FutureBuilder<_CollectionData>(
      future: _future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        final data = snapshot.data;

        final backdropUri = data == null
            ? null
            : services.hermes.thumbImageUri(data.collection, maxWidth: 1920);

        return Scaffold(
          backgroundColor: const Color(0xFF0B0D10),
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (backdropUri != null)
                Image.network(
                  backdropUri.toString(),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: Color(0xFF0B0D10)),
                ),

              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: [0.0, 0.42, 0.68, 1.0],
                    colors: [
                      Color(0xFF0B0D10),
                      Color(0xF00B0D10),
                      Color(0xA00B0D10),
                      Color(0x660B0D10),
                    ],
                  ),
                ),
              ),

              SafeArea(
                bottom: false,
                child: loading
                    ? const _Skeleton()
                    : snapshot.hasError
                        ? _ErrorBody(error: snapshot.error)
                        : _Body(data: data!, services: services),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

final class _Body extends StatelessWidget {
  const _Body({required this.data, required this.services});

  final _CollectionData data;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final collection = data.collection;
    final items = data.items;
    final logoUri = services.hermes.logoImageUri(collection, maxWidth: 900);
    final overview = (collection.overview ?? '').trim();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _BackRow(
            trailing: Text(
              '${items.length} ${items.length == 1 ? 'title' : 'titles'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                  ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 32, 22, 0),
            child: _Header(
              collection: collection,
              logoUri: logoUri,
              overview: overview,
              itemCount: items.length,
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        if (items.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                'No items found in this collection.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
              ),
            ),
          )
        else
          SliverLayoutBuilder(
            builder: (context, constraints) {
              final cols =
                  (constraints.crossAxisExtent / 160).floor().clamp(3, 8);
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2 / 3,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    childCount: items.length,
                    (context, i) {
                      final item = items[i];
                      return _PosterTile(
                        item: item,
                        imageUri: services.hermes
                            .primaryImageUri(item, maxWidth: 420),
                        onPressed: () =>
                            context.push('/details/${item.id}'),
                      );
                    },
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

final class _BackRow extends StatelessWidget {
  const _BackRow({this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 26),
            onPressed: () => context.pop(),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

final class _Header extends StatelessWidget {
  const _Header({
    required this.collection,
    required this.logoUri,
    required this.overview,
    required this.itemCount,
  });

  final EmbyItem collection;
  final Uri? logoUri;
  final String overview;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surfaceContainerHighest;

    Widget inner = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (logoUri != null)
          ConstrainedBox(
            constraints:
                const BoxConstraints(maxHeight: 110, maxWidth: 600),
            child: Image.network(
              logoUri.toString(),
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) =>
                  _TitleText(collection.name),
            ),
          )
        else
          _TitleText(collection.name),

        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _Badge(
                label:
                    '$itemCount ${itemCount == 1 ? 'title' : 'titles'}'),
            if (collection.productionYear != null)
              _Badge(label: '${collection.productionYear}'),
          ],
        ),

        if (overview.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            overview,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
              height: 1.5,
            ),
          ),
        ],
      ],
    );

    if (isTvPlatform) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.09)),
        ),
        child: inner,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surface.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: inner,
        ),
      ),
    );
  }
}

final class _TitleText extends StatelessWidget {
  const _TitleText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.08,
          ),
    );
  }
}

final class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: primary.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

final class _PosterTile extends StatelessWidget {
  const _PosterTile({
    required this.item,
    required this.imageUri,
    required this.onPressed,
  });

  final EmbyItem item;
  final Uri imageUri;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final pct = item.playedPercentage;
    final hasProgress = !item.isPlayed && pct != null && pct > 0;

    return OttFocusableCard(
      onPressed: onPressed,
      borderRadius: 14,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            imageUri.toString(),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: Colors.black26),
          ),

          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xCC000000), Color(0x00000000)],
                ),
              ),
            ),
          ),

          Positioned(
            left: 10,
            right: 10,
            bottom: hasProgress ? 18 : 10,
            child: Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),

          if (hasProgress)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: (pct / 100.0).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),

          if (item.isPlayed)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Skeleton & error ──────────────────────────────────────────────────────────

final class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 26),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 32, 22, 28),
            child: OttSkeleton(
              width: double.infinity,
              height: 170,
              borderRadius: 20,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2 / 3,
            ),
            delegate: SliverChildBuilderDelegate(
              childCount: 20,
              (_, __) => const OttSkeleton(borderRadius: 14),
            ),
          ),
        ),
      ],
    );
  }
}

final class _ErrorBody extends StatelessWidget {
  const _ErrorBody({this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _BackRow(),
        ),
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text('$error'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
