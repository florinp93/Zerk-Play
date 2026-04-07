import '../../core/storage/local_store.dart';

final class AppConfig {
  AppConfig({
    required this.embyServerUrl,
    required this.jellyseerrUrl,
    required this.jellyseerrApiKey,
  });

  final Uri embyServerUrl;
  final Uri jellyseerrUrl;
  final String jellyseerrApiKey;
}

final class ConfigService {
  ConfigService({required LocalStore store}) : _store = store;

  static const kEmbyServerUrl = 'emby.serverUrl';
  static const kEmbyUsername = 'emby.username';
  static const kEmbyPassword = 'emby.password';
  static const kJellyseerrUrl = 'jellyseerr.baseUrl';
  static const kJellyseerrApiKey = 'jellyseerr.apiKey';
  static const kSkippedUpdateVersion = 'app.skippedUpdateVersion';

  final LocalStore _store;

  Future<String?> getSkippedUpdateVersion() async {
    final v = await _store.getString(kSkippedUpdateVersion);
    final out = (v ?? '').trim();
    return out.isEmpty ? null : out;
  }

  Future<void> setSkippedUpdateVersion(String version) async {
    final v = version.trim();
    if (v.isEmpty) return;
    await _store.setString(kSkippedUpdateVersion, v);
  }

  Future<String?> getEmbyUsername() async {
    final v = await _store.getString(kEmbyUsername);
    final out = (v ?? '').trim();
    return out.isEmpty ? null : out;
  }

  Future<String?> getEmbyPassword() async {
    final v = await _store.getString(kEmbyPassword);
    final out = (v ?? '').trim();
    return out.isEmpty ? null : out;
  }

  Future<void> setEmbyCredentials({
    required String username,
    required String password,
  }) async {
    final u = username.trim();
    final p = password;
    if (u.isEmpty) return;
    if (p.isEmpty) return;
    await _store.setString(kEmbyUsername, u);
    await _store.setString(kEmbyPassword, p);
  }

  Future<AppConfig?> load() async {
    final embyServerUrl = await _store.getString(kEmbyServerUrl);
    final jellyseerrUrl = await _store.getString(kJellyseerrUrl);
    final apiKey = await _store.getString(kJellyseerrApiKey);

    final emby = _tryParseUrl(embyServerUrl);
    final jelly = _tryParseUrl(jellyseerrUrl);
    final key = (apiKey ?? '').trim();

    if (emby == null || jelly == null || key.isEmpty) return null;
    return AppConfig(
      embyServerUrl: emby,
      jellyseerrUrl: jelly,
      jellyseerrApiKey: key,
    );
  }

  Future<bool> isConfigured() async => (await load()) != null;

  Future<void> save({
    required String embyServerUrl,
    required String jellyseerrUrl,
    required String jellyseerrApiKey,
  }) async {
    final emby = _parseRequiredUrl(embyServerUrl);
    final jelly = _parseRequiredUrl(jellyseerrUrl);
    final key = jellyseerrApiKey.trim();

    if (key.isEmpty) throw ArgumentError.value(jellyseerrApiKey, 'jellyseerrApiKey', 'Required.');

    await _store.setString(kEmbyServerUrl, emby.toString());
    await _store.setString(kJellyseerrUrl, jelly.toString());
    await _store.setString(kJellyseerrApiKey, key);
  }
}

Uri _parseRequiredUrl(String raw) {
  final parsed = _tryParseUrl(raw);
  if (parsed == null) throw ArgumentError.value(raw, 'url', 'Invalid URL.');
  return parsed;
}

Uri? _tryParseUrl(String? raw) {
  var value = (raw ?? '').trim();
  if (value.isEmpty) return null;
  if (!value.contains('://')) value = 'https://$value';
  try {
    final uri = Uri.parse(value);
    if (!uri.hasScheme || uri.host.isEmpty) return null;
    return uri.replace(fragment: '', queryParameters: null);
  } catch (_) {
    return null;
  }
}
