import 'dart:convert';

import 'package:http/http.dart' as http;

import 'emby_api_exception.dart';

final class EmbyClient {
  EmbyClient({
    required Uri serverUrl,
    required this.clientName,
    required this.deviceName,
    required this.deviceId,
    required this.appVersion,
    http.Client? httpClient,
    String? accessToken,
  })  : serverUrl = _normalizeServerUrl(serverUrl),
        _http = httpClient ?? http.Client(),
        _accessToken = accessToken;

  final Uri serverUrl;
  final String clientName;
  final String deviceName;
  final String deviceId;
  final String appVersion;
  final http.Client _http;
  String? _accessToken;

  void setAccessToken(String? token) => _accessToken = token;

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
    return serverUrl.replace(
      path: _joinPath(serverUrl.path, normalizedPath),
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  Uri buildPrimaryImageUri(
    String itemId, {
    int maxWidth = 360,
    String? tag,
  }) {
    return buildUri(
      '/Items/$itemId/Images/Primary',
      queryParameters: {
        'maxWidth': '$maxWidth',
        'tag': tag,
      },
    );
  }

  Uri buildThumbImageUri(
    String itemId, {
    int maxWidth = 640,
    String? tag,
  }) {
    return buildUri(
      '/Items/$itemId/Images/Thumb',
      queryParameters: {
        'maxWidth': '$maxWidth',
        'tag': tag,
      },
    );
  }

  Uri buildLogoImageUri(
    String itemId, {
    int maxWidth = 800,
    String? tag,
  }) {
    return buildUri(
      '/Items/$itemId/Images/Logo',
      queryParameters: {
        'maxWidth': '$maxWidth',
        'tag': tag,
      },
    );
  }

  Map<String, String> _headers({
    Map<String, String> extra = const {},
  }) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Emby-Authorization':
          'MediaBrowser Client="$clientName", Device="$deviceName", DeviceId="$deviceId", Version="$appVersion"',
      ...extra,
    };

    final token = _accessToken;
    if (token != null && token.isNotEmpty) {
      headers['X-Emby-Token'] = token;
    }

    return headers;
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> queryParameters = const {},
  }) async {
    final uri = buildUri(path, queryParameters: queryParameters);
    final response = await _http.get(uri, headers: _headers());
    return _decodeJsonResponse(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, String?> queryParameters = const {},
    Object? body,
  }) async {
    final uri = buildUri(path, queryParameters: queryParameters);
    final response = await _http.post(
      uri,
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decodeJsonResponse(response);
  }

  Future<void> postNoContent(
    String path, {
    Map<String, String?> queryParameters = const {},
    Object? body,
  }) async {
    final uri = buildUri(path, queryParameters: queryParameters);
    final response = await _http.post(
      uri,
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    Object? decodedBody;
    try {
      decodedBody = jsonDecode(response.body);
    } catch (_) {
      decodedBody = response.body;
    }
    throw EmbyApiException(
      statusCode: response.statusCode,
      reasonPhrase: response.reasonPhrase,
      body: decodedBody,
    );
  }


  Future<void> deleteNoContent(
    String path, {
    Map<String, String?> queryParameters = const {},
    Object? body,
  }) async {
    final uri = buildUri(path, queryParameters: queryParameters);
    final response = await _http.delete(
      uri,
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    Object? decodedBody;
    try {
      decodedBody = jsonDecode(response.body);
    } catch (_) {
      decodedBody = response.body;
    }
    throw EmbyApiException(
      statusCode: response.statusCode,
      reasonPhrase: response.reasonPhrase,
      body: decodedBody,
      uri: uri,
    );
  }

  Map<String, dynamic> _decodeJsonResponse(http.Response response) {
    Object? decodedBody;
    try {
      decodedBody = jsonDecode(response.body);
    } catch (_) {
      decodedBody = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decodedBody is Map<String, dynamic>) return decodedBody;
      throw EmbyApiException(
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
        body: decodedBody,
      );
    }

    throw EmbyApiException(
      statusCode: response.statusCode,
      reasonPhrase: response.reasonPhrase,
      body: decodedBody,
    );
  }
}

Uri _normalizeServerUrl(Uri uri) {
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
