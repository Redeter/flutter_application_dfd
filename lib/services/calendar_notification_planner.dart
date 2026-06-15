import '../constants/calendar_reminders.dart';
import '../models/calendar_entry.dart';

/// Горизонт планирования push для визитов (дольше, чем у препаратов).
const int kAppointmentNotificationHorizonDays = 90;

class PlannedCalendarNotification {
  const PlannedCalendarNotification({
    required this.idKey,
    required this.when,
    required this.title,
    required this.body,
  });

  final String idKey;
  final DateTime when;
  final String title;
  final String body;
}

int stableCalendarNotificationId(String input) {
  var hash = 17;
  for (final code in input.codeUnits) {
    hash = 37 * hash + code;
  }
  return hash.abs() % 2000000000;
}

String formatClockHm(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// Планируемые локальные push для [Appointment].
List<PlannedCalendarNotification> planAppointmentNotifications({
  required Appointment appointment,
  required DateTime now,
  DateTime? horizon,
}) {
  final limit = horizon ??
      now.add(const Duration(days: kAppointmentNotificationHorizonDays));

  void addIfFuture(
    List<PlannedCalendarNotification> out, {
    required String idKey,
    required DateTime when,
    required String title,
    required String body,
  }) {
    if (when.isBefore(now) || when.isAfter(limit)) return;
    out.add(
      PlannedCalendarNotification(
        idKey: idKey,
        when: when,
        title: title,
        body: body,
      ),
    );
  }

  final reminder = appointment.reminder;
  final skipEarly = reminder == 'Не напоминать';

  final visit = DateTime(
    appointment.date.year,
    appointment.date.month,
    appointment.date.day,
    appointment.time.hour,
    appointment.time.minute,
  );
  final clock = formatClockHm(appointment.time.hour, appointment.time.minute);
  final out = <PlannedCalendarNotification>[];

  addIfFuture(
    out,
    idKey: '${appointment.id}:visit:at',
    when: visit,
    title: 'Запись на приём',
    body: appointment.title,
  );

  final early = skipEarly ? null : calendarAppointmentReminderEarlyOffset(reminder);
  if (early != null) {
    final earlyAt = visit.subtract(early);
    if (!earlyAt.isBefore(now) && earlyAt.isBefore(visit)) {
      final (earlyTitle, earlyBody) = switch (reminder) {
        'За неделю' => (
            'Напоминание о записи',
            '${appointment.title} через неделю ($clock)',
          ),
        'За день' => (
            'Напоминание о записи',
            '${appointment.title} завтра в $clock',
          ),
        'За 1 час' => (
            'Скоро приём',
            '${appointment.title} в $clock',
          ),
        _ => (
            'Скоро приём',
            '${appointment.title} в $clock',
          ),
      };
      addIfFuture(
        out,
        idKey: '${appointment.id}:visit:early',
        when: earlyAt,
        title: earlyTitle,
        body: earlyBody,
      );
    }
  }

  return out;
}
