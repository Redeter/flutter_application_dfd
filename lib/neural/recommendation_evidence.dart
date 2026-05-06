import '../models/aggregated_data.dart';
import '../models/state_entries.dart';

/// Агрегаты за 14 дней для слотов в персонализированных текстах советов.
class RecommendationSlotStats {
  const RecommendationSlotStats({
    required this.lowSleepDays,
    required this.distinctSleepDays,
    required this.lowMoodDays,
    required this.distinctMoodDays,
    required this.lowEnergyDays,
    required this.distinctEnergyDays,
    required this.notes14,
    required this.trackedDays,
    required this.anxiousFreq,
    required this.tripleLowDays14,
    required this.morningEntries,
    required this.eveningEntries,
    this.sleepThresholdDisplay = 6,
    this.moodThresholdDisplay = 5,
    this.energyThresholdDisplay = 5,
  });

  final int lowSleepDays;
  final int distinctSleepDays;
  final int lowMoodDays;
  final int distinctMoodDays;
  final int lowEnergyDays;
  final int distinctEnergyDays;
  final int notes14;
  final int trackedDays;
  final double anxiousFreq;
  final int tripleLowDays14;
  final int morningEntries;
  final int eveningEntries;
  final int sleepThresholdDisplay;
  final int moodThresholdDisplay;
  final int energyThresholdDisplay;

  static RecommendationSlotStats compute(AggregatedData d) {
    final now = DateTime.now();
    DateTime d0(DateTime t) => DateTime(t.year, t.month, t.day);
    final today = d0(now);
    final from14d = today.subtract(const Duration(days: 14));

    final sleep14 = d.stateEntries
        .whereType<SleepEntry>()
        .where((e) => !d0(e.createdAt).isBefore(from14d))
        .toList();
    final mood14 = d.stateEntries
        .whereType<MoodEntry>()
        .where((e) => !d0(e.createdAt).isBefore(from14d))
        .toList();
    final energy14 = d.stateEntries
        .whereType<EnergyEntry>()
        .where((e) => !d0(e.createdAt).isBefore(from14d))
        .toList();

    final sleepByDay = <DateTime, int>{};
    for (final e in sleep14) {
      sleepByDay[d0(e.createdAt)] = e.quality;
    }
    final moodByDay = <DateTime, int>{};
    for (final e in mood14) {
      moodByDay[d0(e.createdAt)] = e.value;
    }
    final energyByDay = <DateTime, int>{};
    for (final e in energy14) {
      energyByDay[d0(e.createdAt)] = e.level;
    }

    final sleepDaysBad = <DateTime>{};
    final sleepDaysAny = <DateTime>{};
    for (final e in sleep14) {
      final day = d0(e.createdAt);
      sleepDaysAny.add(day);
      if (e.quality < 6) sleepDaysBad.add(day);
    }

    final moodDaysBad = <DateTime>{};
    final moodDaysAny = <DateTime>{};
    for (final e in mood14) {
      final day = d0(e.createdAt);
      moodDaysAny.add(day);
      if (e.value < 5) moodDaysBad.add(day);
    }

    final energyDaysBad = <DateTime>{};
    final energyDaysAny = <DateTime>{};
    for (final e in energy14) {
      final day = d0(e.createdAt);
      energyDaysAny.add(day);
      if (e.level < 5) energyDaysBad.add(day);
    }

    var morning = 0;
    var evening = 0;
    for (final e in d.stateEntries) {
      if (d0(e.createdAt).isBefore(from14d)) continue;
      final h = e.createdAt.hour;
      if (h < 12) morning++;
      if (h >= 18) evening++;
    }

    final union = <DateTime>{};
    union.addAll(moodByDay.keys);
    union.addAll(sleepByDay.keys);
    union.addAll(energyByDay.keys);
    var tripleLow = 0;
    for (final day in union) {
      final m = moodByDay[day];
      final s = sleepByDay[day];
      final en = energyByDay[day];
      if (m != null && s != null && en != null && m < 5 && s < 5 && en < 5) {
        tripleLow++;
      }
    }

    final notes14 = d.notes.where((n) => !d0(n.date).isBefore(from14d)).length;
    final trackedDays = d.stateEntries
        .where((e) => !d0(e.createdAt).isBefore(from14d))
        .map((e) => d0(e.createdAt))
        .toSet()
        .length;

    return RecommendationSlotStats(
      lowSleepDays: sleepDaysBad.length,
      distinctSleepDays: sleepDaysAny.length,
      lowMoodDays: moodDaysBad.length,
      distinctMoodDays: moodDaysAny.length,
      lowEnergyDays: energyDaysBad.length,
      distinctEnergyDays: energyDaysAny.length,
      notes14: notes14,
      trackedDays: trackedDays,
      anxiousFreq: RecommendationEvidence.anxiousWordFrequencyFor(d),
      tripleLowDays14: tripleLow,
      morningEntries: morning,
      eveningEntries: evening,
    );
  }
}

/// Минимальные условия по дням/событиям, чтобы совет считался подтверждённым данными.
class RecommendationEvidence {
  RecommendationEvidence._();

  static double anxiousWordFrequencyFor(AggregatedData d) => _anxiousWordFrequency(d);

  static double _anxiousWordFrequency(AggregatedData d) {
    final text = d.notes.map((n) => '${n.title} ${n.preview}').join(' ').toLowerCase();
    final words = RegExp(r'[а-яёa-z]+', caseSensitive: false)
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toList();
    if (words.isEmpty) return 0;
    const anxious = {'тревога', 'стресс', 'устал', 'паника', 'напряжение', 'бессонница'};
    final count = words.where((w) => anxious.any((a) => w.contains(a))).length;
    return count / words.length;
  }

  /// Достаточно ли наблюдений за 14 дней для показа этого текста совета.
  static bool meetsMinimum(String rec, AggregatedData d) {
    final now = DateTime.now();
    final s = RecommendationSlotStats.compute(d);
    final medsCount = d.medications.length;
    final upcomingVisits = d.appointments
        .where((a) => a.meetingDate != null && a.meetingDate!.isAfter(now))
        .length;

    if (rec.contains('сна')) {
      return s.distinctSleepDays >= 3 && s.lowSleepDays >= 2;
    }
    if (rec.contains('энерг')) {
      return s.distinctEnergyDays >= 3 && s.lowEnergyDays >= 2;
    }
    if (rec.contains('Регулярные заметки') || rec.contains('регулярные заметки')) {
      return s.trackedDays >= 5;
    }
    if (rec.contains('запись мыслей') && rec.contains('замет')) {
      final moodOk = s.distinctMoodDays >= 3 && s.lowMoodDays >= 2;
      final notesOk = s.notes14 >= 2 && (s.anxiousFreq >= 0.06 || s.notes14 >= 4);
      return moodOk || notesOk;
    }
    if (rec.contains('настроен')) {
      return s.distinctMoodDays >= 3 && s.lowMoodDays >= 2;
    }
    if (rec.contains('препарат')) {
      return medsCount >= 1;
    }
    if (rec.contains('врач')) {
      return upcomingVisits >= 1;
    }
    if (rec.contains('замет')) {
      return s.notes14 >= 2 && (s.anxiousFreq >= 0.06 || s.notes14 >= 4);
    }
    return true;
  }
}
