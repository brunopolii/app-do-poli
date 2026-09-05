import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    // The app is intended for the user's local Brazilian time. Keeping the
    // timezone explicit avoids scheduling notifications in UTC on Android.
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(settings);

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      'lifetrack_agenda',
      'Agenda',
      description: 'Lembretes dos compromissos do App do Poli',
      importance: Importance.high,
    ));
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  static Future<void> schedule({
    required int id,
    required DateTime date,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();
    if (!date.isAfter(now)) return;

    final scheduled = tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute,
    );
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) return;

    await _plugin.cancel(id);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'lifetrack_agenda',
          'Agenda',
          channelDescription: 'Lembretes dos compromissos do App do Poli',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancel(int id) => _plugin.cancel(id);
}
