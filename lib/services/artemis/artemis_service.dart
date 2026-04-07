import 'package:flutter/foundation.dart';

import '../../core/jellyseerr/jellyseerr_api_exception.dart';
import '../../core/jellyseerr/jellyseerr_client.dart';
import '../../core/storage/local_store.dart';
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
    Uri? baseUrl,
  })  : _store = store,
        _apiKey = apiKey,
        _client = JellyseerrClient(baseUrl: baseUrl, apiKey: apiKey);

  static const _kCookie = 'jellyseerr.cookie';

  final LocalStore _store;
  String _apiKey;
  JellyseerrClient _client;

  Future<void> init() async {
    final cookie = await _store.getString(_kCookie);
    _client.setSessionCookie(cookie);
    if (kDebugMode) {
      debugPrint('[Artemis] init: cookiePresent=${(cookie ?? '').isNotEmpty}');
      debugPrint('[Artemis] init: apiKeyPresent=${_apiKey.trim().isNotEmpty}');
    }
  }

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
    _client = JellyseerrClient(baseUrl: baseUrl, apiKey: key);
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
      if (kDebugMode) {
        debugPrint('[Artemis] syncWithJanus skipped: missing username/password');
      }
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
          if (kDebugMode) {
            debugPrint('[Artemis] syncWithJanus: hostname configured; retrying login-only');
          }
          res = await _client.postJsonWithHeaders(
            '/api/v1/auth/jellyfin',
            body: loginPayload,
            preferCookie: false,
          );
        } else {
          rethrow;
        }
      }

      final cookie = _extractCookieHeader(res.headers['set-cookie']);
      if (cookie != null && cookie.isNotEmpty) {
        _client.setSessionCookie(cookie);
        await _store.setString(_kCookie, cookie);
        if (kDebugMode) {
          debugPrint('[Artemis] syncWithJanus: session cookie stored');
        }
      } else {
        if (kDebugMode) {
          debugPrint('[Artemis] syncWithJanus: no Set-Cookie returned');
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Artemis] syncWithJanus failed: $e');
        debugPrint('$st');
      }
      rethrow;
    }
  }

  Future<ArtemisRecommendations> getRecommendations({
    int minMovies = 25,
    int minShows = 25,
  }) async {
    if (kDebugMode) {
      debugPrint('[Artemis] getRecommendations: /api/v1/discover/trending');
    }
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
          final id = r['id'];
          final type = r['mediaType'] ?? r['media_type'];
          if (id is! int) continue;
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

    if (kDebugMode) {
      debugPrint(
        '[Artemis] getRecommendations: movies=${movies.length} shows=${shows.length} pages=${page - 1}',
      );
    }
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
          final id = r['id'];
          final type = r['mediaType'] ?? r['media_type'];
          if (id is! int) continue;
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

  final matches = RegExp(r'(^|,\s*)([^=;,\s]+)=([^;]+);').allMatches(raw);
  final parts = <String>[];
  for (final m in matches) {
    final name = m.group(2);
    final value = m.group(3);
    if (name == null || value == null) continue;
    if (name.isEmpty || value.isEmpty) continue;
    parts.add('$name=$value');
  }
  if (parts.isEmpty) return null;
  return parts.join('; ');
}
