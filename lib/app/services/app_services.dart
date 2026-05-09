import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../../core/http/app_http_client.dart';
import '../../core/storage/shared_preferences_store.dart';
import '../../services/artemis/artemis_service.dart';
import '../../services/apollo/apollo_service.dart';
import '../../services/hermes/hermes_service.dart';
import '../../services/janus/janus_service.dart';
import '../../services/hephaestus/hephaestus_service.dart';
import 'config_service.dart';

final class AppServices {
  AppServices._({
    required this.janus,
    required this.hermes,
    required this.apollo,
    required this.artemis,
    required this.config,
    required this.hephaestus,
    required this.isConfigured,
  });

  final JanusService janus;
  final HermesService hermes;
  final ApolloService apollo;
  final ArtemisService artemis;
  final ConfigService config;
  final HephaestusService hephaestus;
  final bool isConfigured;

  static Future<AppServices> create() async {
    final store = SharedPreferencesStore();
    await store.init();

    final config = ConfigService(store: store);
    final isConfigured = await config.isConfigured();

    Uri? jellyseerrBaseUrl;
    var jellyseerrApiKey = '';
    try {
      final saved = await store.getString(ConfigService.kJellyseerrUrl);
      if (saved != null && saved.trim().isNotEmpty) {
        jellyseerrBaseUrl = Uri.parse(saved.trim());
      }
    } catch (e) {
      debugPrint('[AppServices] Failed to parse Jellyseerr URL from prefs: $e');
    }
    jellyseerrApiKey = (await store.getString(ConfigService.kJellyseerrApiKey) ?? '').trim();
    jellyseerrBaseUrl ??= Uri.parse('https://example.invalid');
    debugPrint('[AppServices] Artemis config: baseUrl=$jellyseerrBaseUrl, apiKeyPresent=${jellyseerrApiKey.isNotEmpty}');

    final deviceName = (!kIsWeb && Platform.isAndroid) ? 'Android TV' : 'Windows';
    final janus = JanusService(
      store: store,
      defaultServerUrl: 'https://example.invalid',
      deviceName: deviceName,
    );
    await janus.init();
    await janus.restoreSession();

    final hermes = HermesService(janus: janus);
    final apollo = ApolloService(janus: janus);
    final jellyseerrHttp = createJellyseerrHttpClient();
    final artemis = ArtemisService(
      store: store,
      apiKey: jellyseerrApiKey,
      baseUrl: jellyseerrBaseUrl,
      httpClient: jellyseerrHttp,
    );
    await artemis.init();

    if (janus.isAuthenticated) {
      await apollo.registerCapabilities();
    }

    final hephaestus = HephaestusService(githubRepo: 'florinp93/Zerk-Play');
    await hephaestus.init();

    return AppServices._(
      janus: janus,
      hermes: hermes,
      apollo: apollo,
      artemis: artemis,
      config: config,
      hephaestus: hephaestus,
      isConfigured: isConfigured,
    );
  }
}
