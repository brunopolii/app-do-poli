import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static Future<List<Map<String, dynamic>>> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(key) ?? <String>[];
    final result = <Map<String, dynamic>>[];
    for (final value in values) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) result.add(Map<String, dynamic>.from(decoded));
      } catch (_) {
        // Ignore a corrupted item instead of preventing the whole screen from loading.
      }
    }
    return result;
  }

  static Future<void> write(String key, List<Map<String, dynamic>> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, values.map(jsonEncode).toList());
  }
}
