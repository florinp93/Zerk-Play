import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app.dart';
import '../../app/services/app_services.dart';
import '../../l10n/l10n.dart';
import '../player/playback_prefs.dart';
import '../settings/app_prefs.dart';
import '../widgets/ott_focusable.dart';
import 'preferences_form.dart';

Future<void> showSettingsDialog({
  required BuildContext context,
  required AppServices services,
}) async {
  final prefs = await PlaybackPrefs.load();
  final appPrefs = await AppPrefs.load();
  if (!context.mounted) return;

  var quality = prefs.qualityPreference;
  var audioLang = prefs.audioLanguage.trim().isEmpty ? 'auto' : prefs.audioLanguage.trim();
  if (audioLang != 'en' && audioLang != 'ro') audioLang = 'auto';

  var subtitleSelection = 'auto';
  if (prefs.subtitleMode == SubtitlePreferenceMode.off) {
    subtitleSelection = 'off';
  } else if (prefs.subtitleMode == SubtitlePreferenceMode.language) {
    final lang = prefs.subtitleLanguage.trim();
    subtitleSelection = (lang == 'en' || lang == 'ro') ? lang : 'auto';
  }
  var appLanguage = appPrefs.language;
  var showFeedbackButton = appPrefs.showFeedbackButton;

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final l10n = context.l10n;
          return AlertDialog(
            title: Text(l10n.settings),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PreferencesForm(
                    appLanguage: appLanguage,
                    onAppLanguageChanged: (v) => setState(() => appLanguage = v),
                    showFeedbackButton: showFeedbackButton,
                    onShowFeedbackButtonChanged: (v) => setState(() => showFeedbackButton = v),
                    quality: quality,
                    onQualityChanged: (v) => setState(() => quality = v),
                    audioLang: audioLang,
                    onAudioLangChanged: (v) => setState(() => audioLang = v),
                    subtitleSelection: subtitleSelection,
                    onSubtitleSelectionChanged: (v) => setState(() => subtitleSelection = v),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: () async {
                      await services.janus.logout();
                      await services.artemis.clearSession();
                      if (!context.mounted) return;
                      AppUiScope.of(context).isAuthenticated.value = false;
                      context.pop();
                    },
                    child: Text(l10n.signOut),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => context.pop(), child: Text(l10n.cancel)),
              FilledButton(
                onPressed: () async {
                  final (subtitleMode, subtitleLanguage) = switch (subtitleSelection) {
                    'off' => (SubtitlePreferenceMode.off, ''),
                    'auto' => (SubtitlePreferenceMode.auto, ''),
                    'en' => (SubtitlePreferenceMode.language, 'en'),
                    'ro' => (SubtitlePreferenceMode.language, 'ro'),
                    _ => (SubtitlePreferenceMode.auto, ''),
                  };
                  await PlaybackPrefs.save(
                    prefs.copyWith(
                      qualityPreference: quality,
                      audioLanguage: audioLang == 'auto' ? '' : audioLang,
                      subtitleMode: subtitleMode,
                      subtitleLanguage: subtitleLanguage,
                    ),
                  );
                  final nextAppPrefs = AppPrefs(
                    language: appLanguage,
                    showFeedbackButton: showFeedbackButton,
                  );
                  await AppPrefs.save(nextAppPrefs);
                  if (context.mounted) {
                    final scope = AppUiScope.of(context);
                    scope.locale.value = nextAppPrefs.toLocale();
                    scope.showFeedbackButton.value = nextAppPrefs.showFeedbackButton;
                  }
                  if (context.mounted) context.pop();
                },
                child: Text(l10n.save),
              ),
            ],
          );
        },
      );
    },
  );
}

final class AppFloatingMenu extends StatelessWidget {
  const AppFloatingMenu({super.key});

  static const double reservedTopPadding = 84;

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);
    final state = GoRouterState.of(context);
    final location = state.uri.toString();
    final onHome = location == '/' || location.startsWith('/?');
    final showBack = !onHome;
    final l10n = context.l10n;

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _GlassMenu(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MenuIconButton(
                  tooltip: l10n.home,
                  icon: Icons.home_rounded,
                  onPressed: () {
                    final router = GoRouter.of(context);
                    while (router.canPop()) {
                      context.pop();
                    }
                    context.go('/');
                    final scope = AppUiScope.of(context);
                    scope.homeRefreshTick.value = scope.homeRefreshTick.value + 1;
                  },
                ),
                if (showBack) ...[
                  const SizedBox(width: 10),
                  _MenuIconButton(
                    tooltip: l10n.back,
                    icon: Icons.arrow_back_rounded,
                    onPressed: () {
                      if (GoRouter.of(context).canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
                  ),
                ],
                const SizedBox(width: 14),
                _MenuLabeledButton(
                  icon: Icons.search_rounded,
                  label: l10n.search,
                  onPressed: () => context.push('/search'),
                ),
                const SizedBox(width: 10),
                _MenuLabeledButton(
                  icon: Icons.movie_rounded,
                  label: l10n.movies,
                  onPressed: () => context.push('/library/movies'),
                ),
                const SizedBox(width: 10),
                _MenuLabeledButton(
                  icon: Icons.tv_rounded,
                  label: l10n.series,
                  onPressed: () => context.push('/library/series'),
                ),
                const SizedBox(width: 10),
                _MenuLabeledButton(
                  icon: Icons.collections_bookmark_rounded,
                  label: l10n.collections,
                  onPressed: () => context.push('/collections'),
                ),
                const SizedBox(width: 10),
                _MenuLabeledButton(
                  icon: Icons.settings_rounded,
                  label: l10n.settings,
                  onPressed: () => showSettingsDialog(context: context, services: services),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _GlassMenu extends StatelessWidget {
  const _GlassMenu({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: surface.withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: child,
        ),
      ),
    );
  }
}

final class _MenuIconButton extends StatelessWidget {
  const _MenuIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OttFocusableCard(
      borderRadius: 999,
      focusScale: 1.06,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Material(
            color: Colors.white.withValues(alpha: 0.06),
            child: InkWell(
              onTap: onPressed,
              child: Icon(icon, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

final class _MenuLabeledButton extends StatelessWidget {
  const _MenuLabeledButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OttFocusableCard(
      borderRadius: 999,
      focusScale: 1.06,
      child: Material(
        color: Colors.white.withValues(alpha: 0.06),
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
