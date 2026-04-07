import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../player/playback_prefs.dart';
import '../settings/app_prefs.dart';

final class PreferencesForm extends StatelessWidget {
  const PreferencesForm({
    super.key,
    required this.appLanguage,
    required this.onAppLanguageChanged,
    required this.showFeedbackButton,
    required this.onShowFeedbackButtonChanged,
    required this.quality,
    required this.onQualityChanged,
    required this.audioLang,
    required this.onAudioLangChanged,
    required this.subtitleSelection,
    required this.onSubtitleSelectionChanged,
  });

  final AppLanguage appLanguage;
  final ValueChanged<AppLanguage> onAppLanguageChanged;

  final bool showFeedbackButton;
  final ValueChanged<bool> onShowFeedbackButtonChanged;

  final PlaybackQualityPreference quality;
  final ValueChanged<PlaybackQualityPreference> onQualityChanged;

  final String audioLang;
  final ValueChanged<String> onAudioLangChanged;

  final String subtitleSelection;
  final ValueChanged<String> onSubtitleSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<AppLanguage>(
          initialValue: appLanguage,
          decoration: InputDecoration(labelText: l10n.appLanguage),
          items: [
            DropdownMenuItem(
              value: AppLanguage.system,
              child: Text(l10n.languageSystem),
            ),
            DropdownMenuItem(
              value: AppLanguage.en,
              child: Text(l10n.languageEnglish),
            ),
            DropdownMenuItem(
              value: AppLanguage.ro,
              child: Text(l10n.languageRomanian),
            ),
          ],
          onChanged: (v) {
            if (v == null) return;
            onAppLanguageChanged(v);
          },
        ),
        SwitchListTile(
          value: showFeedbackButton,
          onChanged: onShowFeedbackButtonChanged,
          title: const Text('Show feedback button'),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<PlaybackQualityPreference>(
          initialValue: quality,
          decoration: InputDecoration(labelText: l10n.qualityPreference),
          items: [
            DropdownMenuItem(
              value: PlaybackQualityPreference.auto,
              child: Text(l10n.qualityAuto),
            ),
            DropdownMenuItem(
              value: PlaybackQualityPreference.p2160,
              child: Text(l10n.quality4k),
            ),
            DropdownMenuItem(
              value: PlaybackQualityPreference.p1080,
              child: Text(l10n.quality1080p),
            ),
            DropdownMenuItem(
              value: PlaybackQualityPreference.p720,
              child: Text(l10n.quality720p),
            ),
          ],
          onChanged: (v) {
            if (v == null) return;
            onQualityChanged(v);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: audioLang,
          decoration: InputDecoration(labelText: l10n.audio),
          items: [
            DropdownMenuItem(value: 'auto', child: Text(l10n.auto)),
            DropdownMenuItem(value: 'en', child: Text(l10n.languageEnglish)),
            DropdownMenuItem(value: 'ro', child: Text(l10n.languageRomanian)),
          ],
          onChanged: (v) {
            if (v == null) return;
            onAudioLangChanged(v);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: subtitleSelection,
          decoration: InputDecoration(labelText: l10n.subtitles),
          items: [
            DropdownMenuItem(value: 'off', child: Text(l10n.off)),
            DropdownMenuItem(value: 'auto', child: Text(l10n.auto)),
            DropdownMenuItem(value: 'en', child: Text(l10n.languageEnglish)),
            DropdownMenuItem(value: 'ro', child: Text(l10n.languageRomanian)),
          ],
          onChanged: (v) {
            if (v == null) return;
            onSubtitleSelectionChanged(v);
          },
        ),
      ],
    );
  }
}
