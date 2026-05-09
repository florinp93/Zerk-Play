import 'package:flutter/material.dart';
import 'package:flutter_tv_media3/flutter_tv_media3.dart';

import 'subtitle_prefs.dart';

/// Matches desktop subtitle dialog baseline ([playback_page] `_showSubtitlesDialog`).
const double kTvSubtitleBaseFontSize = 75.0;

const double _kMinSizeFraction = 50.0 / 100.0;
const double _kMaxSizeFraction = 150.0 / 100.0;

double _colorDist(Color a, Color b) {
  final dr = ((a.r - b.r) * 255.0).round();
  final dg = ((a.g - b.g) * 255.0).round();
  final db = ((a.b - b.b) * 255.0).round();
  return (dr * dr + dg * dg + db * db).toDouble();
}

BasicColors _nearestBasic(Color c) {
  BasicColors best = BasicColors.white;
  var bestD = double.infinity;
  for (final e in BasicColors.values) {
    final d = _colorDist(c, e.color);
    if (d < bestD) {
      bestD = d;
      best = e;
    }
  }
  return best;
}

ExtendedColors _extendedBackgroundFromPrefs(SubtitlePrefs p) {
  if (!p.backgroundVisible) return ExtendedColors.transparent;
  final o = p.backgroundOpacity.clamp(0.0, 1.0);
  if (o < 0.2) return ExtendedColors.black25;
  if (o < 0.45) return ExtendedColors.black50;
  if (o < 0.7) return ExtendedColors.black75;
  return ExtendedColors.black100;
}

SubtitleStyle subtitleStyleFromPrefs(SubtitlePrefs p) {
  final fg = _nearestBasic(Color(p.color));
  final edgeCol = _nearestBasic(Color(p.borderColor));
  final edgeType =
      p.borderSize <= 0.5 ? SubtitleEdgeType.none : SubtitleEdgeType.outline;
  final frac = (p.fontSize / kTvSubtitleBaseFontSize)
      .clamp(_kMinSizeFraction, _kMaxSizeFraction);
  final bg = _extendedBackgroundFromPrefs(p);

  return SubtitleStyle(
    foregroundColor: fg,
    edgeColor: edgeCol,
    edgeType: edgeType,
    textSizeFraction: frac,
    bottomPadding: p.marginY.round().clamp(0, 240),
    applyEmbeddedStyles: true,
    backgroundColor: bg,
    windowColor: ExtendedColors.transparent,
  );
}

double _opacityFromExtended(ExtendedColors? c) {
  if (c == null || c == ExtendedColors.transparent) return 0.55;
  return switch (c) {
    ExtendedColors.black25 => 0.25,
    ExtendedColors.black50 => 0.5,
    ExtendedColors.black75 => 0.75,
    ExtendedColors.black100 => 1.0,
    _ => 0.55,
  };
}

SubtitlePrefs subtitlePrefsFromStyle(SubtitleStyle s) {
  final fg = s.foregroundColor ?? BasicColors.white;
  final ec = s.edgeColor ?? BasicColors.black;
  final edge = s.edgeType ?? SubtitleEdgeType.dropShadow;
  final borderSize = edge == SubtitleEdgeType.none ? 0.0 : 3.5;

  final fontSize = (s.textSizeFraction ?? 1.0) * kTvSubtitleBaseFontSize;

  final marginY = (s.bottomPadding ?? 45).toDouble();

  final bgEnum = s.backgroundColor;
  final visible = bgEnum != null && bgEnum != ExtendedColors.transparent;
  final opacity = visible ? _opacityFromExtended(bgEnum) : 0.55;

  return SubtitlePrefs(
    fontFamily: 'Roboto',
    fontSize: fontSize,
    color: fg.color.toARGB32(),
    borderSize: borderSize,
    borderColor: ec.color.toARGB32(),
    marginY: marginY,
    backgroundVisible: visible,
    backgroundOpacity: opacity.clamp(0.1, 0.9),
  );
}
