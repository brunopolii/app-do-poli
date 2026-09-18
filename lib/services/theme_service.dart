import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeSettings {
  final int backgroundColorValue;
  final String? imagePath;
  final double opacity;
  final double scale;
  final int cardColorValue;
  final double cardOpacity;
  final int cardBorderColorValue;
  final int navColorValue;
  final double navOpacity;
  final int accentColorValue;
  final double x;
  final double y;

  const ThemeSettings({
    this.backgroundColorValue = 0xFFF7F5FA,
    this.imagePath,
    this.opacity = 0.35,
    this.scale = 1.0,
    this.cardColorValue = 0xFFFFFFFF,
    this.cardOpacity = 0.90,
    this.cardBorderColorValue = 0xFF6750A4,
    this.navColorValue = 0xFFFFFFFF,
    this.navOpacity = 0.92,
    this.accentColorValue = 0xFF6750A4,
    this.x = 0.0,
    this.y = 0.0,
  });

  ThemeSettings copyWith({
    int? backgroundColorValue,
    String? imagePath,
    bool clearImagePath = false,
    double? opacity,
    double? scale,
    int? cardColorValue,
    double? cardOpacity,
    int? cardBorderColorValue,
    int? navColorValue,
    double? navOpacity,
    int? accentColorValue,
    double? x,
    double? y,
  }) {
    return ThemeSettings(
      backgroundColorValue: backgroundColorValue ?? this.backgroundColorValue,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      opacity: opacity ?? this.opacity,
      scale: scale ?? this.scale,
      cardColorValue: cardColorValue ?? this.cardColorValue,
      cardOpacity: cardOpacity ?? this.cardOpacity,
      cardBorderColorValue: cardBorderColorValue ?? this.cardBorderColorValue,
      navColorValue: navColorValue ?? this.navColorValue,
      navOpacity: navOpacity ?? this.navOpacity,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }
}

class ThemeService {
  static const _colorKey = 'theme_background_color';
  static const _imageKey = 'theme_background_image';
  static const _opacityKey = 'theme_background_opacity';
  static const _scaleKey = 'theme_background_scale';
  static const _cardColorKey = 'theme_card_color';
  static const _cardOpacityKey = 'theme_card_opacity';
  static const _cardBorderColorKey = 'theme_card_border_color';
  static const _navColorKey = 'theme_nav_color';
  static const _navOpacityKey = 'theme_nav_opacity';
  static const _accentColorKey = 'theme_accent_color';
  static const _xKey = 'theme_background_x';
  static const _yKey = 'theme_background_y';

  static Future<ThemeSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final image = prefs.getString(_imageKey);
    return ThemeSettings(
      backgroundColorValue: prefs.getInt(_colorKey) ?? 0xFFF7F5FA,
      imagePath: image != null && File(image).existsSync() ? image : null,
      opacity: ((prefs.getDouble(_opacityKey) ?? 0.35).clamp(0.05, 1.0)).toDouble(),
      scale: ((prefs.getDouble(_scaleKey) ?? 1.0).clamp(0.5, 3.0)).toDouble(),
      cardColorValue: prefs.getInt(_cardColorKey) ?? 0xFFFFFFFF,
      cardOpacity: ((prefs.getDouble(_cardOpacityKey) ?? 0.90).clamp(0.05, 1.0)).toDouble(),
      cardBorderColorValue: prefs.getInt(_cardBorderColorKey) ?? 0xFF6750A4,
      navColorValue: prefs.getInt(_navColorKey) ?? 0xFFFFFFFF,
      navOpacity: ((prefs.getDouble(_navOpacityKey) ?? 0.92).clamp(0.05, 1.0)).toDouble(),
      accentColorValue: prefs.getInt(_accentColorKey) ?? 0xFF6750A4,
      x: ((prefs.getDouble(_xKey) ?? 0.0).clamp(-5.0, 5.0)).toDouble(),
      y: ((prefs.getDouble(_yKey) ?? 0.0).clamp(-5.0, 5.0)).toDouble(),
    );
  }

  static Future<void> save(ThemeSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorKey, settings.backgroundColorValue);
    if (settings.imagePath == null) {
      await prefs.remove(_imageKey);
    } else {
      await prefs.setString(_imageKey, settings.imagePath!);
    }
    await prefs.setDouble(_opacityKey, settings.opacity);
    await prefs.setDouble(_scaleKey, settings.scale);
    await prefs.setInt(_cardColorKey, settings.cardColorValue);
    await prefs.setDouble(_cardOpacityKey, settings.cardOpacity);
    await prefs.setInt(_cardBorderColorKey, settings.cardBorderColorValue);
    await prefs.setInt(_navColorKey, settings.navColorValue);
    await prefs.setDouble(_navOpacityKey, settings.navOpacity);
    await prefs.setInt(_accentColorKey, settings.accentColorValue);
    await prefs.setDouble(_xKey, settings.x);
    await prefs.setDouble(_yKey, settings.y);
  }

  static Future<String?> pickAndPersistImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (picked == null) return null;

    final directory = await getApplicationDocumentsDirectory();
    final themeDirectory = Directory('${directory.path}/theme');
    if (!await themeDirectory.exists()) {
      await themeDirectory.create(recursive: true);
    }

    final extension = picked.path.contains('.')
        ? picked.path.substring(picked.path.lastIndexOf('.'))
        : '.jpg';
    final target = File(
      '${themeDirectory.path}/background${DateTime.now().millisecondsSinceEpoch}$extension',
    );
    await target.writeAsBytes(await picked.readAsBytes(), flush: true);
    return target.path;
  }
}
