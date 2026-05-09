import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/jellyseerr/jellyseerr_api_exception.dart';
import '../../core/jellyseerr/jellyseerr_client.dart';
import '../../core/storage/local_store.dart';
import 'artemis_transport.dart';
import '../janus/janus_service.dart';

enum MediaType { movie, tv }

enum ArtemisRequestState { none, requested, processing }

final class ArtemisRecommendations {
  const ArtemisRecommendations({
    required this.items,
  });

  final List<ArtemisRecommendationItem> items;
}

final class ArtemisRecommendationItem {
  const ArtemisRecommendationItem({
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    required this.posterPath,
    required this.backdropPath,
    required this.originalLanguage,
    required this.genreIds,
    required this.overview,
  });

  final int tmdbId;
  final MediaType mediaType;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String? originalLanguage;
  final List<int> genreIds;
  final String? overview;
}

final class ArtemisMediaDetails {
  const ArtemisMediaDetails({
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.originalLanguage,
    required this.genreIds,
    required this.genres,
    required this.year,
  });

  final int tmdbId;
  final MediaType mediaType;
  final String title;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final String? originalLanguage;
  final List<int> genreIds;
  final List<String> genres;
  final int? year;
}

final class ArtemisRequestStatus {
  const ArtemisRequestStatus({
    required this.state,
    this.mediaStatus,
    this.requestStatuses = const <int>[],
  });

  final ArtemisRequestState state;
  final int? mediaStatus;
  final List<int> requestStatuses;

  bool get isRequested => state != ArtemisRequestState.none;
  bool get isPending => state == ArtemisRequestState.requested;
}

final class ArtemisService {
  ArtemisService({
    required LocalStore store,
    required String apiKey,
    required http.Client httpClient,
    Uri? baseUrl,
  })  : _store = store,
        _apiKey = apiKey,
        _httpClient = httpClient,
        _client = JellyseerrClient(
          baseUrl: baseUrl,
          apiKey: apiKey,
          httpClient: httpClient,
        );

  static const _kCookie = 'jellyseerr.cookie';

  final LocalStore _store;
  final http.Client _httpClient;
  String _apiKey;
  JellyseerrClient _client;

  Future<void> init() async {
    final cookie = await _store.getString(_kCookie);
    _client.setSessionCookie(cookie);
    debugPrint('[Artemis] init: baseUrl=${_client.baseUrl}, cookiePresent=${(cookie ?? '').isNotEmpty}, apiKeyPresent=${_apiKey.trim().isNotEmpty}');
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    await checkReachability();
  }

  /// Same check as [isReachable], but returns structured diagnostics for UI and `adb logcat`.
  ///
  /// Requires a real Jellyseerr instance: an Emby-only URL (same mistake as using the Emby
  /// server address for *seerr) is reported as [ArtemisTransportIssue.wrongService].
  /// Transport/DNS/TLS failures also set [ArtemisReachabilityResult.reachable] to false.
  ///
  /// Transient **network** errors (timeouts, resets) are retried up to 3 times with backoff;
  /// TLS/DNS and HTTP-shaped results are not retried.
  Future<ArtemisReachabilityResult> checkReachability() async {
    final url = _client.baseUrl;
    if (url.host == 'example.invalid') {
      debugPrint('[Artemis] checkReachability: skipped (placeholder URL)');
      return const ArtemisReachabilityResult(
        reachable: false,
        issue: ArtemisTransportIssue.unknown,
        debugLine: '[Artemis] checkReachability skipped (placeholder URL)',
      );
    }

    const maxAttempts = 3;
    const retryDelaysMs = <int>[400, 1200];

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        final delayMs = retryDelaysMs[attempt - 1];
        debugPrint(
          '[Artemis] checkReachability retry ${attempt + 1}/$maxAttempts after ${delayMs}ms',
        );
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
      try {
        return await _probeReachabilityOnce();
      } catch (e, st) {
        final issue = categorizeArtemisTransportError(e);
        final retryable =
            issue == ArtemisTransportIssue.network && attempt < maxAttempts - 1;
        if (retryable) {
          continue;
        }
        final line = artemisConnectivityDebugLine(e, st);
        debugPrint('[Artemis] checkReachability FAILED $line');
        return ArtemisReachabilityResult(
          reachable: false,
          issue: issue,
          debugLine: line,
        );
      }
    }

    return const ArtemisReachabilityResult(
      reachable: false,
      issue: ArtemisTransportIssue.unknown,
      debugLine: '[Artemis] checkReachability: internal retry loop exhausted',
    );
  }

  Future<ArtemisReachabilityResult> _probeReachabilityOnce() async {
    final response = await _client.rawGet('/api/v1/status');
    if (_responseHeadersSuggestEmby(response.headers)) {
      const issue = ArtemisTransportIssue.wrongService;
      debugPrint('[Artemis] checkReachability: headers suggest Emby (not Jellyseerr)');
      return ArtemisReachabilityResult(
        reachable: false,
        issue: issue,
        debugLine:
            '[Artemis] wrongService: Emby-like headers for ${_client.baseUrl} status=${response.statusCode}',
      );
    }

    final code = response.statusCode;
    if (code >= 200 && code < 300) {
      final decoded = _tryDecodeJsonMap(response.body);
      if (decoded != null && _looksLikeJellyseerrStatus(decoded)) {
        debugPrint('[Artemis] checkReachability: OK Jellyseerr /api/v1/status');
        return const ArtemisReachabilityResult(reachable: true);
      }
      debugPrint('[Artemis] checkReachability: 200 but body is not Jellyseerr /api/v1/status');
      return ArtemisReachabilityResult(
        reachable: false,
        issue: ArtemisTransportIssue.wrongService,
        debugLine:
            '[Artemis] wrongService: HTTP 200 without Jellyseerr status JSON at ${_client.baseUrl}',
      );
    }

    if (code == 401 || code == 403) {
      debugPrint('[Artemis] checkReachability: HTTP $code (auth) — host responded');
      return const ArtemisReachabilityResult(reachable: true);
    }

    if (code == 404) {
      debugPrint('[Artemis] checkReachability: HTTP 404 on /api/v1/status (likely not Jellyseerr)');
      return ArtemisReachabilityResult(
        reachable: false,
        issue: ArtemisTransportIssue.wrongService,
        debugLine:
            '[Artemis] wrongService: HTTP 404 on /api/v1/status at ${_client.baseUrl}',
      );
    }

    final errBody = _tryDecodeJsonMap(response.body);
    if (errBody != null &&
        (_looksLikeJellyseerrErrorPayload(errBody) || _looksLikeJellyseerrStatus(errBody))) {
      debugPrint('[Artemis] checkReachability: HTTP $code Jellyseerr-style JSON — host reachable');
      return const ArtemisReachabilityResult(reachable: true);
    }

    debugPrint('[Artemis] checkReachability: unexpected HTTP $code');
    return ArtemisReachabilityResult(
      reachable: false,
      issue: ArtemisTransportIssue.wrongService,
      debugLine: '[Artemis] wrongService: unexpected HTTP $code for ${_client.baseUrl}',
    );
  }

  /// True if the device can open a TLS connection and get an HTTP response from Jellyseerr.
  /// Uses the same [JellyseerrClient] as other calls (API key + session cookie), not a bare `http.get`.
  /// Prefer [checkReachability] when surfacing errors on Android TV.
  Future<bool> isReachable() async => (await checkReachability()).reachable;

  Future<void> clearSession() async {
    _client.setSessionCookie(null);
    await _store.remove(_kCookie);
  }

  Future<void> setConfig({
    required Uri baseUrl,
    required String apiKey,
  }) async {
    final key = apiKey.trim();
    _apiKey = key;
    final cookie = await _store.getString(_kCookie);
    _client = JellyseerrClient(
      baseUrl: baseUrl,
      apiKey: key,
      httpClient: _httpClient,
    );
    _client.setSessionCookie(cookie);
  }

  Future<void> syncWithJanus(
    JanusService janus, {
    String? username,
    String? password,
  }) async {
    if (!janus.isAuthenticated) return;
    final u = (username ?? '').trim();
    final p = password ?? '';
    if (u.isEmpty || p.isEmpty) {
      debugPrint('[Artemis] syncWithJanus skipped: missing username/password');
      return;
    }

    final s = janus.session;
    final serverUrl = s.serverUrl;
    final port = serverUrl.hasPort
        ? serverUrl.port
        : (serverUrl.scheme.toLowerCase() == 'https' ? 443 : 80);
    final urlBase = serverUrl.path == '/' ? '' : serverUrl.path;

    const serverTypeEmby = 3;
    final configurePayload = <String, Object?>{
      'username': u,
      'password': p,
      'serverType': serverTypeEmby,
      'hostname': serverUrl.host,
      'port': port,
      'useSsl': serverUrl.scheme.toLowerCase() == 'https',
      'urlBase': urlBase,
    };
    final loginPayload = <String, Object?>{
      'username': u,
      'password': p,
      'serverType': serverTypeEmby,
    };

    try {
      ({Map<String, dynamic> json, Map<String, String> headers, Uri uri}) res;
      try {
        res = await _client.postJsonWithHeaders(
          '/api/v1/auth/jellyfin',
          body: configurePayload,
          preferCookie: false,
        );
      } on JellyseerrApiException catch (e) {
        final err = e.body;
        final message = (err is Map ? err['error'] : null) as String?;
        if (e.statusCode == 500 &&
            (message ?? '').toLowerCase().contains('hostname already configured')) {
          debugPrint('[Artemis] syncWithJanus: hostname configured; retrying login-only');
          res = await _client.postJsonWithHeaders(
            '/api/v1/auth/jellyfin',
            body: loginPayload,
            preferCookie: false,
          );
        } else {
          rethrow;
        }
      }

      final rawSetCookie = res.headers['set-cookie'];
      debugPrint('[Artemis] syncWithJanus: raw Set-Cookie header: $rawSetCookie');
      final cookie = _extractCookieHeader(rawSetCookie);
      if (cookie != null && cookie.isNotEmpty) {
        _client.setSessionCookie(cookie);
        await _store.setString(_kCookie, cookie);
        debugPrint('[Artemis] syncWithJanus: session cookie stored ($cookie)');
      } else {
        debugPrint('[Artemis] syncWithJanus: no usable cookie extracted from Set-Cookie header');
      }
    } catch (e, st) {
      debugPrint('[Artemis] syncWithJanus failed: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<ArtemisRecommendations> getRecommendations({
    int minMovies = 25,
    int minShows = 25,
  }) async {
    debugPrint('[Artemis] getRecommendations: baseUrl=${_client.baseUrl}');
    final movies = <ArtemisRecommendationItem>[];
    final shows = <ArtemisRecommendationItem>[];
    final seen = <String>{};

    const maxPages = 20;
    var page = 1;
    while (page <= maxPages && (movies.length < minMovies || shows.length < minShows)) {
      final json = await _client.getJson(
        '/api/v1/discover/trending',
        queryParameters: {'page': '$page'},
      );
      final results = json['results'];
      if (results is List) {
        for (final r in results) {
          if (r is! Map) continue;
          final id = _readTmdbId(r['id']);
          final type = r['mediaType'] ?? r['media_type'];
          if (id == null) continue;
          final mediaType = _parseMediaType(type);
          if (mediaType == null) continue;

          final key = '${_encodeMediaType(mediaType)}-$id';
          if (seen.contains(key)) continue;

          final lang = _readString(r['originalLanguage']) ??
              _readString(r['original_language']) ??
              _readString(r['originalLanguage'.toLowerCase()]);
          final langNorm = (lang ?? '').trim().toLowerCase();
          if (langNorm != 'en' && langNorm != 'ro') continue;

          final genreIds = _readIntList(r['genreIds']) ??
              _readIntList(r['genre_ids']) ??
              _readIntList(r['genres']);
          final genreIdsOut = genreIds ?? const <int>[];
          if (mediaType == MediaType.tv &&
              genreIdsOut.any((g) => g == 10763 || g == 10767)) {
            continue;
          }

          final title = (r['title'] as String?) ??
              (r['name'] as String?) ??
              (r['originalTitle'] as String?) ??
              (r['originalName'] as String?) ??
              '';

          final item = ArtemisRecommendationItem(
            tmdbId: id,
            mediaType: mediaType,
            title: title,
            posterPath: _readString(r['posterPath']) ?? _readString(r['poster_path']),
            backdropPath: _readString(r['backdropPath']) ?? _readString(r['backdrop_path']),
            originalLanguage: langNorm,
            genreIds: genreIdsOut,
            overview: _readString(r['overview']),
          );
          seen.add(key);
          if (mediaType == MediaType.movie) {
            if (movies.length < minMovies) movies.add(item);
          } else {
            if (shows.length < minShows) shows.add(item);
          }
        }
      }
      page++;
    }

    debugPrint(
      '[Artemis] getRecommendations: movies=${movies.length} shows=${shows.length} pages=${page - 1}',
    );
    return ArtemisRecommendations(items: [...movies, ...shows]);
  }

  Future<List<ArtemisRecommendationItem>> search({
    required String query,
    int limit = 30,
  }) async {
    final term = query.trim();
    if (term.isEmpty) return const <ArtemisRecommendationItem>[];

    final out = <ArtemisRecommendationItem>[];
    final seen = <String>{};
    const maxPages = 8;
    var page = 1;
    while (page <= maxPages && out.length < limit) {
      final json = await _client.getJson(
        '/api/v1/search',
        queryParameters: {
          'query': term,
          'page': '$page',
        },
      );
      final results = json['results'];
      if (results is List) {
        for (final r in results) {
          if (r is! Map) continue;
          final id = _readTmdbId(r['id']);
          final type = r['mediaType'] ?? r['media_type'];
          if (id == null) continue;
          final mediaType = _parseMediaType(type);
          if (mediaType == null) continue;

          final key = '${_encodeMediaType(mediaType)}-$id';
          if (seen.contains(key)) continue;

          final title = (r['title'] as String?) ??
              (r['name'] as String?) ??
              (r['originalTitle'] as String?) ??
              (r['originalName'] as String?) ??
              '';

          final item = ArtemisRecommendationItem(
            tmdbId: id,
            mediaType: mediaType,
            title: title,
            posterPath: _readString(r['posterPath']) ?? _readString(r['poster_path']),
            backdropPath: _readString(r['backdropPath']) ?? _readString(r['backdrop_path']),
            originalLanguage: (_readString(r['originalLanguage']) ??
                    _readString(r['original_language']) ??
                    _readString(r['originalLanguage'.toLowerCase()]))
                ?.trim()
                .toLowerCase(),
            genreIds: _readIntList(r['genreIds']) ??
                _readIntList(r['genre_ids']) ??
                _readIntList(r['genres']) ??
                const <int>[],
            overview: _readString(r['overview']),
          );

          seen.add(key);
          out.add(item);
          if (out.length >= limit) break;
        }
      }
      page++;
    }
    return out;
  }

  Future<ArtemisMediaDetails> getMediaDetails({
    required int tmdbId,
    required MediaType type,
  }) async {
    final json = await _client.getJson(_detailsPath(type, tmdbId));

    final rawMedia = json['media'];
    final media = rawMedia is Map ? rawMedia.cast<String, dynamic>() : json;

    final title = (media['title'] as String?) ??
        (media['name'] as String?) ??
        (media['originalTitle'] as String?) ??
        (media['originalName'] as String?) ??
        '';
    final overview = (media['overview'] as String?) ?? '';
    final posterPath = (media['posterPath'] as String?) ?? (media['poster_path'] as String?);
    final backdropPath =
        (media['backdropPath'] as String?) ?? (media['backdrop_path'] as String?);
    final lang = (media['originalLanguage'] as String?) ?? (media['original_language'] as String?);
    final langNorm = (lang ?? '').trim().toLowerCase();

    final genreIds = _readIntList(media['genreIds']) ??
        _readIntList(media['genre_ids']) ??
        _readIntList(media['genres']) ??
        const <int>[];
    final genres = _readStringList(media['genres']) ?? const <String>[];

    final dateRaw = (media['releaseDate'] as String?) ??
        (media['firstAirDate'] as String?) ??
        (media['first_air_date'] as String?);
    final year = _parseYear(dateRaw);

    return ArtemisMediaDetails(
      tmdbId: tmdbId,
      mediaType: type,
      title: title,
      overview: overview.isEmpty ? null : overview,
      posterPath: posterPath,
      backdropPath: backdropPath,
      originalLanguage: langNorm.isEmpty ? null : langNorm,
      genreIds: genreIds,
      genres: genres,
      year: year,
    );
  }

  Future<ArtemisRequestStatus> getRequestStatus({
    required int tmdbId,
    required MediaType type,
  }) async {
    final json = await _client.getJson(_detailsPath(type, tmdbId));
    final mediaInfo = json['mediaInfo'];
    var mediaStatus = 0;
    final requestStatuses = <int>[];

    if (mediaInfo is Map) {
      final ms = mediaInfo['status'];
      if (ms is int) {
        mediaStatus = ms;
      } else if (ms is num) {
        mediaStatus = ms.toInt();
      }
      final requests = mediaInfo['requests'];
      if (requests is List && requests.isNotEmpty) {
        for (final r in requests) {
          if (r is! Map) continue;
          final status = r['status'];
          if (status is int) {
            requestStatuses.add(status);
          } else if (status is num) {
            requestStatuses.add(status.toInt());
          } else if (status is String) {
            final s = status.toLowerCase();
            if (s.contains('pending')) requestStatuses.add(1);
            if (s.contains('approved')) requestStatuses.add(2);
            if (s.contains('declined')) requestStatuses.add(3);
          }
        }
      }
    }

    final state = _deriveRequestState(
      mediaStatus: mediaStatus == 0 ? null : mediaStatus,
      requestStatuses: requestStatuses,
    );
    return ArtemisRequestStatus(
      state: state,
      mediaStatus: mediaStatus == 0 ? null : mediaStatus,
      requestStatuses: requestStatuses,
    );
  }

  Future<void> requestItem(String tmdbId, MediaType type) async {
    final parsed = int.tryParse(tmdbId.trim());
    if (parsed == null) throw ArgumentError.value(tmdbId, 'tmdbId', 'Invalid TMDB id');
    try {
      final body = <String, Object?>{
        'mediaId': parsed,
        'mediaType': _encodeMediaType(type),
      };

      if (type == MediaType.tv) {
        final details = await _client.getJson(_detailsPath(type, parsed));
        final seasons = _readSeasonNumbers(details);
        body['seasons'] = seasons;
      }

      await _client.postJson(
        '/api/v1/request',
        body: body,
      );
    } on JellyseerrApiException {
      rethrow;
    }
  }
}

int? _readTmdbId(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

MediaType? _parseMediaType(Object? raw) {
  final v = (raw is String) ? raw.toLowerCase().trim() : '';
  if (v == 'movie') return MediaType.movie;
  if (v == 'tv') return MediaType.tv;
  return null;
}

String _encodeMediaType(MediaType type) {
  switch (type) {
    case MediaType.movie:
      return 'movie';
    case MediaType.tv:
      return 'tv';
  }
}

String _detailsPath(MediaType type, int tmdbId) {
  switch (type) {
    case MediaType.movie:
      return '/api/v1/movie/$tmdbId';
    case MediaType.tv:
      return '/api/v1/tv/$tmdbId';
  }
}

List<int> _readSeasonNumbers(Map<String, dynamic> json) {
  final rawMedia = json['media'];
  final media = rawMedia is Map ? rawMedia.cast<String, dynamic>() : json;
  final seasonsRaw = media['seasons'];
  if (seasonsRaw is! List) return const <int>[];
  final out = <int>[];
  for (final s in seasonsRaw) {
    if (s is Map) {
      final n = s['seasonNumber'];
      if (n is int) {
        if (n > 0) out.add(n);
      } else if (n is num) {
        final v = n.toInt();
        if (v > 0) out.add(v);
      }
    } else if (s is int) {
      if (s > 0) out.add(s);
    } else if (s is num) {
      final v = s.toInt();
      if (v > 0) out.add(v);
    }
  }
  out.sort();
  return out;
}

String? _readString(Object? value) {
  if (value is String) {
    final v = value.trim();
    return v.isEmpty ? null : v;
  }
  return null;
}

List<int>? _readIntList(Object? value) {
  if (value is List) {
    final out = <int>[];
    for (final v in value) {
      if (v is int) {
        out.add(v);
      } else if (v is num) {
        out.add(v.toInt());
      }
      if (v is Map) {
        final id = v['id'];
        if (id is int) {
          out.add(id);
        } else if (id is num) {
          out.add(id.toInt());
        }
      }
    }
    return out;
  }
  return null;
}

List<String>? _readStringList(Object? value) {
  if (value is List) {
    final out = <String>[];
    for (final v in value) {
      if (v is String) {
        final s = v.trim();
        if (s.isNotEmpty) out.add(s);
      } else if (v is Map) {
        final name = v['name'];
        if (name is String && name.trim().isNotEmpty) out.add(name.trim());
      }
    }
    return out;
  }
  return null;
}

int? _parseYear(String? isoDate) {
  final v = (isoDate ?? '').trim();
  if (v.length < 4) return null;
  final y = int.tryParse(v.substring(0, 4));
  if (y == null) return null;
  if (y < 1800 || y > 3000) return null;
  return y;
}

ArtemisRequestState _deriveRequestState({
  required int? mediaStatus,
  required List<int> requestStatuses,
}) {
  final rs = requestStatuses.toSet();
  final ms = mediaStatus ?? 0;

  if (rs.contains(2) || ms >= 2) return ArtemisRequestState.processing;
  if (rs.contains(1) || ms == 1) return ArtemisRequestState.requested;
  if (rs.isNotEmpty || ms > 0) return ArtemisRequestState.requested;
  return ArtemisRequestState.none;
}

String? _extractCookieHeader(String? setCookie) {
  final raw = (setCookie ?? '').trim();
  if (raw.isEmpty) return null;

  const setCookieAttributes = <String>{
    'path', 'domain', 'expires', 'max-age', 'secure', 'httponly', 'samesite',
  };

  final matches = RegExp(r'(^|[,;]\s*)([^=;,\s]+)=([^;,]+)').allMatches(raw);
  final parts = <String>[];
  for (final m in matches) {
    final name = (m.group(2) ?? '').trim();
    final value = (m.group(3) ?? '').trim();
    if (name.isEmpty || value.isEmpty) continue;
    if (setCookieAttributes.contains(name.toLowerCase())) continue;
    parts.add('$name=$value');
  }
  if (parts.isEmpty) return null;
  return parts.join('; ');
}

bool _responseHeadersSuggestEmby(Map<String, String> headers) {
  for (final e in headers.entries) {
    final blob = '${e.key}:${e.value}'.toLowerCase();
    if (blob.contains('emby')) return true;
  }
  return false;
}

Map<String, dynamic>? _tryDecodeJsonMap(String body) {
  try {
    final o = jsonDecode(body);
    if (o is Map<String, dynamic>) return o;
    if (o is Map) return o.cast<String, dynamic>();
  } catch (_) {}
  return null;
}

bool _looksLikeJellyseerrStatus(Map<String, dynamic> json) {
  return json['version'] is String ||
      json['commitTag'] is String ||
      json['updateAvailable'] is bool;
}

bool _looksLikeJellyseerrErrorPayload(Map<String, dynamic> json) {
  return json.containsKey('message') &&
      (json.containsKey('statusCode') ||
          json.containsKey('errors') ||
          json.containsKey('error'));
}
