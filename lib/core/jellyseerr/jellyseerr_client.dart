import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'jellyseerr_api_exception.dart';

final class JellyseerrClient {
  JellyseerrClient({
    Uri? baseUrl,
    http.Client? httpClient,
    String? apiKey,
    String? sessionCookie,
  })  : baseUrl = _normalizeBaseUrl(baseUrl ?? Uri.parse('https://example.invalid')),
        _http = httpClient ?? http.Client(),
        _apiKey = (apiKey ?? '').trim(),
        _sessionCookie = (sessionCookie ?? '').trim();

  final Uri baseUrl;
  final http.Client _http;
  final String _apiKey;
  String _sessionCookie;

  void setSessionCookie(String? cookie) => _sessionCookie = (cookie ?? '').trim();

  Uri buildUri(
    String path, {
    Map<String, String?> queryParameters = const {},
  }) {
    final qp = <String, String>{};
    for (final entry in queryParameters.entries) {
      final value = entry.value;
      if (value == null) continue;
      qp[entry.key] = value;
    }

    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return baseUrl.replace(
      path: _joinPath(baseUrl.path, normalizedPath),
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  Map<String, String> _headers({
    Map<String, String> extra = const {},
    bool preferCookie = true,
  }) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...extra,
    };

    final cookie = _sessionCookie;
    if (preferCookie && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }

    if (_apiKey.isNotEmpty) {
      headers['X-Api-Key'] = _apiKey;
    }
    return headers;
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> queryParameters = const {},
  }) async {
    final uri = buildUri(path, queryParameters: queryParameters);
    final response = await _http.get(uri, headers: _headers());
    return _decodeJsonResponse(uri: uri, response: response);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, String?> queryParameters = const {},
    Object? body,
    bool preferCookie = true,
  }) async {
    final uri = buildUri(path, queryParameters: queryParameters);
    final response = await _http.post(
      uri,
      headers: _headers(preferCookie: preferCookie),
      body: body == null ? null : jsonEncode(body),
    );
    return _decodeJsonResponse(uri: uri, response: response);
  }

  Future<({Map<String, dynamic> json, Map<String, String> headers, Uri uri})> postJsonWithHeaders(
    String path, {
    Map<String, String?> queryParameters = const {},
    Object? body,
    bool preferCookie = true,
  }) async {
    final uri = buildUri(path, queryParameters: queryParameters);
    final response = await _http.post(
      uri,
      headers: _headers(preferCookie: preferCookie),
      body: body == null ? null : jsonEncode(body),
    );
    final json = _decodeJsonResponse(uri: uri, response: response);
    return (json: json, headers: response.headers, uri: uri);
  }

  Map<String, dynamic> _decodeJsonResponse({
    required Uri uri,
    required http.Response response,
  }) {
    Object? decodedBody;
    try {
      decodedBody = jsonDecode(response.body);
    } catch (_) {
      decodedBody = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decodedBody is Map<String, dynamic>) return decodedBody;
      if (kDebugMode) {
        debugPrint('[Jellyseerr] Non-JSON body for ${response.statusCode} ${uri.toString()}');
        debugPrint('[Jellyseerr] body: $decodedBody');
      }
      throw JellyseerrApiException(
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
        body: decodedBody,
        uri: uri,
      );
    }

    if (kDebugMode) {
      debugPrint('[Jellyseerr] HTTP ${response.statusCode} ${uri.toString()}');
      debugPrint('[Jellyseerr] body: $decodedBody');
    }
    throw JellyseerrApiException(
      statusCode: response.statusCode,
      reasonPhrase: response.reasonPhrase,
      body: decodedBody,
      uri: uri,
    );
  }
}

Uri _normalizeBaseUrl(Uri uri) {
  final normalized = uri.replace(
    path: uri.path.isEmpty ? '/' : uri.path,
    queryParameters: null,
    fragment: null,
  );
  return normalized;
}

String _joinPath(String base, String add) {
  if (base.endsWith('/')) base = base.substring(0, base.length - 1);
  if (!add.startsWith('/')) add = '/$add';
  return '$base$add';
}
