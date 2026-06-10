import 'package:flutter_application_dfd/constants/calendar_reminders.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calendarReminderEarlyOffset', () {
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

    test('legacy За день still works for old entries', () {
      expect(
        calendarReminderEarlyOffset('За день'),
        const Duration(days: 1),
      );
    });
  });

  group('kCalendarReminderOptions', () {
    test('contains За 5 мин, not За день', () {
      expect(kCalendarReminderOptions, contains('За 5 мин'));
      expect(kCalendarReminderOptions, isNot(contains('За день')));
    });
  });
}
