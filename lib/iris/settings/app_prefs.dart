import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { system, en, ro }

enum CollectionsViewMode { card, grid }

final class AppPrefs {
  const AppPrefs({
    required this.language,
    required this.showFeedbackButton,
    required this.startFullscreen,
    required this.collectionsViewMode,
    required this.acceptInvalidCertificates,
  });

  final AppLanguage language;
  final bool showFeedbackButton;
  final bool startFullscreen;
  final CollectionsViewMode collectionsViewMode;
  final bool acceptInvalidCertificates;

  static const defaults = AppPrefs(
    language: AppLanguage.system,
    showFeedbackButton: true,
    startFullscreen: false,
    collectionsViewMode: CollectionsViewMode.card,
    acceptInvalidCertificates: false,
  );

  AppPrefs copyWith({
    AppLanguage? language,
    bool? showFeedbackButton,
    bool? startFullscreen,
    CollectionsViewMode? collectionsViewMode,
    bool? acceptInvalidCertificates,
  }) => AppPrefs(
        language: language ?? this.language,
        showFeedbackButton: showFeedbackButton ?? this.showFeedbackButton,
        startFullscreen: startFullscreen ?? this.startFullscreen,
        collectionsViewMode: collectionsViewMode ?? this.collectionsViewMode,
        acceptInvalidCertificates: acceptInvalidCertificates ?? this.acceptInvalidCertificates,
      );

  static const _kAppLanguage = 'app_language';
  static const _kShowFeedbackButton = 'app_show_feedback_button';
  static const _kStartFullscreen = 'app_start_fullscreen';
  static const _kCollectionsView = 'app_collections_view';
  static const _kAcceptInvalidCerts = 'app_accept_invalid_certs';

  static Future<AppPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(_kAppLanguage) ?? '').trim().toLowerCase();
    final show = prefs.getBool(_kShowFeedbackButton) ?? defaults.showFeedbackButton;
    final fs = prefs.getBool(_kStartFullscreen) ?? defaults.startFullscreen;
    final cvRaw = prefs.getString(_kCollectionsView) ?? '';
    final cv = cvRaw == 'grid' ? CollectionsViewMode.grid : CollectionsViewMode.card;
    final acceptCerts = prefs.getBool(_kAcceptInvalidCerts) ?? defaults.acceptInvalidCertificates;
    return AppPrefs(
      language: _parseLanguage(raw) ?? defaults.language,
      showFeedbackButton: show,
      startFullscreen: fs,
      collectionsViewMode: cv,
      acceptInvalidCertificates: acceptCerts,
    );
  }

  static Future<void> save(AppPrefs value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAppLanguage, _encodeLanguage(value.language));
    await prefs.setBool(_kShowFeedbackButton, value.showFeedbackButton);
    await prefs.setBool(_kStartFullscreen, value.startFullscreen);
    await prefs.setString(
      _kCollectionsView,
      value.collectionsViewMode == CollectionsViewMode.grid ? 'grid' : 'card',
    );
    await prefs.setBool(_kAcceptInvalidCerts, value.acceptInvalidCertificates);
  }

  Locale? toLocale() {
    switch (language) {
      case AppLanguage.system:
        return null;
      case AppLanguage.en:
        return const Locale('en');
      case AppLanguage.ro:
        return const Locale('ro');
    }
  }
}

AppLanguage? _parseLanguage(String raw) {
  switch (raw) {
    case 'system':
    case 'auto':
    case '':
      return AppLanguage.system;
    case 'en':
    case 'english':
      return AppLanguage.en;
    case 'ro':
    case 'romanian':
      return AppLanguage.ro;
  }
  return null;
}

String _encodeLanguage(AppLanguage value) {
  switch (value) {
    case AppLanguage.system:
      return 'system';
    case AppLanguage.en:
      return 'en';
    case AppLanguage.ro:
      return 'ro';
  }
}
