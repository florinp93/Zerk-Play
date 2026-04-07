import 'package:shared_preferences/shared_preferences.dart';

enum EpisodesLayout { list, grid }

final class ShowDetailsPrefs {
  static const _kEpisodesLayout = 'details.episodes_layout';

  static Future<EpisodesLayout> loadEpisodesLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(_kEpisodesLayout) ?? '').trim().toLowerCase();
    if (raw == 'grid') return EpisodesLayout.grid;
    return EpisodesLayout.list;
  }

  static Future<void> saveEpisodesLayout(EpisodesLayout value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEpisodesLayout, value == EpisodesLayout.grid ? 'grid' : 'list');
  }
}

