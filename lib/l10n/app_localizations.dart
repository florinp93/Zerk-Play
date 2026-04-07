import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ro.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ro'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Zerk Play'**
  String get appTitle;

  /// No description provided for @unknownLibraryType.
  ///
  /// In en, this message translates to:
  /// **'Unknown library type'**
  String get unknownLibraryType;

  /// No description provided for @invalidRequestItem.
  ///
  /// In en, this message translates to:
  /// **'Invalid request item'**
  String get invalidRequestItem;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @movies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get movies;

  /// No description provided for @series.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get series;

  /// No description provided for @shows.
  ///
  /// In en, this message translates to:
  /// **'Shows'**
  String get shows;

  /// No description provided for @collections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get collections;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @moreInfo.
  ///
  /// In en, this message translates to:
  /// **'More Info'**
  String get moreInfo;

  /// No description provided for @continueWatching.
  ///
  /// In en, this message translates to:
  /// **'Continue Watching'**
  String get continueWatching;

  /// No description provided for @latestMovies.
  ///
  /// In en, this message translates to:
  /// **'Latest Movies'**
  String get latestMovies;

  /// No description provided for @recentlyReleasedMovies.
  ///
  /// In en, this message translates to:
  /// **'Recently Released Movies'**
  String get recentlyReleasedMovies;

  /// No description provided for @trendingMovies.
  ///
  /// In en, this message translates to:
  /// **'Trending Movies'**
  String get trendingMovies;

  /// No description provided for @topRatedMovies.
  ///
  /// In en, this message translates to:
  /// **'Top Rated Movies'**
  String get topRatedMovies;

  /// No description provided for @latestSeries.
  ///
  /// In en, this message translates to:
  /// **'Latest Series'**
  String get latestSeries;

  /// No description provided for @recentlyReleasedSeries.
  ///
  /// In en, this message translates to:
  /// **'Recently Released Series'**
  String get recentlyReleasedSeries;

  /// No description provided for @trendingShows.
  ///
  /// In en, this message translates to:
  /// **'Trending Shows'**
  String get trendingShows;

  /// No description provided for @topRatedSeries.
  ///
  /// In en, this message translates to:
  /// **'Top Rated Series'**
  String get topRatedSeries;

  /// No description provided for @becauseYouWatched.
  ///
  /// In en, this message translates to:
  /// **'Because you watched {title}'**
  String becauseYouWatched(Object title);

  /// No description provided for @youMightEnjoy.
  ///
  /// In en, this message translates to:
  /// **'You might enjoy'**
  String get youMightEnjoy;

  /// No description provided for @yourNextBinge.
  ///
  /// In en, this message translates to:
  /// **'Your next binge'**
  String get yourNextBinge;

  /// No description provided for @trendingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Trending unavailable'**
  String get trendingUnavailable;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get appLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageRomanian.
  ///
  /// In en, this message translates to:
  /// **'Romanian'**
  String get languageRomanian;

  /// No description provided for @qualityPreference.
  ///
  /// In en, this message translates to:
  /// **'Quality preference'**
  String get qualityPreference;

  /// No description provided for @qualityAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get qualityAuto;

  /// No description provided for @quality4k.
  ///
  /// In en, this message translates to:
  /// **'4K'**
  String get quality4k;

  /// No description provided for @quality1080p.
  ///
  /// In en, this message translates to:
  /// **'1080p'**
  String get quality1080p;

  /// No description provided for @quality720p.
  ///
  /// In en, this message translates to:
  /// **'720p'**
  String get quality720p;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @subtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get subtitles;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginWelcomeBack;

  /// No description provided for @loginSignInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get loginSignInToContinue;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @watched.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get watched;

  /// No description provided for @markAsWatched.
  ///
  /// In en, this message translates to:
  /// **'Mark as Watched'**
  String get markAsWatched;

  /// No description provided for @startFromBeginning.
  ///
  /// In en, this message translates to:
  /// **'Start from Beginning'**
  String get startFromBeginning;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get listView;

  /// No description provided for @gridView.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get gridView;

  /// No description provided for @season.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get season;

  /// No description provided for @seasons.
  ///
  /// In en, this message translates to:
  /// **'Seasons'**
  String get seasons;

  /// No description provided for @episodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get episodes;

  /// No description provided for @noSeasonsFound.
  ///
  /// In en, this message translates to:
  /// **'No seasons found.'**
  String get noSeasonsFound;

  /// No description provided for @noEpisodesFound.
  ///
  /// In en, this message translates to:
  /// **'No episodes found.'**
  String get noEpisodesFound;

  /// No description provided for @youMightAlsoLike.
  ///
  /// In en, this message translates to:
  /// **'You might also like'**
  String get youMightAlsoLike;

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get quality;

  /// No description provided for @noItemsFound.
  ///
  /// In en, this message translates to:
  /// **'No items found.'**
  String get noItemsFound;

  /// No description provided for @noCollectionsFound.
  ///
  /// In en, this message translates to:
  /// **'No collections found.'**
  String get noCollectionsFound;

  /// No description provided for @playback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get playback;

  /// No description provided for @skipIntro.
  ///
  /// In en, this message translates to:
  /// **'Skip Intro'**
  String get skipIntro;

  /// No description provided for @playNext.
  ///
  /// In en, this message translates to:
  /// **'Play Next'**
  String get playNext;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @nextUp.
  ///
  /// In en, this message translates to:
  /// **'Next Up'**
  String get nextUp;

  /// No description provided for @nextUpIn.
  ///
  /// In en, this message translates to:
  /// **'Next Up in {seconds}'**
  String nextUpIn(Object seconds);

  /// No description provided for @noAudioTracksFound.
  ///
  /// In en, this message translates to:
  /// **'No audio tracks found.'**
  String get noAudioTracksFound;

  /// No description provided for @subtitleSettings.
  ///
  /// In en, this message translates to:
  /// **'Subtitle settings'**
  String get subtitleSettings;

  /// No description provided for @subtitleSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle Settings'**
  String get subtitleSettingsTitle;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSize;

  /// No description provided for @background.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get background;

  /// No description provided for @backgroundOpacity.
  ///
  /// In en, this message translates to:
  /// **'Background opacity'**
  String get backgroundOpacity;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @fullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get fullscreen;

  /// No description provided for @exitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit fullscreen'**
  String get exitFullscreen;

  /// No description provided for @volumePercent.
  ///
  /// In en, this message translates to:
  /// **'Volume {pct}%'**
  String volumePercent(Object pct);

  /// No description provided for @audioTrack.
  ///
  /// In en, this message translates to:
  /// **'Audio {id}'**
  String audioTrack(Object id);

  /// No description provided for @subtitleTrack.
  ///
  /// In en, this message translates to:
  /// **'Subtitle {id}'**
  String subtitleTrack(Object id);

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @releaseYear.
  ///
  /// In en, this message translates to:
  /// **'Release year'**
  String get releaseYear;

  /// No description provided for @any.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get any;

  /// No description provided for @genre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get genre;

  /// No description provided for @yearChip.
  ///
  /// In en, this message translates to:
  /// **'Year {year}'**
  String yearChip(Object year);

  /// No description provided for @loadingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loadingEllipsis;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @requested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get requested;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processing;

  /// No description provided for @request.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get request;

  /// No description provided for @availableSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get availableSectionTitle;

  /// No description provided for @availableSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'In your library'**
  String get availableSectionSubtitle;

  /// No description provided for @requestableSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Requestable'**
  String get requestableSectionTitle;

  /// No description provided for @requestableSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Not in your library'**
  String get requestableSectionSubtitle;

  /// No description provided for @badgeAvailable.
  ///
  /// In en, this message translates to:
  /// **'AVAILABLE'**
  String get badgeAvailable;

  /// No description provided for @badgeRequest.
  ///
  /// In en, this message translates to:
  /// **'REQUEST'**
  String get badgeRequest;

  /// No description provided for @badgePlayed.
  ///
  /// In en, this message translates to:
  /// **'PLAYED'**
  String get badgePlayed;

  /// No description provided for @badgeResume.
  ///
  /// In en, this message translates to:
  /// **'RESUME'**
  String get badgeResume;

  /// No description provided for @badgeMovie.
  ///
  /// In en, this message translates to:
  /// **'MOVIE'**
  String get badgeMovie;

  /// No description provided for @badgeTv.
  ///
  /// In en, this message translates to:
  /// **'TV'**
  String get badgeTv;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search movies and series'**
  String get searchHint;

  /// No description provided for @searchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Search your library or request something new'**
  String get searchEmptyTitle;

  /// No description provided for @searchEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Results show what’s already available, plus requestable items in black & white.'**
  String get searchEmptySubtitle;

  /// No description provided for @tryQuery.
  ///
  /// In en, this message translates to:
  /// **'Try “{query}”'**
  String tryQuery(Object query);

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @tryDifferentTitle.
  ///
  /// In en, this message translates to:
  /// **'Try a different title.'**
  String get tryDifferentTitle;

  /// No description provided for @nothingMatched.
  ///
  /// In en, this message translates to:
  /// **'Nothing matched “{query}”.'**
  String nothingMatched(Object query);

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get searchFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ro'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ro':
      return AppLocalizationsRo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
