import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeSettings {
  final int backgroundColorValue;
  final String? imagePath;
  final double opacity;
  final double scale;
  final double x;
  final double y;

  const ThemeSettings({
    this.backgroundColorValue = 0xFFF7F5FA,
    this.imagePath,
    this.opacity = 0.35,
    this.scale = 1.0,
    this.x = 0.0,
    this.y = 0.0,
  });

  ThemeSettings copyWith({
    int? backgroundColorValue,
    String? imagePath,
    bool clearImagePath = false,
    double? opacity,
    double? scale,
    double? x,
    double? y,
  }) {
    return ThemeSettings(
      backgroundColorValue: backgroundColorValue ?? this.backgroundColorValue,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      opacity: opacity ?? this.opacity,
      scale: scale ?? this.scale,
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
