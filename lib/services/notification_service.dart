import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../constants/calendar_reminders.dart';
import '../models/calendar_entry.dart';
import 'calendar_storage.dart';

Duration? _earlyOffsetForReminder(String? reminder) {
  final r = reminder ?? kCalendarReminderOptions[0];
  switch (r) {
    case 'За 15 мин':
      return const Duration(minutes: 15);
    case 'За 1 час':
      return const Duration(hours: 1);
    case 'За день':
      return const Duration(days: 1);
    case 'Не напоминать':
    default:
      return null;
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _configureLocalTimeZone() async {
    if (kIsWeb) return;
    try {
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows) {
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
      }
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }
    tzdata.initializeTimeZones();
    await _configureLocalTimeZone();
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
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
  }

  Future<void> showTestNotification() async {
    if (kIsWeb) return;
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
    if (kIsWeb) return;
    await init();
    final when = DateTime.now().add(after);
    await _schedule(_stableId('snooze:${when.microsecondsSinceEpoch}'), when, title, body);
  }

  Future<void> rescheduleCalendarNotifications() async {
    if (kIsWeb) return;
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
          final amounts = e.schedule.isNotEmpty
              ? e.schedule.map((d) => d.amount).toList()
              : <String>[e.dosage.isEmpty ? '—' : e.dosage];
          for (var i = 0; i < times.length; i++) {
            if (i < e.skippedPerDose.length && e.skippedPerDose[i]) continue;
            if (i < e.takenAtPerDose.length && e.takenAtPerDose[i] != null) continue;
            final t = times[i];
            final amount = i < amounts.length ? amounts[i] : '—';
            final dt = DateTime(
              e.date.year,
              e.date.month,
              e.date.day,
              t.hour,
              t.minute,
            );
            if (!dt.isBefore(now)) {
              await _schedule(
                _stableId('${e.id}:med:$i:at'),
                dt,
                'Время принять препарат',
                '${e.name} — $amount',
              );
            }
            final early = _earlyOffsetForReminder(e.reminder);
            if (early != null) {
              final earlyAt = dt.subtract(early);
              if (!earlyAt.isBefore(now) && earlyAt.isBefore(dt)) {
                await _schedule(
                  _stableId('${e.id}:med:$i:early'),
                  earlyAt,
                  'Напоминание о приёме',
                  '${e.name} в ${_twoDigits(t.hour)}:${_twoDigits(t.minute)} — $amount',
                );
              }
            }
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
              _stableId('${e.id}:visit:at'),
              visit,
              'Запись на приём',
              e.title,
            );
          }
          final early = _earlyOffsetForReminder(e.reminder);
          if (early != null) {
            final earlyAt = visit.subtract(early);
            if (!earlyAt.isBefore(now) && earlyAt.isBefore(visit)) {
              await _schedule(
                _stableId('${e.id}:visit:early'),
                earlyAt,
                'Скоро приём',
                '${e.title} в ${_twoDigits(e.time.hour)}:${_twoDigits(e.time.minute)}',
              );
            }
          }
      }
    }
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

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
