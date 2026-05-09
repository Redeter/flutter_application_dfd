import 'package:flutter/material.dart';

import '../models/aggregated_data.dart';
import '../models/calendar_entry.dart';
import '../models/state_entries.dart';

/// Ключ одной схемы приёма для календарной статистики по режимам:
/// [seriesId] при многодневной серии, иначе имя+дозировка.
String medicationRegimenKey(Medication m) {
  final sid = m.seriesId;
  if (sid != null && sid.isNotEmpty) return sid;
  return '${m.name.toLowerCase()}|${m.dosage}';
}

/// Сколько разных препаратов/схем в списке (не число строк календаря по дням).
int countDistinctMedicationRegimens(Iterable<Medication> meds) {
  final seen = <String>{};
  for (final m in meds) {
    seen.add(medicationRegimenKey(m));
  }
  return seen.length;
}

/// Разные схемы, у которых есть хотя бы один день приёма не раньше [today] (как список в профиле).
int countDistinctActiveMedicationRegimens(AggregatedData data, DateTime today) {
  final d0 = _calendarDay(today);
  final seen = <String>{};
  for (final m in data.medications) {
    final md = _calendarDay(m.date);
    if (md.isBefore(d0)) continue;
    seen.add(medicationRegimenKey(m));
  }
  return seen.length;
}

/// Нормализованное название: одно уникальное имя = один препарат в счётчиках профиля и статистики.
String medicationUniqueNameKey(Medication m) => m.name.trim().toLowerCase();

/// Уникальные названия препаратов с хотя бы одним днём приёма не раньше [today]
/// (совпадает с числом строк «Принимаемые препараты» в профиле).
int countDistinctActiveMedicationNames(Iterable<Medication> medications, DateTime today) {
  final d0 = _calendarDay(today);
  final seen = <String>{};
  for (final m in medications) {
    final md = _calendarDay(m.date);
    if (md.isBefore(d0)) continue;
    final key = medicationUniqueNameKey(m);
    if (key.isEmpty) continue;
    seen.add(key);
  }
  return seen.length;
}

DateTime _calendarDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Заметки с датой [day] (локальный календарный день).
int countNotesOnCalendarDay(AggregatedData data, DateTime day) {
  final d0 = _calendarDay(day);
  var n = 0;
  for (final note in data.notes) {
    if (_calendarDay(note.date) == d0) n++;
  }
  return n;
}

/// Запланированные слоты приёма на календарный день [day] (по расписанию препаратов).
int countMedicationDosesOnCalendarDay(AggregatedData data, DateTime day) {
  final d0 = _calendarDay(day);
  var n = 0;
  for (final m in data.medications) {
    if (_calendarDay(m.date) != d0) continue;
    if (m.schedule.isEmpty) {
      n += 1;
    } else {
      n += m.schedule.length;
    }
  }
  return n;
}

/// Ближайший приём не раньше [now] по всем записям календаря препаратов.
DateTime? nextMedicationIntakeOnOrAfter(AggregatedData data, DateTime now) {
  DateTime? best;
  for (final m in data.medications) {
    final base = _calendarDay(m.date);
    final times = m.schedule.isEmpty
        ? <TimeOfDay>[m.time]
        : [for (final dose in m.schedule) dose.time];
    for (final t in times) {
      final dt = DateTime(base.year, base.month, base.day, t.hour, t.minute);
      if (dt.isBefore(now)) continue;
      if (best == null || dt.isBefore(best)) best = dt;
    }
  }
  return best;
}

/// Визиты с датой [day] (календарный день записи).
int countAppointmentsOnCalendarDay(AggregatedData data, DateTime day) {
  final d0 = _calendarDay(day);
  var n = 0;
  for (final a in data.appointments) {
    if (_calendarDay(a.date) == d0) n++;
  }
  return n;
}

/// Разные схемы препаратов, у которых есть строка календаря в день [day].
int countDistinctMedicationRegimensOnDay(AggregatedData data, DateTime day) {
  final d0 = _calendarDay(day);
  final seen = <String>{};
  for (final m in data.medications) {
    if (_calendarDay(m.date) != d0) continue;
    seen.add(medicationRegimenKey(m));
  }
  return seen.length;
}

/// Ближайший визит к врачу не раньше [now].
DateTime? nextAppointmentVisitOnOrAfter(AggregatedData data, DateTime now) {
  DateTime? best;
  for (final a in data.appointments) {
    final dt = DateTime(
      a.date.year,
      a.date.month,
      a.date.day,
      a.time.hour,
      a.time.minute,
    );
    if (dt.isBefore(now)) continue;
    if (best == null || dt.isBefore(best)) best = dt;
  }
  return best;
}

/// Локальная статистика за выбранный период (без ИИ).
class LocalStats {
  const LocalStats({
    this.avgMood,
    this.moodCount = 0,
    this.avgSleep,
    this.sleepCount = 0,
    this.avgEnergy,
    this.energyCount = 0,
    this.notesCount = 0,
    this.medicationsCount = 0,
    this.appointmentsCount = 0,
  });

  final double? avgMood;
  final int moodCount;
  final double? avgSleep;
  final int sleepCount;
  final double? avgEnergy;
  final int energyCount;
  final int notesCount;
  final int medicationsCount;
  final int appointmentsCount;

  bool get hasAny =>
      avgMood != null ||
      avgSleep != null ||
      avgEnergy != null ||
      notesCount > 0 ||
      medicationsCount > 0 ||
      appointmentsCount > 0;
}

/// Вычисляет локальную статистику из агрегированных данных за период.
LocalStats computeLocalStats(
  AggregatedData data, {
  required DateTime start,
  required DateTime end,
}) {
  final startDay = DateTime(start.year, start.month, start.day);
  final endDay = DateTime(end.year, end.month, end.day);

  double? avgMood;
  int moodCount = 0;
  double moodSum = 0;

  double? avgSleep;
  int sleepCount = 0;
  double sleepSum = 0;

  double? avgEnergy;
  int energyCount = 0;
  double energySum = 0;

  for (final e in data.stateEntries) {
    final day = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
    if (day.isBefore(startDay) || day.isAfter(endDay)) continue;

    switch (e) {
      case MoodEntry(:final value):
        moodSum += value;
        moodCount++;
      case SleepEntry(:final quality):
        sleepSum += quality;
        sleepCount++;
      case EnergyEntry(:final level):
        energySum += level;
        energyCount++;
      default:
        break;
    }
  }

  if (moodCount > 0) avgMood = moodSum / moodCount;
  if (sleepCount > 0) avgSleep = sleepSum / sleepCount;
  if (energyCount > 0) avgEnergy = energySum / energyCount;

  int notesInRange = 0;
  for (final n in data.notes) {
    final day = DateTime(n.date.year, n.date.month, n.date.day);
    if (!day.isBefore(startDay) && !day.isAfter(endDay)) notesInRange++;
  }

  /// Одна добавленная схема хранится как много строк (по дням) с одним [Medication.seriesId].
  /// В сводке считаем разные схемы в периоде, а не строки календаря.
  final medsInPeriodKeys = <String>{};
  for (final m in data.medications) {
    final day = DateTime(m.date.year, m.date.month, m.date.day);
    if (day.isBefore(startDay) || day.isAfter(endDay)) continue;
    medsInPeriodKeys.add(medicationRegimenKey(m));
  }
  final medicationsInRange = medsInPeriodKeys.length;

  int appointmentsInRange = 0;
  for (final a in data.appointments) {
    final day = DateTime(a.date.year, a.date.month, a.date.day);
    if (!day.isBefore(startDay) && !day.isAfter(endDay)) appointmentsInRange++;
  }

  return LocalStats(
    avgMood: avgMood,
    moodCount: moodCount,
    avgSleep: avgSleep,
    sleepCount: sleepCount,
    avgEnergy: avgEnergy,
    energyCount: energyCount,
    notesCount: notesInRange,
    medicationsCount: medicationsInRange,
    appointmentsCount: appointmentsInRange,
  );
}
