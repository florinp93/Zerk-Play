// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get appTitle => 'Zerk Play';

  @override
  String get unknownLibraryType => 'Tip de bibliotecă necunoscut';

  @override
  String get invalidRequestItem => 'Element invalid pentru cerere';

  @override
  String get home => 'Acasă';

  @override
  String get back => 'Înapoi';

  @override
  String get search => 'Căutare';

  @override
  String get movies => 'Filme';

  @override
  String get series => 'Seriale';

  @override
  String get shows => 'Seriale';

  @override
  String get collections => 'Colecții';

  @override
  String get settings => 'Setări';

  @override
  String get logout => 'Deconectare';

  @override
  String get viewAll => 'Vezi toate';

  @override
  String get moreInfo => 'Mai multe informații';

  @override
  String get continueWatching => 'Continuă vizionarea';

  @override
  String get latestMovies => 'Filme adăugate recent';

  @override
  String get recentlyReleasedMovies => 'Filme lansate recent';

  @override
  String get trendingMovies => 'Filme în tendințe';

  @override
  String get topRatedMovies => 'Filme cu rating mare';

  @override
  String get latestSeries => 'Seriale adăugate recent';

  @override
  String get recentlyReleasedSeries => 'Seriale lansate recent';

  @override
  String get trendingShows => 'Seriale în tendințe';

  @override
  String get topRatedSeries => 'Seriale cu rating mare';

  @override
  String becauseYouWatched(Object title) {
    return 'Pentru că ai urmărit $title';
  }

  @override
  String get youMightEnjoy => 'S-ar putea să-ți placă';

  @override
  String get yourNextBinge => 'Următorul tău maraton';

  @override
  String get trendingUnavailable => 'Tendințe indisponibile';

  @override
  String get artemisConnectionFailed =>
      'Nu pot accesa *seerr. Verifică URL-ul, cheia API și conexiunea la internet.';

  @override
  String get artemisConnectionFailedCertificate =>
      'Nu pot accesa *seerr: problemă HTTPS sau certificat. Verifică URL-ul, lanțul de certificate și că folosești adresa de bază *seerr (nu cea Emby).';

  @override
  String get artemisConnectionFailedDns =>
      'Nu pot accesa *seerr: nu pot rezolva numele serverului. Verifică DNS-ul Wi‑Fi (încearcă să dezactivezi DNS privat) sau URL-ul introdus.';

  @override
  String get artemisConnectionFailedNetwork =>
      'Nu pot accesa *seerr: eroare de rețea (timeout, refuz sau indisponibil). Verifică că TV-ul e online, serverul rulează și DNS/IPv6 pentru domeniu.';

  @override
  String get artemisWrongServerNotJellyseerr =>
      'Acest URL nu este serverul *seerr (de exemplu indică Emby). Folosește adresa de bază Jellyseerr — adesea un subdomeniu separat, ex. https://request.example.com — nu URL-ul Emby.';

  @override
  String get artemisDiagnosticsTitle => 'Diagnostic conexiune *seerr';

  @override
  String get artemisDiagnosticsOpen => 'Diagnostic conexiune';

  @override
  String get artemisDiagnosticsTest => 'Testează conexiunea';

  @override
  String get artemisDiagnosticsSeerrUrl => 'URL *seerr salvat';

  @override
  String get artemisDiagnosticsResult => 'Rezultat';

  @override
  String get artemisDiagnosticsDebugLine => 'Detaliu tehnic (pentru suport)';

  @override
  String get artemisDiagnosticsCopy => 'Copiază detaliile';

  @override
  String get artemisDiagnosticsCopyDone => 'Copiat în clipboard';

  @override
  String get artemisDiagnosticsNotConfigured =>
      'Configurare incompletă: salvează mai întâi URL-ul și cheia API *seerr.';

  @override
  String get artemisDiagnosticsInfraTips =>
      'Dacă doar acest dispozitiv eșuează:\n• Server: lanț TLS complet, SNI corect, TLS 1.2+; evită renegocierea TLS defectă.\n• DNS: verifică A și AAAA pentru hostul *seerr; corectează sau șterge AAAA invalid.\n• Android TV: încearcă fără DNS privat; verifică Pi-hole / DNS router.\n• Reverse proxy: hostul trebuie să ducă la Jellyseerr, nu Emby.';

  @override
  String get artemisDiagnosticsReachableYes =>
      'Accesibil — Jellyseerr răspunde corect.';

  @override
  String get artemisDiagnosticsReachableNo => 'Neaccesibil';

  @override
  String get save => 'Salvează';

  @override
  String get cancel => 'Anulează';

  @override
  String get clear => 'Șterge';

  @override
  String get apply => 'Aplică';

  @override
  String get appLanguage => 'Limba aplicației';

  @override
  String get languageSystem => 'Sistem';

  @override
  String get languageEnglish => 'Engleză';

  @override
  String get languageRomanian => 'Română';

  @override
  String get qualityPreference => 'Preferință calitate';

  @override
  String get qualityAuto => 'Automat';

  @override
  String get quality4k => '4K';

  @override
  String get quality1080p => '1080p';

  @override
  String get quality720p => '720p';

  @override
  String get audio => 'Audio';

  @override
  String get subtitles => 'Subtitrări';

  @override
  String get off => 'Oprit';

  @override
  String get auto => 'Automat';

  @override
  String get signOut => 'Deconectare';

  @override
  String get signIn => 'Autentificare';

  @override
  String get username => 'Utilizator';

  @override
  String get password => 'Parolă';

  @override
  String get loginWelcomeBack => 'Bine ai revenit';

  @override
  String get loginSignInToContinue => 'Autentifică-te pentru a continua';

  @override
  String get resume => 'Reia';

  @override
  String get play => 'Redă';

  @override
  String get pause => 'Pauză';

  @override
  String get watched => 'Vizionat';

  @override
  String get markAsWatched => 'Marchează ca vizionat';

  @override
  String get startFromBeginning => 'Pornește de la început';

  @override
  String get details => 'Detalii';

  @override
  String get listView => 'Listă';

  @override
  String get gridView => 'Grilă';

  @override
  String get season => 'Sezon';

  @override
  String get seasons => 'Sezoane';

  @override
  String get episodes => 'Episoade';

  @override
  String get noSeasonsFound => 'Nu s-au găsit sezoane.';

  @override
  String get noEpisodesFound => 'Nu s-au găsit episoade.';

  @override
  String get youMightAlsoLike => 'S-ar putea să-ți placă și';

  @override
  String get quality => 'Calitate';

  @override
  String get noItemsFound => 'Nu s-au găsit elemente.';

  @override
  String get noCollectionsFound => 'Nu s-au găsit colecții.';

  @override
  String get playback => 'Redare';

  @override
  String get skipIntro => 'Sari peste intro';

  @override
  String get playNext => 'Redă următorul';

  @override
  String get dismiss => 'Închide';

  @override
  String get nextUp => 'Urmează';

  @override
  String nextUpIn(Object seconds) {
    return 'Urmează în $seconds';
  }

  @override
  String get noAudioTracksFound => 'Nu s-au găsit piste audio.';

  @override
  String get subtitleSettings => 'Setări subtitrări';

  @override
  String get subtitleSettingsTitle => 'Setări subtitrări';

  @override
  String get fontSize => 'Mărime font';

  @override
  String get background => 'Fundal';

  @override
  String get backgroundOpacity => 'Opacitate fundal';

  @override
  String get reset => 'Resetează';

  @override
  String get close => 'Închide';

  @override
  String get fullscreen => 'Ecran complet';

  @override
  String get exitFullscreen => 'Ieși din ecran complet';

  @override
  String volumePercent(Object pct) {
    return 'Volum $pct%';
  }

  @override
  String audioTrack(Object id) {
    return 'Audio $id';
  }

  @override
  String subtitleTrack(Object id) {
    return 'Subtitrare $id';
  }

  @override
  String get filters => 'Filtre';

  @override
  String get filter => 'Filtru';

  @override
  String get releaseYear => 'Anul lansării';

  @override
  String get any => 'Oricare';

  @override
  String get genre => 'Gen';

  @override
  String yearChip(Object year) {
    return 'Anul $year';
  }

  @override
  String get loadingEllipsis => 'Se încarcă…';

  @override
  String get unavailable => 'Indisponibil';

  @override
  String get requested => 'Cerut';

  @override
  String get processing => 'În procesare';

  @override
  String get request => 'Cere';

  @override
  String get availableSectionTitle => 'Disponibile';

  @override
  String get availableSectionSubtitle => 'În biblioteca ta';

  @override
  String get requestableSectionTitle => 'Disponibile la cerere';

  @override
  String get requestableSectionSubtitle => 'Nu sunt în biblioteca ta';

  @override
  String get badgeAvailable => 'DISPONIBIL';

  @override
  String get badgeRequest => 'CERE';

  @override
  String get badgePlayed => 'VIZIONAT';

  @override
  String get badgeResume => 'REIA';

  @override
  String get badgeMovie => 'FILM';

  @override
  String get badgeTv => 'TV';

  @override
  String get searchHint => 'Caută filme și seriale';

  @override
  String get searchEmptyTitle => 'Caută în bibliotecă sau cere ceva nou';

  @override
  String get searchEmptySubtitle =>
      'Rezultatele arată ce e deja disponibil, plus titluri ce pot fi cerute în alb-negru.';

  @override
  String tryQuery(Object query) {
    return 'Încearcă „$query”';
  }

  @override
  String get noResults => 'Niciun rezultat';

  @override
  String get tryDifferentTitle => 'Încearcă un alt titlu.';

  @override
  String nothingMatched(Object query) {
    return 'Nimic nu corespunde cu „$query”.';
  }

  @override
  String get searchFailed => 'Căutarea a eșuat';

  @override
  String get exitApp => 'Închide aplicația';

  @override
  String get exitAppConfirm => 'Ești sigur că vrei să închizi aplicația?';

  @override
  String get exit => 'Închide';

  @override
  String get playerSettings => 'Player / MPV…';

  @override
  String get playerSettingsMpvTitle => 'Player (mpv)';

  @override
  String get playerSettingsMatchRefreshRate =>
      'Potrivește refresh‑ul display‑ului cu videoclipul';

  @override
  String get playerSettingsMatchRefreshRateHelp =>
      'Doar display principal. Poate clipi; multi‑monitor și HDR pot avea probleme. Implicit oprit.';

  @override
  String get playerSettingsMatchRefreshRateFullscreenOnly =>
      'Doar pe ecran complet';

  @override
  String playerSettingsMpvPathFull(Object path) {
    return 'mpv.conf:\n$path';
  }

  @override
  String get playerSettingsMpvHelp =>
      'Încărcat după valorile implicite aplicației, deci opțiunile de aici le pot suprascrie. Manual mpv: https://mpv.io/manual/master/';

  @override
  String get playerSettingsOpenConfigFolder =>
      'Deschide folderul de configurare';
}
