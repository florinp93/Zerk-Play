import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app.dart';
import '../player/playback_prefs.dart';
import '../settings/app_prefs.dart';
import '../widgets/preferences_form.dart';
import '../../l10n/l10n.dart';

final class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

final class _SetupPageState extends State<SetupPage> {
  final _embyUrlController = TextEditingController();
  final _jellyseerrUrlController = TextEditingController();
  final _jellyseerrApiKeyController = TextEditingController();

  PlaybackPrefs? _playbackPrefs;
  PlaybackQualityPreference _quality = PlaybackPrefs.defaults.qualityPreference;
  String _audioLang = 'auto';
  String _subtitleSelection = 'auto';
  AppLanguage _appLanguage = AppPrefs.defaults.language;
  bool _showFeedbackButton = AppPrefs.defaults.showFeedbackButton;

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final services = AppServicesScope.of(context);
      final cfg = await services.config.load();
      final playbackPrefs = await PlaybackPrefs.load();
      final appPrefs = await AppPrefs.load();
      if (!mounted) return;

      if (cfg != null) {
        _embyUrlController.text = cfg.embyServerUrl.toString();
        _jellyseerrUrlController.text = cfg.jellyseerrUrl.toString();
        _jellyseerrApiKeyController.text = cfg.jellyseerrApiKey;
      }

      var audioLang = playbackPrefs.audioLanguage.trim().isEmpty
          ? 'auto'
          : playbackPrefs.audioLanguage.trim();
      if (audioLang != 'en' && audioLang != 'ro') audioLang = 'auto';

      var subtitleSelection = 'auto';
      if (playbackPrefs.subtitleMode == SubtitlePreferenceMode.off) {
        subtitleSelection = 'off';
      } else if (playbackPrefs.subtitleMode == SubtitlePreferenceMode.language) {
        final lang = playbackPrefs.subtitleLanguage.trim();
        subtitleSelection = (lang == 'en' || lang == 'ro') ? lang : 'auto';
      }

      setState(() {
        _playbackPrefs = playbackPrefs;
        _quality = playbackPrefs.qualityPreference;
        _audioLang = audioLang;
        _subtitleSelection = subtitleSelection;
        _appLanguage = appPrefs.language;
        _showFeedbackButton = appPrefs.showFeedbackButton;
      });
    });
  }

  @override
  void dispose() {
    _embyUrlController.dispose();
    _jellyseerrUrlController.dispose();
    _jellyseerrApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final services = AppServicesScope.of(context);
      final basePlaybackPrefs = _playbackPrefs ?? PlaybackPrefs.defaults;
      await services.config.save(
        embyServerUrl: _embyUrlController.text,
        jellyseerrUrl: _jellyseerrUrlController.text,
        jellyseerrApiKey: _jellyseerrApiKeyController.text,
      );

      final (subtitleMode, subtitleLanguage) = switch (_subtitleSelection) {
        'off' => (SubtitlePreferenceMode.off, ''),
        'auto' => (SubtitlePreferenceMode.auto, ''),
        'en' => (SubtitlePreferenceMode.language, 'en'),
        'ro' => (SubtitlePreferenceMode.language, 'ro'),
        _ => (SubtitlePreferenceMode.auto, ''),
      };
      await PlaybackPrefs.save(
        basePlaybackPrefs.copyWith(
          qualityPreference: _quality,
          audioLanguage: _audioLang == 'auto' ? '' : _audioLang,
          subtitleMode: subtitleMode,
          subtitleLanguage: subtitleLanguage,
        ),
      );
      final nextAppPrefs = AppPrefs(
        language: _appLanguage,
        showFeedbackButton: _showFeedbackButton,
      );
      await AppPrefs.save(nextAppPrefs);

      final cfg = await services.config.load();
      if (cfg == null) {
        throw StateError('Configuration incomplete.');
      }

      await services.janus.init();
      await services.artemis.setConfig(
        baseUrl: cfg.jellyseerrUrl,
        apiKey: cfg.jellyseerrApiKey,
      );

      if (!mounted) return;
      final scope = AppUiScope.of(context);
      scope.isConfigured.value = true;
      scope.locale.value = nextAppPrefs.toLocale();
      scope.showFeedbackButton.value = nextAppPrefs.showFeedbackButton;
      context.go('/login');
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final l10n = context.l10n;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  bg,
                  Color.lerp(bg, Colors.black, 0.25) ?? bg,
                ],
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'First-time setup',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                        textAlign: TextAlign.left,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your Emby and *seerr details to continue.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.82),
                            ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _embyUrlController,
                        decoration: const InputDecoration(labelText: 'Emby Server URL'),
                        textInputAction: TextInputAction.next,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _jellyseerrUrlController,
                        decoration: const InputDecoration(labelText: '*seerr URL'),
                        textInputAction: TextInputAction.next,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _jellyseerrApiKeyController,
                        onSubmitted: (_) => _isLoading ? null : _submit(),
                        decoration: const InputDecoration(labelText: '*seerr API Key'),
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l10n.settings,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      PreferencesForm(
                        appLanguage: _appLanguage,
                        onAppLanguageChanged: (v) => setState(() => _appLanguage = v),
                        showFeedbackButton: _showFeedbackButton,
                        onShowFeedbackButtonChanged: (v) =>
                            setState(() => _showFeedbackButton = v),
                        quality: _quality,
                        onQualityChanged: (v) => setState(() => _quality = v),
                        audioLang: _audioLang,
                        onAudioLangChanged: (v) => setState(() => _audioLang = v),
                        subtitleSelection: _subtitleSelection,
                        onSubtitleSelectionChanged: (v) =>
                            setState(() => _subtitleSelection = v),
                      ),
                      const SizedBox(height: 16),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: TextStyle(color: scheme.error),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.save),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
