final class EmbyItem {
  EmbyItem({
    required this.id,
    required this.name,
    required this.type,
    required this.primaryImageTag,
    required this.thumbImageTag,
    required this.logoImageTag,
    required this.communityRating,
    required this.genres,
    required this.overview,
    required this.productionYear,
    required this.parentId,
    required this.seriesId,
    required this.seasonId,
    required this.runTimeTicks,
    required this.isPlayed,
    required this.playbackPositionTicks,
    required this.playedPercentage,
    required this.introStartTicks,
    required this.introEndTicks,
    required this.creditsStartTicks,
  });

  final String id;
  final String name;
  final String type;
  final String? primaryImageTag;
  final String? thumbImageTag;
  final String? logoImageTag;
  final double? communityRating;
  final List<String> genres;
  final String? overview;
  final int? productionYear;
  final String? parentId;
  final String? seriesId;
  final String? seasonId;
  final int? runTimeTicks;
  final bool isPlayed;
  final int? playbackPositionTicks;
  final double? playedPercentage;
  final int? introStartTicks;
  final int? introEndTicks;
  final int? creditsStartTicks;

  factory EmbyItem.fromJson(Map<String, dynamic> json) {
    final imageTags = json['ImageTags'];
    String? primaryTag;
    String? thumbTag;
    String? logoTag;
    if (imageTags is Map) {
      final tag = imageTags['Primary'];
      if (tag is String && tag.isNotEmpty) primaryTag = tag;
      final t = imageTags['Thumb'];
      if (t is String && t.isNotEmpty) thumbTag = t;
      final l = imageTags['Logo'];
      if (l is String && l.isNotEmpty) logoTag = l;
    }

    final userData = json['UserData'];
    int? playbackPositionTicks;
    var isPlayed = false;
    double? playedPercentage;
    if (userData is Map) {
      final value = userData['PlaybackPositionTicks'];
      if (value is int) {
        playbackPositionTicks = value;
      } else if (value is num) {
        playbackPositionTicks = value.toInt();
      }
      final playedValue = userData['Played'];
      if (playedValue is bool) {
        isPlayed = playedValue;
      }
      final pctValue = userData['PlayedPercentage'];
      if (pctValue is num) {
        playedPercentage = pctValue.toDouble();
      }
    }

    int? runTimeTicks;
    final rtValue = json['RunTimeTicks'];
    if (rtValue is int) {
      runTimeTicks = rtValue;
    } else if (rtValue is num) {
      runTimeTicks = rtValue.toInt();
    }

    final genresOut = <String>[];
    final genresValue = json['Genres'];
    if (genresValue is List) {
      for (final g in genresValue) {
        if (g is String && g.trim().isNotEmpty) {
          genresOut.add(g.trim());
        }
      }
    }

    double? communityRating;
    final ratingValue = json['CommunityRating'];
    if (ratingValue is num) {
      communityRating = ratingValue.toDouble();
    }

    int? introStartTicks;
    int? introEndTicks;
    int? creditsStartTicks;
    final chapters = json['Chapters'];
    if (chapters is List) {
      for (final c in chapters) {
        if (c is! Map) continue;
        final markerType = c['MarkerType'];
        final nameValue = c['Name'];
        final startValue = c['StartPositionTicks'];
        final endValue = c['EndPositionTicks'];
        if (markerType is! String) continue;
        final startTicks =
            startValue is num ? startValue.toInt() : (startValue as int?) ?? 0;
        final endTicks =
            endValue is num ? endValue.toInt() : (endValue as int?) ?? 0;

        if (markerType == 'IntroStart') {
          introStartTicks ??= startTicks;
        } else if (markerType == 'IntroEnd') {
          introEndTicks ??= startTicks;
        } else if (markerType == 'CreditsStart') {
          creditsStartTicks ??= startTicks;
        } else if (markerType == 'Chapter' && nameValue is String) {
          final name = nameValue.toLowerCase().trim();
          if (name.contains('credits')) {
            creditsStartTicks ??= startTicks;
          }
          if (name.contains('intro')) {
            if (endTicks > startTicks) {
              introStartTicks ??= startTicks;
              introEndTicks ??= endTicks;
            } else if (name.contains('end')) {
              introEndTicks ??= startTicks;
            } else if (name.contains('start')) {
              introStartTicks ??= startTicks;
            } else {
              introStartTicks ??= startTicks;
            }
          }
        }
      }
    }

    return EmbyItem(
      id: (json['Id'] as String?) ?? '',
      name: (json['Name'] as String?) ?? '',
      type: (json['Type'] as String?) ?? '',
      primaryImageTag: primaryTag,
      thumbImageTag: thumbTag,
      logoImageTag: logoTag,
      communityRating: communityRating,
      genres: genresOut,
      overview: json['Overview'] as String?,
      productionYear: json['ProductionYear'] as int?,
      parentId: json['ParentId'] as String?,
      seriesId: json['SeriesId'] as String?,
      seasonId: json['SeasonId'] as String?,
      runTimeTicks: runTimeTicks,
      isPlayed: isPlayed,
      playbackPositionTicks: playbackPositionTicks,
      playedPercentage: playedPercentage,
      introStartTicks: introStartTicks,
      introEndTicks: introEndTicks,
      creditsStartTicks: creditsStartTicks,
    );
  }
}
