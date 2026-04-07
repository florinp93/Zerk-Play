import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { system, en, ro }

final class AppPrefs {
  const AppPrefs({
    required this.language,
    required this.showFeedbackButton,
  });

  final AppLanguage language;
  final bool showFeedbackButton;

  static const defaults = AppPrefs(
    language: AppLanguage.system,
    showFeedbackButton: true,
  );

  static const _kAppLanguage = 'app_language';
  static const _kShowFeedbackButton = 'app_show_feedback_button';

  static Future<AppPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(_kAppLanguage) ?? '').trim().toLowerCase();
    final show = prefs.getBool(_kShowFeedbackButton) ?? defaults.showFeedbackButton;
    return AppPrefs(
      language: _parseLanguage(raw) ?? defaults.language,
      showFeedbackButton: show,
    );
  }

  static Future<void> save(AppPrefs value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAppLanguage, _encodeLanguage(value.language));
    await prefs.setBool(_kShowFeedbackButton, value.showFeedbackButton);
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
