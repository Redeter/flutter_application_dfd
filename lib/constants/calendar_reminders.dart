/// Варианты «за сколько напомнить» для **препаратов**.
const List<String> kCalendarReminderOptions = [
  'За 5 мин',
  'За 15 мин',
  'За 1 час',
  'Не напоминать',
];

/// Варианты «за сколько напомнить» для **записи ко врачу**.
const List<String> kAppointmentReminderOptions = [
  'За неделю',
  'За день',
  'За 1 час',
  'Не напоминать',
];

/// Смещение до приёма препарата. `null` — только push в момент приёма.
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
      // Старые записи препаратов до смены списка.
      return const Duration(days: 1);
    case 'Не напоминать':
    default:
      return null;
  }
}

/// Смещение до визита к врачу. `null` — только push в момент визита.
Duration? calendarAppointmentReminderEarlyOffset(String? reminder) {
  final r = reminder ?? kAppointmentReminderOptions[0];
  switch (r) {
    case 'За неделю':
      return const Duration(days: 7);
    case 'За день':
      return const Duration(days: 1);
    case 'За 1 час':
      return const Duration(hours: 1);
    case 'За 5 мин':
      // Старые визиты: слот «5 мин» в UI заменён на «за неделю».
      return const Duration(days: 7);
    case 'За 15 мин':
      // Старые визиты: слот «15 мин» в UI заменён на «за день».
      return const Duration(days: 1);
    case 'Не напоминать':
    default:
      return null;
  }
}

/// Актуальное значение для выпадающего списка препаратов.
String normalizeCalendarReminder(String? reminder) {
  if (reminder != null && kCalendarReminderOptions.contains(reminder)) {
    return reminder;
  }
  return kCalendarReminderOptions[0];
}

/// Актуальное значение для выпадающего списка визита к врачу.
String normalizeAppointmentReminder(String? reminder) {
  if (reminder != null && kAppointmentReminderOptions.contains(reminder)) {
    return reminder;
  }
  return switch (reminder) {
    'За 5 мин' => 'За неделю',
    'За 15 мин' => 'За день',
    _ => kAppointmentReminderOptions[0],
  };
}
