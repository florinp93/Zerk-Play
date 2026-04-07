import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'services/app_services.dart';
import '../services/artemis/artemis_service.dart';
import '../iris/pages/home_page.dart';
import '../iris/pages/login_page.dart';
import '../iris/pages/setup_page.dart';
import '../iris/pages/details_page.dart';
import '../iris/pages/collections_page.dart';
import '../iris/pages/library_page.dart';
import '../iris/pages/playback_page.dart';
import '../iris/pages/request_details_page.dart';
import '../iris/pages/search_page.dart';
import '../iris/settings/app_prefs.dart';
import '../iris/theme/ott_theme.dart';
import '../iris/widgets/app_shell.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import 'updater_wrapper.dart';

final appRouteObserver = RouteObserver<PageRoute<dynamic>>();
final appNavigatorKey = GlobalKey<NavigatorState>();

final class App extends StatefulWidget {
  const App({super.key, required this.services});

  final AppServices services;

  @override
  State<App> createState() => _AppState();
}

final class _AppState extends State<App> {
  late final ValueNotifier<bool> _isAuthenticated;
  late final ValueNotifier<bool> _isConfigured;
  late final ValueNotifier<String?> _lastPlaybackItemId;
  late final ValueNotifier<Locale?> _locale;
  late final ValueNotifier<bool> _showFeedbackButton;
  late final ValueNotifier<int> _homeRefreshTick;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _isAuthenticated = ValueNotifier<bool>(widget.services.janus.isAuthenticated);
    _isConfigured = ValueNotifier<bool>(widget.services.isConfigured);
    _lastPlaybackItemId = ValueNotifier<String?>(null);
    _locale = ValueNotifier<Locale?>(null);
    _showFeedbackButton = ValueNotifier<bool>(AppPrefs.defaults.showFeedbackButton);
    _homeRefreshTick = ValueNotifier<int>(0);
    AppPrefs.load().then((prefs) {
      _locale.value = prefs.toLocale();
      _showFeedbackButton.value = prefs.showFeedbackButton;
    });
    _router = GoRouter(
      navigatorKey: appNavigatorKey,
      initialLocation: '/',
      observers: [appRouteObserver],
      refreshListenable: Listenable.merge([_isAuthenticated, _isConfigured]),
      redirect: (context, state) {
        final configured = _isConfigured.value;
        final atSetup = state.matchedLocation == '/setup';
        if (!configured) return atSetup ? null : '/setup';

        final authed = _isAuthenticated.value;
        final atLogin = state.matchedLocation == '/login';
        if (!authed) return atLogin ? null : '/login';
        if (authed && atLogin) return '/';
        if (configured && atSetup) return authed ? '/' : '/login';
        return null;
      },
      routes: [
        GoRoute(
          path: '/setup',
          builder: (context, state) => const SetupPage(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: '/play/:id',
          builder: (context, state) => PlaybackPage(
            args: state.extra is PlaybackArgs ? state.extra as PlaybackArgs : null,
            itemId: state.pathParameters['id']!,
          ),
        ),
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomePage(),
            ),
            GoRoute(
              path: '/details/:id',
              builder: (context, state) => DetailsPage(
                itemId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/search',
              builder: (context, state) => SearchPage(
                initialQuery: (state.uri.queryParameters['q'] ?? '').trim(),
              ),
            ),
            GoRoute(
              path: '/library/:type',
              builder: (context, state) {
                final raw = state.pathParameters['type'] ?? '';
                final type = parseLibraryType(raw);
                if (type == null) {
                  return Scaffold(body: Center(child: Text(context.l10n.unknownLibraryType)));
                }
                return LibraryPage(type: type);
              },
            ),
            GoRoute(
              path: '/collections',
              builder: (context, state) => const CollectionsPage(),
            ),
            GoRoute(
              path: '/request/:type/:id',
              builder: (context, state) {
                final rawType = (state.pathParameters['type'] ?? '').trim().toLowerCase();
                final mediaType = rawType == 'movie'
                    ? MediaType.movie
                    : rawType == 'tv'
                        ? MediaType.tv
                        : null;
                final rawId = (state.pathParameters['id'] ?? '').trim();
                final tmdbId = int.tryParse(rawId);
                if (mediaType == null || tmdbId == null) {
                  return Scaffold(body: Center(child: Text(context.l10n.invalidRequestItem)));
                }
                final extra = state.extra is ArtemisRecommendationItem
                    ? state.extra as ArtemisRecommendationItem
                    : null;
                return RequestDetailsPage(tmdbId: tmdbId, mediaType: mediaType, initial: extra);
              },
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _isAuthenticated.dispose();
    _isConfigured.dispose();
    _lastPlaybackItemId.dispose();
    _locale.dispose();
    _showFeedbackButton.dispose();
    _homeRefreshTick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppServicesScope(
      services: widget.services,
      child: AppUiScope(
        isAuthenticated: _isAuthenticated,
        isConfigured: _isConfigured,
        lastPlaybackItemId: _lastPlaybackItemId,
        homeRefreshTick: _homeRefreshTick,
        locale: _locale,
        showFeedbackButton: _showFeedbackButton,
        child: ValueListenableBuilder<Locale?>(
          valueListenable: _locale,
          builder: (context, locale, _) {
            return MaterialApp.router(
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              title: 'Zerk Play',
              theme: ottDarkTheme(),
              routerConfig: _router,
              builder: (context, child) {
                if (child == null) return const SizedBox.shrink();
                return UpdaterWrapper(child: child);
              },
            );
          },
        ),
      ),
    );
  }
}

final class AppServicesScope extends InheritedWidget {
  const AppServicesScope({
    super.key,
    required this.services,
    required super.child,
  });

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppServicesScope>();
    if (scope == null) throw StateError('AppServicesScope not found.');
    return scope.services;
  }

  @override
  bool updateShouldNotify(AppServicesScope oldWidget) {
    return identical(oldWidget.services, services) == false;
  }
}

final class AppUiScope extends InheritedWidget {
  const AppUiScope({
    super.key,
    required this.isAuthenticated,
    required this.isConfigured,
    required this.lastPlaybackItemId,
    required this.homeRefreshTick,
    required this.locale,
    required this.showFeedbackButton,
    required super.child,
  });

  final ValueNotifier<bool> isAuthenticated;
  final ValueNotifier<bool> isConfigured;
  final ValueNotifier<String?> lastPlaybackItemId;
  final ValueNotifier<int> homeRefreshTick;
  final ValueNotifier<Locale?> locale;
  final ValueNotifier<bool> showFeedbackButton;

  static AppUiScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppUiScope>();
    if (scope == null) throw StateError('AppUiScope not found.');
    return scope;
  }

  @override
  bool updateShouldNotify(AppUiScope oldWidget) {
    return oldWidget.isAuthenticated != isAuthenticated ||
        oldWidget.isConfigured != isConfigured ||
        oldWidget.lastPlaybackItemId != lastPlaybackItemId ||
        oldWidget.homeRefreshTick != homeRefreshTick ||
        oldWidget.locale != locale ||
        oldWidget.showFeedbackButton != showFeedbackButton;
  }
}
