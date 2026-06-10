import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../constants/calendar_reminders.dart';
import '../models/calendar_entry.dart';
import 'auth_service.dart';
import 'calendar_storage.dart';
import 'foundation_service.dart';


class _PendingNotification {
  const _PendingNotification({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
  });

  final int id;
  final DateTime when;
  final String title;
  final String body;
}



class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  static const int _kAndroidAlarmSoftLimit = 450;
  static const int _kScheduleHorizonDays = 45;
  static const int _kFoundationQuestEveningReminderId = 888777;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// После входа или изменения календаря — пересобрать локальные напоминания.
  Future<void> bootstrapRemindersForActiveSession() async {
    if (kIsWeb) return;
    await init();
    if (await AuthService.instance.sessionUserId() == null) return;
    await rescheduleCalendarNotifications();
  }

  Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    if (kIsWeb || !Platform.isAndroid) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final canExact = await android?.canScheduleExactNotifications();
    if (canExact == true) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

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
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    // Явно создаём канал до zonedSchedule — на части прошивок иначе будильники не показываются.
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'health_reminders',
        'Health reminders',
        description: 'Medication and appointments reminders',
        importance: Importance.high,
      ),
    );
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
    final sessionUserId = await AuthService.instance.sessionUserId();
    if (sessionUserId == null || sessionUserId.isEmpty) {
      // Без сессии не трогаем уже запланированные будильники.
      return;
    }

    final entries = await CalendarStorage.instance.loadAll();
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: _kScheduleHorizonDays));
    final pending = _collectPendingNotifications(
      entries: entries,
      now: now,
      horizon: horizon,
    );
    pending.sort((a, b) => a.when.compareTo(b.when));

    final maxCalendarSlots = Platform.isAndroid
        ? _kAndroidAlarmSoftLimit - 1
        : pending.length;
    final toSchedule = pending.take(maxCalendarSlots).toList();

    await _plugin.cancelAll();
    final androidMode = await _resolveAndroidScheduleMode();
    for (final item in toSchedule) {
      try {
        await _schedule(
          item.id,
          item.when,
          item.title,
          item.body,
          androidMode: androidMode,
        );
      } catch (_) {
        // Единичная ошибка alarm manager не должна срывать всю пересборку.
      }
    }
    await scheduleFoundationQuestEveningReminderIfNeeded();
  }

  List<_PendingNotification> _collectPendingNotifications({
    required List<CalendarEntry> entries,
    required DateTime now,
    required DateTime horizon,
  }) {
    final out = <_PendingNotification>[];

    void addIfValid({
      required String idKey,
      required DateTime when,
      required String title,
      required String body,
    }) {
      if (when.isBefore(now) || when.isAfter(horizon)) return;
      out.add(
        _PendingNotification(
          id: _stableId(idKey),
          when: when,
          title: title,
          body: body,
        ),
      );
    }

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
            if (i < e.takenAtPerDose.length && e.takenAtPerDose[i] != null) {
              continue;
            }
            final t = times[i];
            final amount = i < amounts.length ? amounts[i] : '—';
            final dt = DateTime(
              e.date.year,
              e.date.month,
              e.date.day,
              t.hour,
              t.minute,
            );
            addIfValid(
              idKey: '${e.id}:med:$i:at',
              when: dt,
              title: 'Время принять препарат',
              body: '${e.name} — $amount',
            );
            final early = calendarReminderEarlyOffset(e.reminder);
            if (early != null) {
              final earlyAt = dt.subtract(early);
              if (!earlyAt.isBefore(now) && earlyAt.isBefore(dt)) {
                addIfValid(
                  idKey: '${e.id}:med:$i:early',
                  when: earlyAt,
                  title: 'Напоминание о приёме',
                  body:
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
          addIfValid(
            idKey: '${e.id}:visit:at',
            when: visit,
            title: 'Запись на приём',
            body: e.title,
          );
          final early = calendarReminderEarlyOffset(e.reminder);
          if (early != null) {
            final earlyAt = visit.subtract(early);
            if (!earlyAt.isBefore(now) && earlyAt.isBefore(visit)) {
              addIfValid(
                idKey: '${e.id}:visit:early',
                when: earlyAt,
                title: 'Скоро приём',
                body:
                    '${e.title} в ${_twoDigits(e.time.hour)}:${_twoDigits(e.time.minute)}',
              );
            }
          }
      }
    }
    return out;
  }

  /// Ежедневное локальное напоминание заглянуть в «Цели» (если включено в профиле).
  Future<void> scheduleFoundationQuestEveningReminderIfNeeded() async {
    if (kIsWeb) return;
    await init();
    await _plugin.cancel(_kFoundationQuestEveningReminderId);
    final sessionUserId = await AuthService.instance.sessionUserId();
    if (sessionUserId == null || sessionUserId.isEmpty) return;

    final enabled = await FoundationService.instance.isQuestEveningReminderEnabled();
    if (!enabled) return;

    final (hour, minute) =
        await FoundationService.instance.getQuestEveningReminderClock();
    final scheduled = _nextTzInstanceOfClock(hour, minute);
    final androidMode = await _resolveAndroidScheduleMode();
    try {
      await _plugin.zonedSchedule(
        _kFoundationQuestEveningReminderId,
        'Шаг дня в «Цели»',
        'Успели отметить выполнение шага? Откройте вкладку Цели.',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'foundation_quest',
            'Цели — шаг дня',
            channelDescription: 'Вечернее напоминание об отметке шага',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: androidMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      if (androidMode == AndroidScheduleMode.exactAllowWhileIdle) {
        try {
          await _plugin.zonedSchedule(
            _kFoundationQuestEveningReminderId,
            'Шаг дня в «Цели»',
            'Успели отметить выполнение шага? Откройте вкладку Цели.',
            scheduled,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'foundation_quest',
                'Цели — шаг дня',
                channelDescription: 'Вечернее напоминание об отметке шага',
                importance: Importance.defaultImportance,
                priority: Priority.defaultPriority,
              ),
              iOS: DarwinNotificationDetails(),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
          );
        } catch (_) {}
      }
    }
  }

  tz.TZDateTime _nextTzInstanceOfClock(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  Future<void> _schedule(
    int id,
    DateTime when,
    String title,
    String body, {
    AndroidScheduleMode? androidMode,
  }) async {
    final mode = androidMode ?? await _resolveAndroidScheduleMode();
    final details = const NotificationDetails(
      android: AndroidNotificationDetails(
        'health_reminders',
        'Health reminders',
        channelDescription: 'Medication and appointments reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    final whenTz = tz.TZDateTime.from(when, tz.local);
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        whenTz,
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      if (mode != AndroidScheduleMode.exactAllowWhileIdle) rethrow;
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        whenTz,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  int _stableId(String input) {
    var hash = 17;
    for (final code in input.codeUnits) {
      hash = 37 * hash + code;
    }
    return hash.abs() % 2000000000;
  }
}
