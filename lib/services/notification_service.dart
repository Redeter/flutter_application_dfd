import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/calendar_entry.dart';
import 'calendar_storage.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
  }

  Future<void> showTestNotification() async {
    await init();
    await _plugin.show(
      999001,
      'Тест пуша',
      'Уведомления работают корректно.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'health_test',
          'Health test',
          channelDescription: 'Test notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> scheduleSnooze({
    required String title,
    required String body,
    Duration after = const Duration(minutes: 30),
  }) async {
    await init();
    final when = DateTime.now().add(after);
    await _schedule(_stableId('snooze:${when.microsecondsSinceEpoch}'), when, title, body);
  }

  Future<void> rescheduleCalendarNotifications() async {
    await init();
    await _plugin.cancelAll();
    final entries = await CalendarStorage.instance.loadAll();
    final now = DateTime.now();
    for (final e in entries) {
      switch (e) {
        case Medication():
          final times = e.schedule.isNotEmpty
              ? e.schedule.map((d) => d.time).toList()
              : [e.time];
          for (var i = 0; i < times.length; i++) {
            final dt = DateTime(
              e.date.year,
              e.date.month,
              e.date.day,
              times[i].hour,
              times[i].minute,
            );
            if (dt.isBefore(now)) continue;
            await _schedule(
              _stableId('${e.id}:med:$i'),
              dt,
              'Прием препарата',
              '${e.name} ${e.dosage}',
            );
          }
        case Appointment():
          final visit = DateTime(
            e.date.year,
            e.date.month,
            e.date.day,
            e.time.hour,
            e.time.minute,
          );
          if (!visit.isBefore(now)) {
            await _schedule(
              _stableId('${e.id}:visit'),
              visit,
              'Напоминание о приеме',
              e.title,
            );
          }
          final twoHoursBefore = visit.subtract(const Duration(hours: 2));
          if (!twoHoursBefore.isBefore(now)) {
            await _schedule(
              _stableId('${e.id}:visit:2h'),
              twoHoursBefore,
              'Прием скоро',
              'Через 2 часа: ${e.title}',
            );
          }
      }
    }
  }

  Future<void> _schedule(int id, DateTime when, String title, String body) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'health_reminders',
          'Health reminders',
          channelDescription: 'Medication and appointments reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  int _stableId(String input) {
    var hash = 17;
    for (final code in input.codeUnits) {
      hash = 37 * hash + code;
    }
    return hash.abs() % 2000000000;
  }
}
