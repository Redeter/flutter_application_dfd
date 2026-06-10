/// Варианты «за сколько напомнить» для препаратов и записей на приём.
const List<String> kCalendarReminderOptions = [
  'За 5 мин',
  'За 15 мин',
  'За 1 час',
  'Не напоминать',
];

/// Смещение до события для push. `null` — только уведомление в момент приёма/визита.
Duration? calendarReminderEarlyOffset(String? reminder) {
  final r = reminder ?? kCalendarReminderOptions[0];
  switch (r) {
    case 'За 5 мин':
      return const Duration(minutes: 5);
    case 'За 15 мин':
      return const Duration(minutes: 15);
    case 'За 1 час':
      return const Duration(hours: 1);
    case 'За день':
      // Старые записи до обновления списка.
      return const Duration(days: 1);
    case 'Не напоминать':
    default:
      return null;
  }
}

/// Актуальное значение для выпадающего списка (старые «За день» → по умолчанию).
String normalizeCalendarReminder(String? reminder) {
  if (reminder != null && kCalendarReminderOptions.contains(reminder)) {
    return reminder;
  }
  return kCalendarReminderOptions[0];
}
