import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../app/services/app_services.dart';
import '../../l10n/l10n.dart';
import '../../services/artemis/artemis_service.dart';

final class RequestDetailsPage extends StatefulWidget {
  const RequestDetailsPage({
    super.key,
    required this.tmdbId,
    required this.mediaType,
    this.initial,
  });

  final int tmdbId;
  final MediaType mediaType;
  final ArtemisRecommendationItem? initial;

  @override
  State<RequestDetailsPage> createState() => _RequestDetailsPageState();
}

final class _RequestDetailsPageState extends State<RequestDetailsPage> with RouteAware {
  Future<_RequestData>? _future;
  bool _submitting = false;
  String? _error;
  PageRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && _route != route) {
      if (_route != null) appRouteObserver.unsubscribe(this);
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
    _future ??= _load(AppServicesScope.of(context));
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
      _error = null;
      _future = _load(services);
    });
  }

  Future<_RequestData> _load(AppServices services) async {
    final details = await services.artemis.getMediaDetails(
      tmdbId: widget.tmdbId,
      type: widget.mediaType,
    );
    final status = await services.artemis.getRequestStatus(
      tmdbId: widget.tmdbId,
      type: widget.mediaType,
    );
    return _RequestData(details: details, status: status);
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Scaffold(
      body: FutureBuilder<_RequestData>(
        future: _future,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState != ConnectionState.done;
          final failed = snapshot.hasError;
          final data = snapshot.data;
          final details = data?.details;
          final status = data?.status;

          final initial = widget.initial;
          final title = (details?.title ?? initial?.title ?? '').trim();
          final overview = (details?.overview ?? initial?.overview ?? '').trim();

          final bg = _tmdbBackdropUri(details?.backdropPath ?? initial?.backdropPath) ??
              _tmdbPosterUri(details?.posterPath ?? initial?.posterPath);
          final poster = _tmdbPosterUri(details?.posterPath ?? initial?.posterPath);

          final requested = status?.isRequested ?? false;
          final pending = status?.isPending ?? false;
          final requestLabel = loading
              ? l10n.loadingEllipsis
              : failed
                  ? l10n.unavailable
              : requested
                  ? (pending ? l10n.requested : l10n.processing)
                  : l10n.request;

          return Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                if (bg != null)
                  Image.network(
                    bg.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const ColoredBox(color: Colors.black12),
                  )
                else
                  const ColoredBox(color: Colors.black12),
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
                                  _Poster(uri: poster),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title.isEmpty ? l10n.request : title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineMedium
                                              ?.copyWith(fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 8),
                                        if (details?.year != null)
                                          Text(
                                            '${details!.year}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  color: scheme.onSurface.withValues(alpha: 0.82),
                                                ),
                                          ),
                                        const SizedBox(height: 12),
                                        if (overview.isNotEmpty)
                                          Text(
                                            overview,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(
                                                  color: scheme.onSurface.withValues(alpha: 0.86),
                                                ),
                                          ),
                                        const SizedBox(height: 18),
                                        Row(
                                          children: [
                                            FilledButton.icon(
                                              onPressed: (loading || requested || _submitting)
                                                  ? null
                                                  : failed
                                                  ? null
                                                  : () => _submitRequest(services),
                                              icon: const Icon(Icons.add),
                                              label: _submitting
                                                  ? const SizedBox(
                                                      height: 16,
                                                      width: 16,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                    )
                                                  : Text(requestLabel),
                                            ),
                                          ],
                                        ),
                                        if (failed) ...[
                                          const SizedBox(height: 12),
                                          Text(
                                            '${snapshot.error}',
                                            style: TextStyle(color: scheme.error),
                                          ),
                                        ],
                                        if (_error != null) ...[
                                          const SizedBox(height: 12),
                                          Text(_error!, style: TextStyle(color: scheme.error)),
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
                      const SliverToBoxAdapter(child: SizedBox(height: 28)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitRequest(AppServices services) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await services.artemis.requestItem('${widget.tmdbId}', widget.mediaType);
      if (!mounted) return;
      setState(() {
        _future = _load(services);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

final class _RequestData {
  const _RequestData({required this.details, required this.status});

  final ArtemisMediaDetails details;
  final ArtemisRequestStatus status;
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

final class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.52),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: child,
      ),
    );
  }
}

final class _Poster extends StatelessWidget {
  const _Poster({required this.uri});

  final Uri? uri;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 220,
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: uri == null
              ? const ColoredBox(color: Colors.black12)
              : Image.network(
                  uri.toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(color: Colors.black12),
                ),
        ),
      ),
    );
  }
}
