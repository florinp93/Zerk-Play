import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Native [IOClient] with explicit timeouts and a neutral User-Agent so HTTPS
/// to public hosts (reverse proxies, TLS) behaves reliably on Android TV.
http.Client createJellyseerrHttpClient() {
  final raw = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30)
    ..idleTimeout = const Duration(seconds: 90)
    ..userAgent =
        'Zerk-Play/1.0 (compatible; +https://github.com/florinp93/Zerk-Play)';
  return IOClient(raw);
}
