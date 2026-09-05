import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const String _channelId = 'app_do_poli_agenda';

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Agenda',
        description: 'Lembretes dos compromissos do App do Poli',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  static Future<bool> notificationsEnabled() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? true;
  }

  static Future<bool> exactAlarmsEnabled() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? false;
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

    final details = const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Agenda',
        channelDescription: 'Lembretes dos compromissos do App do Poli',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        ticker: 'Lembrete da Agenda',
      ),
    );

    // Android 14+ may deny exact alarms. In that case, use the inexact
    // scheduler instead of silently failing to schedule the notification.
    final exact = await exactAlarmsEnabled();
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> testNow() async {
    await _plugin.show(
      2147483000,
      'App do Poli',
      'As notificações da Agenda estão funcionando.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Agenda',
          channelDescription: 'Lembretes dos compromissos do App do Poli',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
        ),
      ),
    );
  }

  static Future<void> cancel(int id) => _plugin.cancel(id);
}
