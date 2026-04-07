import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app.dart';
import '../../core/emby/models/emby_item.dart';
import '../../l10n/l10n.dart';
import '../widgets/ott_focusable.dart';
import '../widgets/ott_shimmer.dart';

enum LibraryType {
  movies,
  series,
}

LibraryType? parseLibraryType(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'movies':
      return LibraryType.movies;
    case 'series':
    case 'shows':
      return LibraryType.series;
  }
  return null;
}

final class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.type});

  final LibraryType type;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

final class _LibraryPageState extends State<LibraryPage> with RouteAware {
  static const _pageSize = 60;
  final _controller = ScrollController();
  final _filterButtonKey = GlobalKey();
  final _items = <EmbyItem>[];
  final Set<String> _selectedGenres = {};
  int? _selectedYear;
  PageRoute<dynamic>? _route;

  bool _loading = false;
  bool _hasMore = true;
  bool _loadMoreScheduled = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && _route != route) {
      if (_route != null) appRouteObserver.unsubscribe(this);
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
    if (_items.isEmpty && !_loading) {
      _loadMore();
    }
  }

  @override
  void didUpdateWidget(covariant LibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      _items.clear();
      _selectedGenres.clear();
      _selectedYear = null;
      _loading = false;
      _hasMore = true;
      _error = null;
      _loadMore();
    }
  }

  @override
  void dispose() {
    if (_route != null) appRouteObserver.unsubscribe(this);
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didPopNext() => _refresh();

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _items.clear();
      _loading = false;
      _hasMore = true;
      _error = null;
    });
    unawaited(_controller.animateTo(
      0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    ));
    _loadMore();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    if (!_hasMore || _loading) return;
    final remaining = _controller.position.maxScrollExtent - _controller.offset;
    if (remaining < 800) {
      _loadMore();
    }
  }

  void _scheduleLoadMore() {
    if (!mounted) return;
    if (_loading || !_hasMore) return;
    if (_loadMoreScheduled) return;
    _loadMoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoreScheduled = false;
      if (!mounted) return;
      if (_loading || !_hasMore) return;
      _loadMore();
    });
  }

  List<String> _includeTypes() {
    switch (widget.type) {
      case LibraryType.movies:
        return const ['Movie'];
      case LibraryType.series:
        return const ['Series'];
    }
  }

  String _title() {
    switch (widget.type) {
      case LibraryType.movies:
        return 'Movies';
      case LibraryType.series:
        return 'Series';
    }
  }

  Future<void> _loadMore() async {
    if (!mounted) return;
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final services = AppServicesScope.of(context);
    try {
      final page = await services.hermes.getLibraryItemsPage(
        includeItemTypes: _includeTypes(),
        startIndex: _items.length,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        _hasMore = page.length >= _pageSize;
        _loading = false;
      });
      _ensureEnoughMatches();
      _scheduleLoadMore();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final error = _error;
    final hasFilters = _selectedGenres.isNotEmpty || _selectedYear != null;
    final items = _filteredItems();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: Row(
                children: [
                  Text(
                    _title(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: context.l10n.filter,
                    onPressed: () => _openFilters(context),
                    key: _filterButtonKey,
                    icon: Icon(
                      Icons.filter_list,
                      color: hasFilters ? scheme.primary : null,
                    ),
                  ),
                ],
              ),
            ),
            if (hasFilters)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_selectedYear != null)
                        InputChip(
                          label: Text(context.l10n.yearChip(_selectedYear!)),
                          onDeleted: () => _applyFilters(genres: _selectedGenres, year: null),
                        ),
                      for (final g in _selectedGenres)
                        InputChip(
                          label: Text(g),
                          onDeleted: () {
                            final next = Set<String>.of(_selectedGenres);
                            next.remove(g);
                            _applyFilters(genres: next, year: _selectedYear);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            if (hasFilters) const SizedBox(height: 8),
            Expanded(
              child: error != null
                  ? Center(child: Text('$error'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final maxExtent = widget.type == LibraryType.movies ? 180.0 : 200.0;
                        final columns = max(2, (width / maxExtent).floor());
                        final childAspectRatio = widget.type == LibraryType.movies
                            ? 2 / 3
                            : 2 / 3;

                        if (_items.isEmpty && _loading) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: GridView.builder(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: childAspectRatio,
                              ),
                              itemCount: columns * 3,
                              itemBuilder: (context, index) {
                                return const OttSkeleton(borderRadius: 16);
                              },
                            ),
                          );
                        }

                        return NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n is ScrollEndNotification) _onScroll();
                            return false;
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: GridView.builder(
                              controller: _controller,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: childAspectRatio,
                              ),
                              itemCount: items.length + (_hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= items.length) {
                                  _scheduleLoadMore();
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.08),
                                      ),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  );
                                }
                                final item = items[index];
                                return _LibraryTile(
                                  item: item,
                                  imageUri: services.hermes.primaryImageUri(item, maxWidth: 420),
                                  onOpen: () => context.push('/details/${item.id}'),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFilters(BuildContext context) {
    final currentGenres = Set<String>.of(_selectedGenres);
    final currentYear = _selectedYear;
    final availableGenres = _availableGenres();
    final availableYears = _availableYears();

    final anchor = _anchorRect();
    final Future<_FilterResult?> future = anchor == null
        ? showModalBottomSheet<_FilterResult>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (context) {
              return SafeArea(
                top: false,
                child: _FilterSheet(
                  availableGenres: availableGenres,
                  availableYears: availableYears,
                  initialGenres: currentGenres,
                  initialYear: currentYear,
                ),
              );
            },
          )
        : showDialog<_FilterResult>(
            context: context,
            barrierColor: Colors.black.withValues(alpha: 0.35),
            builder: (context) {
              return _AnchoredPopup(
                anchor: anchor,
                child: _FilterSheet(
                  availableGenres: availableGenres,
                  availableYears: availableYears,
                  initialGenres: currentGenres,
                  initialYear: currentYear,
                ),
              );
            },
          );

    future.then((result) {
      if (!mounted || result == null) return;
      _applyFilters(genres: result.genres, year: result.year);
    });
  }

  Rect? _anchorRect() {
    final ctx = _filterButtonKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    final overlay = Overlay.of(ctx).context.findRenderObject();
    if (box is! RenderBox || overlay is! RenderBox) return null;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    return Rect.fromLTWH(topLeft.dx, topLeft.dy, box.size.width, box.size.height);
  }

  void _applyFilters({required Set<String> genres, required int? year}) {
    setState(() {
      _selectedGenres
        ..clear()
        ..addAll(genres);
      _selectedYear = year;
      _error = null;
    });
    if (_controller.hasClients) _controller.jumpTo(0);
    _ensureEnoughMatches();
  }

  List<EmbyItem> _filteredItems() {
    if (_selectedGenres.isEmpty && _selectedYear == null) return _items;
    return _items.where(_matches).toList(growable: false);
  }

  bool _matches(EmbyItem item) {
    final year = _selectedYear;
    if (year != null && item.productionYear != year) return false;
    if (_selectedGenres.isEmpty) return true;
    for (final g in item.genres) {
      if (_selectedGenres.contains(g)) return true;
    }
    return false;
  }

  List<String> _availableGenres() {
    final out = <String>{};
    for (final item in _items) {
      for (final g in item.genres) {
        if (g.trim().isNotEmpty) out.add(g.trim());
      }
    }
    final list = out.toList(growable: false);
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<int> _availableYears() {
    final out = <int>{};
    for (final item in _items) {
      final y = item.productionYear;
      if (y != null && y > 1800) out.add(y);
    }
    final list = out.toList(growable: false);
    list.sort((a, b) => b.compareTo(a));
    return list;
  }

  void _ensureEnoughMatches() {
    if (!mounted) return;
    if (_selectedGenres.isEmpty && _selectedYear == null) return;
    final matches = _filteredItems().length;
    if (matches >= 40) return;
    if (_hasMore && !_loading) {
      unawaited(_loadMore());
    }
  }
}

final class _AnchoredPopup extends StatelessWidget {
  const _AnchoredPopup({required this.anchor, required this.child});

  final Rect anchor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox;
    final overlaySize = overlayBox.size;

    const popupWidth = 460.0;
    const maxHeight = 560.0;
    const margin = 12.0;

    var left = anchor.right - popupWidth;
    left = left.clamp(margin, overlaySize.width - popupWidth - margin);

    var top = anchor.bottom + 10;
    top = top.clamp(margin, overlaySize.height - maxHeight - margin);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: popupWidth,
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: maxHeight),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: SingleChildScrollView(child: child),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _FilterResult {
  const _FilterResult({required this.genres, required this.year});

  final Set<String> genres;
  final int? year;
}

final class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.availableGenres,
    required this.availableYears,
    required this.initialGenres,
    required this.initialYear,
  });

  final List<String> availableGenres;
  final List<int> availableYears;
  final Set<String> initialGenres;
  final int? initialYear;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

final class _FilterSheetState extends State<_FilterSheet> {
  late final Set<String> _genres;
  int? _year;
  String _genreSearch = '';

  @override
  void initState() {
    super.initState();
    _genres = Set<String>.of(widget.initialGenres);
    _year = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    final filteredGenres = widget.availableGenres.where((g) {
      final term = _genreSearch.trim().toLowerCase();
      if (term.isEmpty) return true;
      return g.toLowerCase().contains(term);
    }).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(context.l10n.filters, style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _genres.clear();
                    _year = null;
                    _genreSearch = '';
                  });
                },
                child: Text(context.l10n.clear),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            key: ValueKey(_year),
            initialValue: _year,
            decoration: InputDecoration(labelText: context.l10n.releaseYear),
            items: <DropdownMenuItem<int?>>[
              DropdownMenuItem(value: null, child: Text(context.l10n.any)),
              ...widget.availableYears.map(
                (y) => DropdownMenuItem(value: y, child: Text('$y')),
              ),
            ],
            onChanged: (v) => setState(() => _year = v),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: context.l10n.genre,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _genreSearch = v),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in filteredGenres)
                    FilterChip(
                      label: Text(g),
                      selected: _genres.contains(g),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _genres.add(g);
                          } else {
                            _genres.remove(g);
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(
                _FilterResult(genres: _genres, year: _year),
              ),
              child: Text(context.l10n.apply),
            ),
          ),
        ],
      ),
    );
  }
}

final class _LibraryTile extends StatelessWidget {
  const _LibraryTile({
    required this.item,
    required this.imageUri,
    required this.onOpen,
  });

  final EmbyItem item;
  final Uri imageUri;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return OttFocusableCard(
      onPressed: onOpen,
      borderRadius: 16,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            imageUri.toString(),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const ColoredBox(color: Colors.black12),
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
            left: 10,
            right: 10,
            bottom: 10,
            child: Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
