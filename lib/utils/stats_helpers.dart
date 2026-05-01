import '../models/aggregated_data.dart';
import '../models/state_entries.dart';

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

  int medicationsInRange = 0;
  for (final m in data.medications) {
    final day = DateTime(m.date.year, m.date.month, m.date.day);
    if (!day.isBefore(startDay) && !day.isAfter(endDay)) medicationsInRange++;
  }

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
