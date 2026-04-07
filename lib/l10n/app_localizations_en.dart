// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Zerk Play';

  @override
  String get unknownLibraryType => 'Unknown library type';

  @override
  String get invalidRequestItem => 'Invalid request item';

  @override
  String get home => 'Home';

  @override
  String get back => 'Back';

  @override
  String get search => 'Search';

  @override
  String get movies => 'Movies';

  @override
  String get series => 'Series';

  @override
  String get shows => 'Shows';

  @override
  String get collections => 'Collections';

  @override
  String get settings => 'Settings';

  @override
  String get logout => 'Logout';

  @override
  String get viewAll => 'View all';

  @override
  String get moreInfo => 'More Info';

  @override
  String get continueWatching => 'Continue Watching';

  @override
  String get latestMovies => 'Latest Movies';

  @override
  String get recentlyReleasedMovies => 'Recently Released Movies';

  @override
  String get trendingMovies => 'Trending Movies';

  @override
  String get topRatedMovies => 'Top Rated Movies';

  @override
  String get latestSeries => 'Latest Series';

  @override
  String get recentlyReleasedSeries => 'Recently Released Series';

  @override
  String get trendingShows => 'Trending Shows';

  @override
  String get topRatedSeries => 'Top Rated Series';

  @override
  String becauseYouWatched(Object title) {
    return 'Because you watched $title';
  }

  @override
  String get youMightEnjoy => 'You might enjoy';

  @override
  String get yourNextBinge => 'Your next binge';

  @override
  String get trendingUnavailable => 'Trending unavailable';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get clear => 'Clear';

  @override
  String get apply => 'Apply';

  @override
  String get appLanguage => 'App language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRomanian => 'Romanian';

  @override
  String get qualityPreference => 'Quality preference';

  @override
  String get qualityAuto => 'Auto';

  @override
  String get quality4k => '4K';

  @override
  String get quality1080p => '1080p';

  @override
  String get quality720p => '720p';

  @override
  String get audio => 'Audio';

  @override
  String get subtitles => 'Subtitles';

  @override
  String get off => 'Off';

  @override
  String get auto => 'Auto';

  @override
  String get signOut => 'Sign out';

  @override
  String get signIn => 'Sign in';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get loginWelcomeBack => 'Welcome back';

  @override
  String get loginSignInToContinue => 'Sign in to continue';

  @override
  String get resume => 'Resume';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get watched => 'Watched';

  @override
  String get markAsWatched => 'Mark as Watched';

  @override
  String get startFromBeginning => 'Start from Beginning';

  @override
  String get details => 'Details';

  @override
  String get listView => 'List view';

  @override
  String get gridView => 'Grid view';

  @override
  String get season => 'Season';

  @override
  String get seasons => 'Seasons';

  @override
  String get episodes => 'Episodes';

  @override
  String get noSeasonsFound => 'No seasons found.';

  @override
  String get noEpisodesFound => 'No episodes found.';

  @override
  String get youMightAlsoLike => 'You might also like';

  @override
  String get quality => 'Quality';

  @override
  String get noItemsFound => 'No items found.';

  @override
  String get noCollectionsFound => 'No collections found.';

  @override
  String get playback => 'Playback';

  @override
  String get skipIntro => 'Skip Intro';

  @override
  String get playNext => 'Play Next';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get nextUp => 'Next Up';

  @override
  String nextUpIn(Object seconds) {
    return 'Next Up in $seconds';
  }

  @override
  String get noAudioTracksFound => 'No audio tracks found.';

  @override
  String get subtitleSettings => 'Subtitle settings';

  @override
  String get subtitleSettingsTitle => 'Subtitle Settings';

  @override
  String get fontSize => 'Font size';

  @override
  String get background => 'Background';

  @override
  String get backgroundOpacity => 'Background opacity';

  @override
  String get reset => 'Reset';

  @override
  String get close => 'Close';

  @override
  String get fullscreen => 'Fullscreen';

  @override
  String get exitFullscreen => 'Exit fullscreen';

  @override
  String volumePercent(Object pct) {
    return 'Volume $pct%';
  }

  @override
  String audioTrack(Object id) {
    return 'Audio $id';
  }

  @override
  String subtitleTrack(Object id) {
    return 'Subtitle $id';
  }

  @override
  String get filters => 'Filters';

  @override
  String get filter => 'Filter';

  @override
  String get releaseYear => 'Release year';

  @override
  String get any => 'Any';

  @override
  String get genre => 'Genre';

  @override
  String yearChip(Object year) {
    return 'Year $year';
  }

  @override
  String get loadingEllipsis => 'Loading…';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get requested => 'Requested';

  @override
  String get processing => 'Processing';

  @override
  String get request => 'Request';

  @override
  String get availableSectionTitle => 'Available';

  @override
  String get availableSectionSubtitle => 'In your library';

  @override
  String get requestableSectionTitle => 'Requestable';

  @override
  String get requestableSectionSubtitle => 'Not in your library';

  @override
  String get badgeAvailable => 'AVAILABLE';

  @override
  String get badgeRequest => 'REQUEST';

  @override
  String get badgePlayed => 'PLAYED';

  @override
  String get badgeResume => 'RESUME';

  @override
  String get badgeMovie => 'MOVIE';

  @override
  String get badgeTv => 'TV';

  @override
  String get searchHint => 'Search movies and series';

  @override
  String get searchEmptyTitle => 'Search your library or request something new';

  @override
  String get searchEmptySubtitle =>
      'Results show what’s already available, plus requestable items in black & white.';

  @override
  String tryQuery(Object query) {
    return 'Try “$query”';
  }

  @override
  String get noResults => 'No results';

  @override
  String get tryDifferentTitle => 'Try a different title.';

  @override
  String nothingMatched(Object query) {
    return 'Nothing matched “$query”.';
  }

  @override
  String get searchFailed => 'Search failed';
}
