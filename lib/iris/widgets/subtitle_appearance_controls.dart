import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../player/subtitle_prefs.dart';

/// Shared subtitle **appearance** controls (size, background) for desktop dialog,
/// TV app settings, etc. Callers persist with [SubtitlePrefs.save] in [onChanged].
class SubtitleAppearanceControls extends StatelessWidget {
  const SubtitleAppearanceControls({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final SubtitlePrefs value;
  final ValueChanged<SubtitlePrefs> onChanged;

  static const double baseFontSize = 75.0;
  static const double minFontSizePct = 50.0;
  static const double maxFontSizePct = 150.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fontSizePct = ((value.fontSize / baseFontSize) * 100)
        .clamp(minFontSizePct, maxFontSizePct);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.subtitleSettingsTitle,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Text(l10n.fontSize)),
            Text(fontSizePct.toStringAsFixed(0)),
          ],
        ),
        Slider(
          min: minFontSizePct,
          max: maxFontSizePct,
          value: fontSizePct,
          onChanged: (v) {
            onChanged(value.copyWith(fontSize: baseFontSize * (v / 100)));
          },
        ),
        SwitchListTile(
          value: value.backgroundVisible,
          onChanged: (v) {
            onChanged(value.copyWith(backgroundVisible: v));
          },
          title: Text(l10n.background),
          contentPadding: EdgeInsets.zero,
        ),
        Row(
          children: [
            Expanded(child: Text(l10n.backgroundOpacity)),
            Text('${(value.backgroundOpacity * 100).round()}%'),
          ],
        ),
        Slider(
          min: 0.1,
          max: 0.9,
          value: value.backgroundOpacity.clamp(0.1, 0.9),
          onChanged: value.backgroundVisible
              ? (v) {
                  onChanged(value.copyWith(backgroundOpacity: v));
                }
              : null,
        ),
      ],
    );
  }
}
