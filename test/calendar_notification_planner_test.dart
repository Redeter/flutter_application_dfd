import 'package:flutter/material.dart';
import 'package:flutter_application_dfd/models/calendar_entry.dart';
import 'package:flutter_application_dfd/services/calendar_notification_planner.dart';
import 'package:flutter_test/flutter_test.dart';

Appointment _visit({
  required DateTime date,
  required TimeOfDay time,
  String reminder = 'За неделю',
  String id = 'appt-1',
}) {
  return Appointment(
    id: id,
    date: date,
    time: time,
    title: 'Терапевт',
    reminder: reminder,
  );
}

void main() {
  final now = DateTime(2026, 6, 4, 10, 0); // среда 10:00

  test('За неделю: ранний push и push в момент визита', () {
    final visitDay = now.add(const Duration(days: 10));
    final planned = planAppointmentNotifications(
      appointment: _visit(
        date: visitDay,
        time: const TimeOfDay(hour: 14, minute: 30),
        reminder: 'За неделю',
      ),
      now: now,
    );
    expect(planned.length, 2);
    expect(
      planned.any((p) => p.idKey.endsWith(':visit:early')),
      isTrue,
    );
    expect(
      planned.any((p) => p.idKey.endsWith(':visit:at')),
      isTrue,
    );
    final early = planned.firstWhere((p) => p.idKey.endsWith(':visit:early'));
    expect(early.when, visitDay.subtract(const Duration(days: 7)));
    expect(early.title, 'Напоминание о записи');
  });

  test('За день: ранний push за сутки', () {
    final visitDay = now.add(const Duration(days: 2));
    final planned = planAppointmentNotifications(
      appointment: _visit(
        date: visitDay,
        time: const TimeOfDay(hour: 9, minute: 0),
        reminder: 'За день',
      ),
      now: now,
    );
    final early = planned.firstWhere((p) => p.idKey.endsWith(':visit:early'));
    expect(early.when, visitDay.subtract(const Duration(days: 1)));
  });

  test('За 1 час: ранний push за час', () {
    final visitAt = now.add(const Duration(hours: 3));
    final planned = planAppointmentNotifications(
      appointment: _visit(
        date: visitAt,
        time: TimeOfDay(hour: visitAt.hour, minute: visitAt.minute),
        reminder: 'За 1 час',
      ),
      now: now,
    );
    final early = planned.firstWhere((p) => p.idKey.endsWith(':visit:early'));
    expect(early.when, visitAt.subtract(const Duration(hours: 1)));
  });

  test('Не напоминать: только push в момент визита', () {
    final visitDay = now.add(const Duration(days: 3));
    final planned = planAppointmentNotifications(
      appointment: _visit(
        date: visitDay,
        time: const TimeOfDay(hour: 12, minute: 0),
        reminder: 'Не напоминать',
      ),
      now: now,
    );
    expect(planned.length, 1);
    expect(planned.single.idKey, endsWith(':visit:at'));
  });

  test('визит через 60 дней с «За неделю» попадает в горизонт 90 дней', () {
    final visitDay = now.add(const Duration(days: 60));
    final planned = planAppointmentNotifications(
      appointment: _visit(
        date: visitDay,
        time: const TimeOfDay(hour: 11, minute: 0),
        reminder: 'За неделю',
      ),
      now: now,
    );
    expect(planned.length, 2);
    final early = planned.firstWhere((p) => p.idKey.endsWith(':visit:early'));
    expect(early.when.isAfter(now), isTrue);
  });

  test('визит в прошлом не планируется', () {
    final planned = planAppointmentNotifications(
      appointment: _visit(
        date: now.subtract(const Duration(days: 1)),
        time: const TimeOfDay(hour: 12, minute: 0),
      ),
      now: now,
    );
    expect(planned, isEmpty);
  });

  test('слишком рано для «За неделю» — только push в момент визита', () {
    final visitDay = now.add(const Duration(days: 3));
    final planned = planAppointmentNotifications(
      appointment: _visit(
        date: visitDay,
        time: const TimeOfDay(hour: 15, minute: 0),
        reminder: 'За неделю',
      ),
      now: now,
    );
    expect(planned.length, 1);
    expect(planned.single.idKey, endsWith(':visit:at'));
  });
}
