import 'package:flutter/material.dart';
import 'package:flutter_application_dfd/models/aggregated_data.dart';
import 'package:flutter_application_dfd/models/calendar_entry.dart';
import 'package:flutter_application_dfd/models/foundation_score.dart';
import 'package:flutter_application_dfd/models/foundation_sphere.dart';
import 'package:flutter_application_dfd/models/note_item.dart';
import 'package:flutter_application_dfd/models/state_entries.dart';
import 'package:flutter_application_dfd/services/foundation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const goals = FoundationGoals();
  const cap = 'Тестовый период';

  test('compute empty data — ноль кирпичей', () {
    final data = AggregatedData(
      notes: const [],
      stateEntries: const [],
      medications: const [],
      appointments: const [],
    );
    final s = FoundationService.instance.compute(data, goals, statsPeriodCaption: cap);
    expect(s.filledBricks, 0);
    expect(s.rawOverallProgress, 0);
    expect(s.history30d.length, FoundationService.historyDays);
    expect(s.medicationAdherenceRate, isNull);
    expect(s.dataSourcesSummary.contains('заметки не учитываются'), true);
  });

  test('заметки не влияют на фундамент', () {
    final day = DateTime.now();
    final data = AggregatedData(
      notes: [
        NoteItem(
          date: day,
          title: 't',
          tags: const [],
          preview: 'p',
          sticker: NoteStickerKind.sun,
        ),
      ],
      stateEntries: const [],
      medications: const [],
      appointments: const [],
    );
    final s = FoundationService.instance.compute(data, goals, statsPeriodCaption: cap);
    expect(s.filledBricks, 0);
  });

  test('запись настроения сегодня даёт прогресс по сфере', () {
    final day = DateTime.now();
    final data = AggregatedData(
      notes: const [],
      stateEntries: [
        MoodEntry(createdAt: day, value: 8),
      ],
      medications: const [],
      appointments: const [],
    );
    final s = FoundationService.instance.compute(data, goals, statsPeriodCaption: cap);
    final mood = s.spheres.firstWhere((e) => e.id == FoundationSphereIds.mood);
    expect(mood.loggedToday, true);
    expect(mood.progress, greaterThan(0));
  });

  test('выключенная сфера не участвует в расчёте', () {
    final goalsHidden = goals.copyWith(
      priorities: const FoundationSpherePriorities(
        sleep: 0,
        mood: 1,
        energy: 0,
        nutrition: 0,
        medication: 0,
      ),
    );
    final data = AggregatedData(
      notes: const [],
      stateEntries: [
        MoodEntry(createdAt: DateTime.now(), value: 7),
        SleepEntry(createdAt: DateTime.now(), quality: 8),
      ],
      medications: const [],
      appointments: const [],
    );
    final s = FoundationService.instance.compute(
      data,
      goalsHidden,
      statsPeriodCaption: cap,
    );
    expect(s.spheres.length, 1);
    expect(s.spheres.first.id, FoundationSphereIds.mood);
  });

  test('dailyFoundationScore падает при пропуске дня', () {
    final today = FoundationService.dayOnly(DateTime.now());
    final data = AggregatedData(
      notes: const [],
      stateEntries: [
        MoodEntry(
          createdAt: today.subtract(const Duration(days: 1)),
          value: 8,
        ),
      ],
      medications: const [],
      appointments: const [],
    );
    final todayScore = FoundationService.dailyFoundationScore(
      data: data,
      day: today,
      goals: goals,
    );
    expect(todayScore, 0);
  });

  test('nutrition progress — без всех приёмов нельзя 100%', () {
    const goals = FoundationGoals(snackTarget: 2);
    final entry = NutritionEntry(
      createdAt: DateTime.now(),
      meals: const ['ЗАВТРАК', 'ОБЕД'],
      snackCount: 2,
    );
    expect(
      FoundationService.nutritionProgressForEntry(entry, goals),
      closeTo(2 / 3, 0.001),
    );
  });

  test('nutrition progress — 3 приёма и перекусы по цели', () {
    const goals = FoundationGoals(snackTarget: 2);
    final full = NutritionEntry(
      createdAt: DateTime.now(),
      meals: const ['ЗАВТРАК', 'ОБЕД', 'УЖИН'],
      snackCount: 2,
    );
    expect(FoundationService.nutritionProgressForEntry(full, goals), 1.0);

    final partialSnacks = NutritionEntry(
      createdAt: DateTime.now(),
      meals: const ['ЗАВТРАК', 'ОБЕД', 'УЖИН'],
      snackCount: 1,
    );
    expect(
      FoundationService.nutritionProgressForEntry(partialSnacks, goals),
      closeTo(0.5, 0.001),
    );
  });

  test('два дня подряд с записями — серия 2 и учёт в среднем', () {
    final today = FoundationService.dayOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final data = AggregatedData(
      notes: const [],
      stateEntries: [
        MoodEntry(createdAt: today, value: 8),
        SleepEntry(createdAt: today, quality: 8),
        EnergyEntry(createdAt: today, level: 8),
        NutritionEntry(
          createdAt: today,
          meals: const ['ЗАВТРАК', 'ОБЕД', 'УЖИН'],
          snackCount: 1,
        ),
        MoodEntry(createdAt: yesterday, value: 8),
        SleepEntry(createdAt: yesterday, quality: 8),
        EnergyEntry(createdAt: yesterday, level: 8),
        NutritionEntry(
          createdAt: yesterday,
          meals: const ['ЗАВТРАК', 'ОБЕД', 'УЖИН'],
          snackCount: 1,
        ),
      ],
      medications: const [],
      appointments: const [],
    );
    final s = FoundationService.instance.compute(data, goals, statsPeriodCaption: cap);
    expect(s.activityStreak, 2);
    expect(s.filledBricks, greaterThan(0));
    expect(s.rawOverallProgress, greaterThan(0));
  });

  test('medication adherence сегодня', () {
    final day = DateTime.now();
    final med = Medication(
      id: '1',
      date: day,
      time: const TimeOfDay(hour: 9, minute: 0),
      name: 'x',
      dosage: '1',
      schedule: const [
        MedicationDose(time: TimeOfDay(hour: 9, minute: 0), amount: '1'),
      ],
      takenAtPerDose: [day.add(const Duration(hours: 1))],
    );
    final data = AggregatedData(
      notes: const [],
      stateEntries: const [],
      medications: [med],
      appointments: const [],
    );
    final s = FoundationService.instance.compute(data, goals, statsPeriodCaption: cap);
    expect(s.medicationAdherenceRate, closeTo(1.0, 0.01));
  });
}
