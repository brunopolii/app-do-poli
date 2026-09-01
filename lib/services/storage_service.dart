
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static Future<List<Map<String, dynamic>>> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(key) ?? <String>[];
    return values
        .map((value) => Map<String, dynamic>.from(jsonDecode(value) as Map))
        .toList();
  }

  static Future<void> write(
    String key,
    List<Map<String, dynamic>> values,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      key,
      values.map((value) => jsonEncode(value)).toList(),
    );
  }
}
