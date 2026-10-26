import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Experimental, on-device funnel counters. These are test signals only:
/// they are not global analytics and are not sent to a server.
class ExperimentalMetricsService {
  static const _eventsKey = 'poliroutines_experimental_metrics_v1';
  static const _firstLaunchKey = 'poliroutines_experimental_first_launch_v1';

  Future<void> record(String event, {Map<String, Object?> details = const {}}) async {
    final prefs = await SharedPreferences.getInstance();
    final events = prefs.getStringList(_eventsKey) ?? <String>[];
    events.add(jsonEncode({
      'event': event,
      'at': DateTime.now().toUtc().toIso8601String(),
      'details': details,
    }));
    await prefs.setStringList(_eventsKey, events);
  }

  Future<void> recordFirstLaunchIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_firstLaunchKey) ?? false) return;
    await record('install_first_open');
    await prefs.setBool(_firstLaunchKey, true);
  }

  Future<Map<String, int>> summary() async {
    final prefs = await SharedPreferences.getInstance();
    final events = prefs.getStringList(_eventsKey) ?? <String>[];
    final counts = <String, int>{
      'install_first_open': 0,
      'premium_screen_view': 0,
      'plan_selected': 0,
      'purchase_intent': 0,
      'license_activation_success': 0,
      'license_activation_failure': 0,
    };
    for (final raw in events) {
      try {
        final event = jsonDecode(raw);
        if (event is Map<String, dynamic>) {
          final name = event['event']?.toString();
          if (name != null) counts[name] = (counts[name] ?? 0) + 1;
        }
      } catch (_) {
        // Ignore malformed legacy test entries.
      }
    }
    return counts;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_eventsKey);
    await prefs.remove(_firstLaunchKey);
  }
}
