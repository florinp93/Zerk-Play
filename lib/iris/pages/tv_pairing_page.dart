import 'dart:async';

import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/app.dart';
import '../../core/pairing/pairing_server.dart';
import '../../l10n/artemis_error_messages.dart';
import '../../l10n/l10n.dart';

/// Replaces SetupPage + LoginPage on Android TV.
/// Shows a QR code that the user scans on their phone to fill in
/// Emby URL, *seerr URL/API key, username, and password from a web form.
final class TvPairingPage extends StatefulWidget {
  const TvPairingPage({super.key});

  @override
  State<TvPairingPage> createState() => _TvPairingPageState();
}

final class _TvPairingPageState extends State<TvPairingPage> {
  PairingServer? _server;
  String? _pairingUrl;
  String? _error;
  bool _pairing = false;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  @override
  void dispose() {
    _server?.stop();
    super.dispose();
  }

  Future<void> _startServer() async {
    try {
      final server = PairingServer();
      _server = server;
      await server.start();

      final info = NetworkInfo();
      final ip = await info.getWifiIP() ?? 'unknown';
      final url = 'http://$ip:${server.port}/pair/${server.token}';

      if (!mounted) return;
      setState(() => _pairingUrl = url);

      final creds = await server.credentials;
      if (!mounted) return;
      await _processPairing(creds);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _processPairing(PairingCredentials creds) async {
    setState(() {
      _pairing = true;
      _error = null;
    });

    try {
      final services = AppServicesScope.of(context);

      // 1. Persist server config (mirrors SetupPage._submit)
      await services.config.save(
        embyServerUrl: creds.embyServerUrl,
        jellyseerrUrl: creds.jellyseerrUrl,
        jellyseerrApiKey: creds.jellyseerrApiKey,
      );

      // setServerUrl calls logout + init internally
      await services.janus.setServerUrl(creds.embyServerUrl);

      final cfg = await services.config.load();
      if (cfg != null) {
        await services.artemis.setConfig(
          baseUrl: cfg.jellyseerrUrl,
          apiKey: cfg.jellyseerrApiKey,
        );
        final reach = await services.artemis.checkReachability();
        if (!reach.reachable && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(messageForReachability(context.l10n, reach)),
              duration: const Duration(seconds: 10),
            ),
          );
        }
      }

      // 2. Authenticate (mirrors LoginPage._submit)
      await services.janus.login(
        username: creds.username,
        password: creds.password,
      );
      await services.config.setEmbyCredentials(
        username: creds.username,
        password: creds.password,
      );
      await services.apollo.registerCapabilities();
      try {
        await services.artemis.syncWithJanus(
          services.janus,
          username: creds.username,
          password: creds.password,
        );
      } catch (e, st) {
        debugPrint('[TvPairing] Artemis syncWithJanus failed: $e');
        debugPrint('$st');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Jellyseerr sync failed: $e'),
              duration: const Duration(seconds: 6),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }

      if (!mounted) return;
      final scope = AppUiScope.of(context);
      scope.isConfigured.value = true;
      scope.isAuthenticated.value = true;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pairing = false;
        _error = 'Pairing failed: $e';
      });
      _restartServer();
    }
  }

  Future<void> _restartServer() async {
    await _server?.stop();
    _server = null;
    setState(() {
      _pairingUrl = null;
      _error = null;
    });
    _startServer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Zerk Play',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Scan the QR code with your phone to set up',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 32),
            if (_pairing)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Connecting to your server...'),
                ],
              )
            else if (_pairingUrl != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: QrImageView(
                  data: _pairingUrl!,
                  version: QrVersions.auto,
                  size: 260,
                  backgroundColor: Colors.white,
                ),
              )
            else
              const CircularProgressIndicator(),
            const SizedBox(height: 24),
            if (_pairingUrl != null && !_pairing)
              SelectableText(
                _pairingUrl!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white54,
                  fontFamily: 'monospace',
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _restartServer,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
