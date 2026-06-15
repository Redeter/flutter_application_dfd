import 'package:flutter_application_dfd/constants/calendar_reminders.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calendarReminderEarlyOffset (препараты)', () {
    test('За 5 мин → 5 minutes', () {
      expect(
        calendarReminderEarlyOffset('За 5 мин'),
        const Duration(minutes: 5),
      );
    });

    test('default (null) → 5 minutes (first option)', () {
      expect(
        calendarReminderEarlyOffset(null),
        const Duration(minutes: 5),
      );
    });

    test('Не напоминать → null', () {
      expect(calendarReminderEarlyOffset('Не напоминать'), isNull);
    });
  });

  group('calendarAppointmentReminderEarlyOffset (визит к врачу)', () {
    test('За неделю → 7 days', () {
      expect(
        calendarAppointmentReminderEarlyOffset('За неделю'),
        const Duration(days: 7),
      );
    });

    test('За день → 1 day', () {
      expect(
        calendarAppointmentReminderEarlyOffset('За день'),
        const Duration(days: 1),
      );
    });

    test('За 1 час → 1 hour', () {
      expect(
        calendarAppointmentReminderEarlyOffset('За 1 час'),
        const Duration(hours: 1),
      );
    });

    test('legacy За 5 мин → неделя', () {
      expect(
        calendarAppointmentReminderEarlyOffset('За 5 мин'),
        const Duration(days: 7),
      );
    });

    test('legacy За 15 мин → день', () {
      expect(
        calendarAppointmentReminderEarlyOffset('За 15 мин'),
        const Duration(days: 1),
      );
    });
  });

  group('kCalendarReminderOptions', () {
    test('препараты: 5 мин и 15 мин, без недели', () {
      expect(kCalendarReminderOptions, contains('За 5 мин'));
      expect(kCalendarReminderOptions, contains('За 15 мин'));
      expect(kCalendarReminderOptions, isNot(contains('За неделю')));
    });
  });

  group('kAppointmentReminderOptions', () {
    test('визиты: неделя и день, без 5 мин', () {
      expect(kAppointmentReminderOptions, contains('За неделю'));
      expect(kAppointmentReminderOptions, contains('За день'));
      expect(kAppointmentReminderOptions, isNot(contains('За 5 мин')));
    });
  });

  group('normalizeAppointmentReminder', () {
    test('legacy За 5 мин → За неделю', () {
      expect(normalizeAppointmentReminder('За 5 мин'), 'За неделю');
    });

    test('legacy За 15 мин → За день', () {
      expect(normalizeAppointmentReminder('За 15 мин'), 'За день');
    });
  });
}
