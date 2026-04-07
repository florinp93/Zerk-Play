import '../../core/emby/models/emby_item.dart';
import '../janus/janus_service.dart';

final class EmbyLibraryFilters {
  const EmbyLibraryFilters({required this.genres, required this.years});

  final List<String> genres;
  final List<int> years;
}

final class HermesService {
  HermesService({required JanusService janus}) : _janus = janus;

  final JanusService _janus;

  Future<List<EmbyItem>> getResumeItems({int limit = 30}) async {
    final session = _janus.session;
    final json = await _janus.client.getJson(
      '/Users/${session.userId}/Items/Resume',
      queryParameters: {
        'Limit': '$limit',
        'IncludeItemTypes': 'Movie,Episode',
        'SortBy': 'DatePlayed',
        'SortOrder': 'Descending',
        'Fields': 'Overview,ProductionYear,ImageTags,UserData,SeriesId,SeasonId,ParentId,Chapters',
      },
    );
    return _parseItems(json);
  }

  Future<List<EmbyItem>> getPlaybackActivityItems({int limit = 80}) async {
    final session = _janus.session;
    final json = await _janus.client.getJson(
      '/Users/${session.userId}/Items',
      queryParameters: {
        'Recursive': 'true',
        'IncludeItemTypes': 'Movie,Episode',
        'SortBy': 'DatePlayed',
        'SortOrder': 'Descending',
        'Limit': '$limit',
        'Fields': 'Overview,ProductionYear,Genres,ImageTags,UserData,SeriesId,SeasonId,ParentId,Chapters',
      },
    );
    return _parseItems(json);
  }

  Future<List<EmbyItem>> getRecentEpisodeActivityItems({int limit = 200}) async {
    final session = _janus.session;
    final json = await _janus.client.getJson(
      '/Users/${session.userId}/Items',
      queryParameters: {
        'Recursive': 'true',
        'IncludeItemTypes': 'Episode',
        'SortBy': 'DatePlayed',
        'SortOrder': 'Descending',
        'Limit': '$limit',
        'Fields': 'UserData,SeriesId,SeasonId,ParentId',
      },
    );
    return _parseItems(json);
  }

  Future<List<EmbyItem>> getMovies() async {
    return _getItems(
      includeItemTypes: const ['Movie'],
    );
  }

  Future<List<EmbyItem>> getShows() async {
    return _getItems(
      includeItemTypes: const ['Series'],
    );
  }

  Future<List<EmbyItem>> getLatestAddedMovies({int limit = 30}) async {
    return _getSortedItems(
      includeItemTypes: const ['Movie'],
      sortBy: 'DateCreated',
      sortOrder: 'Descending',
      limit: limit,
    );
  }

  Future<List<EmbyItem>> getLatestAddedShows({int limit = 30}) async {
    return _getSortedItems(
      includeItemTypes: const ['Series'],
      sortBy: 'DateCreated',
      sortOrder: 'Descending',
      limit: limit,
    );
  }

  Future<List<EmbyItem>> getRecentlyReleasedMovies({int limit = 30}) async {
    return _getSortedItems(
      includeItemTypes: const ['Movie'],
      sortBy: 'PremiereDate',
      sortOrder: 'Descending',
      limit: limit,
    );
  }

  Future<List<EmbyItem>> getRecentlyReleasedShows({int limit = 30}) async {
    return _getSortedItems(
      includeItemTypes: const ['Series'],
      sortBy: 'PremiereDate',
      sortOrder: 'Descending',
      limit: limit,
    );
  }

  Future<List<EmbyItem>> getCollections({int limit = 50}) async {
    final session = _janus.session;
    final json = await _janus.client.getJson(
      '/Users/${session.userId}/Items',
      queryParameters: {
        'Recursive': 'true',
        'IncludeItemTypes': 'BoxSet',
        'SortBy': 'SortName',
        'SortOrder': 'Ascending',
        'Limit': '$limit',
        'Fields': 'Overview,ProductionYear,ImageTags',
      },
    );
    return _parseItems(json);
  }

  Future<List<EmbyItem>> getCollectionMovies(String collectionId, {int limit = 60}) async {
    final session = _janus.session;
    final json = await _janus.client.getJson(
      '/Users/${session.userId}/Items',
      queryParameters: {
        'ParentId': collectionId,
        'Recursive': 'true',
        'IncludeItemTypes': 'Movie',
        'SortBy': 'PremiereDate,ProductionYear,SortName',
        'SortOrder': 'Ascending,Ascending,Ascending',
        'Limit': '$limit',
        'Fields': 'Overview,ProductionYear,Genres,ImageTags,UserData',
      },
    );
    return _parseItems(json);
  }

  Future<List<EmbyItem>> getLibraryItemsPage({
    required List<String> includeItemTypes,
    int startIndex = 0,
    int limit = 60,
  }) async {
    final session = _janus.session;
    final json = await _janus.client.getJson(
      '/Users/${session.userId}/Items',
      queryParameters: {
        'Recursive': 'true',
        'IncludeItemTypes': includeItemTypes.join(','),
        'SortBy': 'SortName',
        'SortOrder': 'Ascending',
        'StartIndex': '$startIndex',
        'Limit': '$limit',
        'Fields': 'Overview,ProductionYear,Genres,ImageTags,UserData,SeriesId,SeasonId,ParentId',
      },
    );
    return _parseItems(json);
  }

  Future<List<EmbyItem>> search({
    required String query,
    int limit = 50,
    int startIndex = 0,
  }) async {
    final term = query.trim();
    if (term.isEmpty) return const <EmbyItem>[];
    final session = _janus.session;
    final json = await _janus.client.getJson(
      '/Users/${session.userId}/Items',
      queryParameters: {
        'Recursive': 'true',
        'SearchTerm': term,
        'IncludeItemTypes': 'Movie,Series',
        'StartIndex': '$startIndex',
        'Limit': '$limit',
        'SortBy': 'SortName',
        'SortOrder': 'Ascending',
        'Fields': 'Overview,ProductionYear,ImageTags,UserData',
      },
    );
    return _parseItems(json);
  }

  Future<EmbyItem?> findByTmdbId({
    required int tmdbId,
    required String includeItemType,
  }) async {
    final session = _janus.session;
    final json = await _janus.client.getJson(
      '/Users/${session.userId}/Items',
      queryParameters: {
        'Recursive': 'true',
        'IncludeItemTypes': includeItemType,
        'AnyProviderIdEquals': 'tmdb.$tmdbId',
        'Limit': '1',
        'Fields': 'Overview,ProductionYear,Genres,ImageTags,UserData,Chapters',
      },
    );
    final items = _parseItems(json);
    return items.isEmpty ? null : items.first;
  }

  Future<EmbyItem> getItem(String itemId) async {
    final session = _janus.session;
    final json = await _janus.client.getJson(
      '/Users/${session.userId}/Items/$itemId',
      queryParameters: {
        'Fields': 'Overview,ProductionYear,Genres,CommunityRating,ImageTags,UserData,Chapters',
      },
    );
    return EmbyItem.fromJson(json);
  }

  Future<List<EmbyItem>> getSimilarItems(String itemId, {int limit = 30}) async {
    final session = _janus.session;
    final json = await _janus.client.getJson(
      '/Items/$itemId/Similar',
      queryParameters: {
        'UserId': session.userId,
        'Limit': '$limit',
        'Fields': 'Overview,ProductionYear,Genres,CommunityRating,ImageTags,UserData,SeriesId,SeasonId,ParentId',
      },
    );
    return _parseItems(json);
  }

  Future<List<EmbyItem>> getSeasons(String showId) async {
    return _getChildren(
      parentId: showId,
      includeItemTypes: const ['Season'],
    );
  }

  Future<List<EmbyItem>> getEpisodes(String seasonId) async {
    return _getChildren(
      parentId: seasonId,
      includeItemTypes: const ['Episode'],
    );
  }

  Uri primaryImageUri(EmbyItem item, {int maxWidth = 360}) {
    return _janus.client.buildPrimaryImageUri(
      item.id,
      maxWidth: maxWidth,
      tag: item.primaryImageTag,
    );
  }

  Uri thumbImageUri(EmbyItem item, {int maxWidth = 640}) {
    if (item.thumbImageTag == null) {
      return primaryImageUri(item, maxWidth: maxWidth);
    }
    return _janus.client.buildThumbImageUri(
      item.id,
      maxWidth: maxWidth,
      tag: item.thumbImageTag,
    );
  }

  Uri? logoImageUri(EmbyItem item, {int maxWidth = 800}) {
    final tag = item.logoImageTag;
    if (tag == null) return null;
    return _janus.client.buildLogoImageUri(
      item.id,
      maxWidth: maxWidth,
      tag: tag,
    );
  }

  Future<List<EmbyItem>> _getItems({
    required List<String> includeItemTypes,
  }) async {
    return _getSortedItems(
      includeItemTypes: includeItemTypes,
      sortBy: 'SortName',
      sortOrder: 'Ascending',
      limit: null,
    );
  }

  Future<List<EmbyItem>> _getSortedItems({
    required List<String> includeItemTypes,
    required String sortBy,
    required String sortOrder,
    required int? limit,
  }) async {
    final session = _janus.session;
    final json = await _janus.client.getJson(
      '/Users/${session.userId}/Items',
      queryParameters: {
        'Recursive': 'true',
        'IncludeItemTypes': includeItemTypes.join(','),
        'SortBy': sortBy,
        'SortOrder': sortOrder,
        'Limit': limit == null ? null : '$limit',
        'Fields':
            'Overview,ProductionYear,Genres,CommunityRating,ImageTags,UserData,ParentId,SeriesId,SeasonId',
      },
    );
    return _parseItems(json);
  }

  Future<List<EmbyItem>> _getChildren({
    required String parentId,
    required List<String> includeItemTypes,
  }) async {
    final session = _janus.session;
    final json = await _janus.client.getJson(
      '/Users/${session.userId}/Items',
      queryParameters: {
        'ParentId': parentId,
        'IncludeItemTypes': includeItemTypes.join(','),
        'SortBy': includeItemTypes.contains('Episode') ? 'IndexNumber' : 'SortName',
        'SortOrder': 'Ascending',
        'Fields': 'Overview,ProductionYear,ImageTags,UserData,SeriesId,SeasonId,ParentId',
      },
    );

    return _parseItems(json);
  }

  List<EmbyItem> _parseItems(Map<String, dynamic> json) {
    final items = json['Items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => EmbyItem.fromJson(e.cast<String, dynamic>()))
        .where((e) => e.id.isNotEmpty)
        .toList(growable: false);
  }
}
