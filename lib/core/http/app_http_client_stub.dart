import 'package:http/http.dart' as http;

/// Stub for platforms without `dart:io` (web).
http.Client createJellyseerrHttpClient() => http.Client();
