import 'package:shared_preferences/shared_preferences.dart';

final class SubtitlePrefs {
  const SubtitlePrefs({
    required this.fontFamily,
    required this.fontSize,
    required this.color,
    required this.borderSize,
    required this.borderColor,
    required this.marginY,
    required this.backgroundVisible,
    required this.backgroundOpacity,
  });

  final String fontFamily;
  final double fontSize;
  final int color;
  final double borderSize;
  final int borderColor;
  final double marginY;
  final bool backgroundVisible;
  final double backgroundOpacity;

  SubtitlePrefs copyWith({
    String? fontFamily,
    double? fontSize,
    int? color,
    double? borderSize,
    int? borderColor,
    double? marginY,
    bool? backgroundVisible,
    double? backgroundOpacity,
  }) {
    return SubtitlePrefs(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      borderSize: borderSize ?? this.borderSize,
      borderColor: borderColor ?? this.borderColor,
      marginY: marginY ?? this.marginY,
      backgroundVisible: backgroundVisible ?? this.backgroundVisible,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
    );
  }

  static const _kFontFamily = 'subtitle_font_family';
  static const _kFontSize = 'subtitle_font_size';
  static const _kColor = 'subtitle_color';
  static const _kBorderSize = 'subtitle_border_size';
  static const _kBorderColor = 'subtitle_border_color';
  static const _kMarginY = 'subtitle_margin_y';
  static const _kBgVisible = 'subtitle_bg_visible';
  static const _kBgOpacity = 'subtitle_bg_opacity';

  static const defaults = SubtitlePrefs(
    fontFamily: 'Roboto',
    fontSize: 75,
    color: 0xFFFFFFFF,
    borderSize: 3.5,
    borderColor: 0xFF000000,
    marginY: 45,
    backgroundVisible: false,
    backgroundOpacity: 0.55,
  );

  static Future<SubtitlePrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    final family = prefs.getString(_kFontFamily);
    final size = prefs.getDouble(_kFontSize);
    final color = prefs.getInt(_kColor);
    final borderSize = prefs.getDouble(_kBorderSize);
    final borderColor = prefs.getInt(_kBorderColor);
    final marginY = prefs.getDouble(_kMarginY);
    final visible = prefs.getBool(_kBgVisible);
    final opacity = prefs.getDouble(_kBgOpacity);
    return SubtitlePrefs(
      fontFamily: family ?? defaults.fontFamily,
      fontSize: size ?? defaults.fontSize,
      color: color ?? defaults.color,
      borderSize: borderSize ?? defaults.borderSize,
      borderColor: borderColor ?? defaults.borderColor,
      marginY: marginY ?? defaults.marginY,
      backgroundVisible: visible ?? defaults.backgroundVisible,
      backgroundOpacity: opacity ?? defaults.backgroundOpacity,
    );
  }

  static Future<void> save(SubtitlePrefs value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFontFamily, value.fontFamily);
    await prefs.setDouble(_kFontSize, value.fontSize);
    await prefs.setInt(_kColor, value.color);
    await prefs.setDouble(_kBorderSize, value.borderSize);
    await prefs.setInt(_kBorderColor, value.borderColor);
    await prefs.setDouble(_kMarginY, value.marginY);
    await prefs.setBool(_kBgVisible, value.backgroundVisible);
    await prefs.setDouble(_kBgOpacity, value.backgroundOpacity);
  }

  static Future<void> reset() async {
    await save(defaults);
  }
}

