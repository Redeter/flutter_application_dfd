import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/aggregated_data.dart';
import '../models/foundation_score.dart';
import '../models/state_entries.dart';
import 'user_scoped_store.dart';

class FoundationService {
  FoundationService._();
  static final FoundationService instance = FoundationService._();

  static const _keyGoals = 'foundation_goals_v1';
  static const prefsKeyQuestDoneDate = 'foundation_quest_done_date_v1';
  static const _prefsSmoothOverall = 'foundation_overall_display_smooth_v1';
  static const _prefsWeightSurveyDone = 'foundation_weight_survey_v1';

  /// Сброс «квеста дня» при полном wipe данных (цели/веса в [prefsKeyGoals] не трогаем).
  Future<void> clearQuestDoneDate() async {
    final prefs = await SharedPreferences.getInstance();
    final qKey = await UserScopedStore.scopedKey(prefsKeyQuestDoneDate);
    await prefs.remove(qKey);
  }

  Future<FoundationGoals> loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final gKey = await UserScopedStore.scopedKey(_keyGoals);
    final raw = prefs.getString(gKey);
    if (raw == null || raw.isEmpty) return const FoundationGoals();
    try {
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return FoundationGoals(
        sleepTarget: (m['sleepTarget'] as num?)?.toDouble() ?? 7.5,
        moodTarget: (m['moodTarget'] as num?)?.toDouble() ?? 7.0,
        energyTarget: (m['energyTarget'] as num?)?.toDouble() ?? 7.0,
        sleepWeight: (m['sleepWeight'] as num?)?.toDouble() ?? 1.0,
        moodWeight: (m['moodWeight'] as num?)?.toDouble() ?? 1.0,
        energyWeight: (m['energyWeight'] as num?)?.toDouble() ?? 1.0,
        consistencyWeight: (m['consistencyWeight'] as num?)?.toDouble() ?? 0.7,
      );
    } catch (_) {
      return const FoundationGoals();
    }
  }

  Future<void> saveGoals(FoundationGoals goals) async {
    final prefs = await SharedPreferences.getInstance();
    final gKey = await UserScopedStore.scopedKey(_keyGoals);
    await prefs.setString(
      gKey,
      jsonEncode({
        'sleepTarget': goals.sleepTarget,
        'moodTarget': goals.moodTarget,
        'energyTarget': goals.energyTarget,
        'sleepWeight': goals.sleepWeight,
        'moodWeight': goals.moodWeight,
        'energyWeight': goals.energyWeight,
        'consistencyWeight': goals.consistencyWeight,
      }),
    );
  }

  Future<bool> isQuestDoneToday() async {
    final prefs = await SharedPreferences.getInstance();
    final qKey = await UserScopedStore.scopedKey(prefsKeyQuestDoneDate);
    final raw = prefs.getString(qKey);
    if (raw == null) return false;
    final now = DateTime.now();
    final d = DateTime.tryParse(raw);
    if (d == null) return false;
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Future<void> setQuestDoneToday(bool done) async {
    final prefs = await SharedPreferences.getInstance();
    final qKey = await UserScopedStore.scopedKey(prefsKeyQuestDoneDate);
    if (!done) {
      await prefs.remove(qKey);
      return;
    }
    await prefs.setString(qKey, DateTime.now().toIso8601String());
  }

  FoundationScore compute(
    AggregatedData data,
    FoundationGoals goals, {
    required String statsPeriodCaption,
  }) {
    final hasAnySignal = data.notes.isNotEmpty ||
        data.stateEntries.isNotEmpty ||
        data.medications.isNotEmpty ||
        data.appointments.isNotEmpty;
    final hasStateOrNotes =
        data.notes.isNotEmpty || data.stateEntries.isNotEmpty;
    final hasSleepSamples =
        data.stateEntries.whereType<SleepEntry>().isNotEmpty;
    final hasMoodSamples =
        data.stateEntries.whereType<MoodEntry>().isNotEmpty;
    final hasEnergySamples =
        data.stateEntries.whereType<EnergyEntry>().isNotEmpty;
    final days = _observationDays(data).toDouble();
    final activeDays = _activeDays(data).toDouble();
    final consistency = days <= 0 ? 0.0 : (activeDays / days).clamp(0.0, 1.0);
    final reliability = (days / 14).clamp(0.0, 1.0);
    final baseConfidence = (0.6 * reliability + 0.4 * consistency).clamp(0.0, 1.0);

    final sleepAvg = _avgSleep(data);
    final moodAvg = _avgMood(data);
    final energyAvg = _avgEnergy(data);

    var confidenceCap = false;
    if (days < 7) {
      confidenceCap = true;
    }
    final effectiveConfidence = confidenceCap ? baseConfidence.clamp(0.0, 0.65) : baseConfidence;

    final rawSpheres = <FoundationSphereScore>[
      FoundationSphereScore(
        id: 'sleep',
        label: 'Сон',
        target: goals.sleepTarget,
        current: sleepAvg,
        progress: _ratio(sleepAvg, goals.sleepTarget),
        confidence: effectiveConfidence,
        weight: goals.sleepWeight,
        brickContribution: 0,
        hasMetricSamples: hasSleepSamples,
      ),
      FoundationSphereScore(
        id: 'mood',
        label: 'Настроение',
        target: goals.moodTarget,
        current: moodAvg,
        progress: _ratio(moodAvg, goals.moodTarget),
        confidence: effectiveConfidence,
        weight: goals.moodWeight,
        brickContribution: 0,
        hasMetricSamples: hasMoodSamples,
      ),
      FoundationSphereScore(
        id: 'energy',
        label: 'Энергия',
        target: goals.energyTarget,
        current: energyAvg,
        progress: _ratio(energyAvg, goals.energyTarget),
        confidence: effectiveConfidence,
        weight: goals.energyWeight,
        brickContribution: 0,
        hasMetricSamples: hasEnergySamples,
      ),
      FoundationSphereScore(
        id: 'consistency',
        label: 'Регулярность',
        target: 0.8,
        current: consistency,
        progress: consistency,
        confidence: effectiveConfidence,
        weight: goals.consistencyWeight,
        brickContribution: 0,
        hasMetricSamples: true,
      ),
    ];

    final weightedSum = rawSpheres.fold<double>(
      0,
      (acc, s) => acc + (s.progress * s.confidence * s.weight),
    );
    final totalWeight = rawSpheres.fold<double>(0, (acc, s) => acc + s.weight);
    final overall = totalWeight == 0 ? 0.0 : (weightedSum / totalWeight).clamp(0.0, 1.0);
    const totalBricks = 40;
    final filled = (overall * totalBricks).round().clamp(0, totalBricks);

    final spheres = rawSpheres
        .map((s) => FoundationSphereScore(
              id: s.id,
              label: s.label,
              target: s.target,
              current: s.current,
              progress: s.progress,
              confidence: s.confidence,
              weight: s.weight,
              brickContribution: ((s.progress * s.confidence * s.weight) /
                      (totalWeight == 0 ? 1 : totalWeight) *
                      totalBricks)
                  .round(),
              hasMetricSamples: s.hasMetricSamples,
            ))
        .toList();

    final weakest = [...spheres]
      ..sort((a, b) {
        final ca = a.progress * a.confidence;
        final cb = b.progress * b.confidence;
        final c = ca.compareTo(cb);
        if (c != 0) return c;
        return a.id.compareTo(b.id);
      });
    final next = _nextStepFor(weakest.first.id);
    final previousWeek = _subset(data, fromDaysAgo: 14, toDaysAgo: 7);
    final currentWeek = _subset(data, fromDaysAgo: 7, toDaysAgo: 0);
    final prevFilled = _computeBricks(previousWeek, goals);
    final currFilled = _computeBricks(currentWeek, goals);
    final delta7 = currFilled - prevFilled;
    final (cracks, cracksWhy) = _riskCracksWithExplanation(data);
    final (history, historyDetails) =
        _history30dWithDetails(data, goals, totalBricks);
    final calendarCount = data.medications.length + data.appointments.length;
    final dataSourcesSummary =
        'В расчёте: заметок ${data.notes.length} · записей состояния ${data.stateEntries.length} · календарь $calendarCount';

    final (medRate, medCaption) = _medicationAdherence(data);
    final streak = _consecutiveDaysWithNoteOrState(data);
    final weeklySub = streak == 0
        ? 'Начните с одного дня с заметкой или записью через «+».'
        : '${_pluralDaysRu(streak)} подряд с заметкой или «+».';

    final String hint;
    if (!hasAnySignal) {
      hint =
          'Пока нет данных — фундамент обнулён. Добавьте заметки, записи через «+» или план в календаре.';
    } else if (!hasStateOrNotes &&
        (data.medications.isNotEmpty || data.appointments.isNotEmpty)) {
      hint =
          'Календарь учитывается в регулярности. Сон, настроение и энергия заполняются записями через центральную «+».';
    } else if (confidenceCap) {
      hint =
          'Фундамент показывает тренд, но данных пока мало: это предварительная оценка.';
    } else {
      hint =
          'Кирпичи — по заметкам, записям состояния и календарю за последние недели.';
    }

    const missionTitle = 'Фундамент — не диагноз';
    const missionBody =
        'Это локальная сводка по вашим заметкам, записям «+» и календарю. Она не заменяет врача и не уходит с устройства, пока вы сами не делитесь данными.';

    return FoundationScore(
      totalBricks: totalBricks,
      filledBricks: filled,
      overallProgress: overall,
      rawOverallProgress: overall,
      spheres: spheres,
      nextStep: next,
      brickDelta7d: delta7,
      riskCracks: cracks,
      riskCracksExplanation: cracksWhy,
      history30d: history,
      historyDayDetails: historyDetails,
      confidenceCap: confidenceCap,
      userHint: hint,
      dataSourcesSummary: dataSourcesSummary,
      missionTitle: missionTitle,
      missionBody: missionBody,
      weeklyFocusTitle: 'Цель недели',
      weeklyFocusSubtitle: weeklySub,
      medicationAdherenceRate: medRate,
      medicationAdherenceCaption: medCaption,
      statsPeriodCaption: statsPeriodCaption,
    );
  }

  Future<FoundationScore> applyDisplaySmoothing(FoundationScore raw) async {
    final prefs = await SharedPreferences.getInstance();
    final smoothKey = await UserScopedStore.scopedKey(_prefsSmoothOverall);
    if (raw.rawOverallProgress <= 0.0001 && raw.filledBricks == 0) {
      await prefs.remove(smoothKey);
      return raw;
    }
    final prev = prefs.getDouble(smoothKey) ?? raw.rawOverallProgress;
    const alpha = 0.38;
    final next =
        (alpha * raw.rawOverallProgress + (1 - alpha) * prev).clamp(0.0, 1.0);
    await prefs.setDouble(smoothKey, next);
    final filled = (next * raw.totalBricks).round().clamp(0, raw.totalBricks);
    return raw.copyWithSmoothed(
      displayOverall: next,
      displayFilledBricks: filled,
    );
  }

  Future<bool> isWeightSurveyDone() async {
    final prefs = await SharedPreferences.getInstance();
    final wKey = await UserScopedStore.scopedKey(_prefsWeightSurveyDone);
    return prefs.getBool(wKey) ?? false;
  }

  Future<void> markWeightSurveyDone() async {
    final prefs = await SharedPreferences.getInstance();
    final wKey = await UserScopedStore.scopedKey(_prefsWeightSurveyDone);
    await prefs.setBool(wKey, true);
  }

  /// Первичный выбор «что важнее» — чуть сдвигает веса сфер.
  Future<void> applyPresetWeightsForPrimary(String sphereId) async {
    FoundationGoals g;
    switch (sphereId) {
      case 'sleep':
        g = const FoundationGoals(
          sleepWeight: 1.55,
          moodWeight: 0.88,
          energyWeight: 0.88,
          consistencyWeight: 0.72,
        );
      case 'mood':
        g = const FoundationGoals(
          sleepWeight: 0.9,
          moodWeight: 1.55,
          energyWeight: 0.9,
          consistencyWeight: 0.72,
        );
      case 'energy':
        g = const FoundationGoals(
          sleepWeight: 0.9,
          moodWeight: 0.9,
          energyWeight: 1.55,
          consistencyWeight: 0.72,
        );
      default:
        g = const FoundationGoals();
    }
    await saveGoals(g);
    await markWeightSurveyDone();
  }

  String _nextStepFor(String sphereId) {
    switch (sphereId) {
      case 'sleep':
        return 'Шаг на сегодня: отметьте сон через «+» или лягте спать на 30 минут раньше.';
      case 'mood':
        return 'Шаг на сегодня: короткая заметка или настроение в «+» — что поддержало день.';
      case 'energy':
        return 'Шаг на сегодня: запись энергии в «+» или 20 минут прогулки.';
      case 'consistency':
        return 'Шаг на сегодня: календарь (приём/визит) и хотя бы одна запись через «+».';
      default:
        return 'Шаг на сегодня: «+» — запись состояния или заметка; при необходимости отметьте календарь.';
    }
  }

  double _ratio(double current, double target) {
    if (target <= 0) return 0;
    return (current / target).clamp(0.0, 1.0);
  }

  int _computeBricks(AggregatedData data, FoundationGoals goals) {
    final days = _observationDays(data).toDouble();
    final activeDays = _activeDays(data).toDouble();
    final consistency = days <= 0 ? 0.0 : (activeDays / days).clamp(0.0, 1.0);
    final reliability = (days / 14).clamp(0.0, 1.0);
    final conf = (0.6 * reliability + 0.4 * consistency).clamp(0.0, days < 7 ? 0.65 : 1.0);
    final spheres = [
      _ratio(_avgSleep(data), goals.sleepTarget) * conf * goals.sleepWeight,
      _ratio(_avgMood(data), goals.moodTarget) * conf * goals.moodWeight,
      _ratio(_avgEnergy(data), goals.energyTarget) * conf * goals.energyWeight,
      consistency * conf * goals.consistencyWeight,
    ];
    final totalWeight =
        goals.sleepWeight + goals.moodWeight + goals.energyWeight + goals.consistencyWeight;
    final overall =
        totalWeight == 0 ? 0.0 : (spheres.reduce((a, b) => a + b) / totalWeight).clamp(0.0, 1.0);
    return (overall * 40).round().clamp(0, 40);
  }

  (int cracks, String? explanation) _riskCracksWithExplanation(AggregatedData data) {
    final moods = data.stateEntries.whereType<MoodEntry>().toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final energies = data.stateEntries.whereType<EnergyEntry>().toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final lowMood = moods.take(5).where((m) => m.value < 5).length;
    final lowEnergy = energies.take(5).where((e) => e.level < 5).length;
    if (lowMood >= 4 || lowEnergy >= 4) {
      return (
        2,
        'Среди 5 последних оценок настроения и энергии много значений ниже 5 — это сигнал «трещины» для осторожности, не диагноз.',
      );
    }
    if (lowMood >= 3 || lowEnergy >= 3) {
      return (
        1,
        'Несколько последних отметок ниже 5 — лёгкий риск; стабилизируйте сон и ритм, при ухудшении обратитесь к врачу.',
      );
    }
    return (0, null);
  }

  (List<int>, List<FoundationHistoryDayDetail>) _history30dWithDetails(
    AggregatedData data,
    FoundationGoals goals,
    int totalBricks,
  ) {
    final out = <int>[];
    final details = <FoundationHistoryDayDetail>[];
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    for (var day = 29; day >= 0; day--) {
      final snap = _subset(data, fromDaysAgo: day + 14, toDaysAgo: day);
      final b = _computeBricks(snap, goals).clamp(0, totalBricks);
      out.add(b);
      final end = todayNorm.subtract(Duration(days: day));
      details.add(
        FoundationHistoryDayDetail(
          windowEndDay: end,
          bricks: b,
          notesCount: snap.notes.length,
          stateCount: snap.stateEntries.length,
          calendarCount: snap.medications.length + snap.appointments.length,
        ),
      );
    }
    return (out, details);
  }

  (double? rate, String caption) _medicationAdherence(AggregatedData d) {
    if (d.medications.isEmpty) {
      return (null, '');
    }
    var expected = 0;
    var taken = 0;
    for (final m in d.medications) {
      final slots = m.schedule.isEmpty ? 1 : m.schedule.length;
      expected += slots;
      if (m.schedule.isEmpty) {
        if (m.takenAtPerDose.isNotEmpty && m.takenAtPerDose[0] != null) {
          taken += 1;
        }
      } else {
        for (var i = 0; i < m.schedule.length; i++) {
          if (i < m.takenAtPerDose.length && m.takenAtPerDose[i] != null) {
            taken++;
          }
        }
      }
    }
    if (expected == 0) {
      return (null, '');
    }
    final r = taken / expected;
    return (
      r,
      'Приёмы в календаре: отмечено $taken из $expected слотов (${(r * 100).round()}%).',
    );
  }

  int _consecutiveDaysWithNoteOrState(AggregatedData d) {
    DateTime norm(DateTime t) => DateTime(t.year, t.month, t.day);
    final active = <DateTime>{};
    for (final n in d.notes) {
      active.add(norm(n.date));
    }
    for (final s in d.stateEntries) {
      active.add(norm(s.createdAt));
    }
    final today = norm(DateTime.now());
    var streak = 0;
    for (var i = 0; i < 400; i++) {
      final day = today.subtract(Duration(days: i));
      if (active.contains(day)) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  String _pluralDaysRu(int n) {
    if (n % 10 == 1 && n % 100 != 11) return '$n день';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return '$n дня';
    }
    return '$n дней';
  }

  AggregatedData _subset(
    AggregatedData data, {
    required int fromDaysAgo,
    required int toDaysAgo,
  }) {
    DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    final today = dayOnly(DateTime.now());
    final from = today.subtract(Duration(days: fromDaysAgo));
    final to = today.subtract(Duration(days: toDaysAgo));
    bool inRange(DateTime d) {
      final day = dayOnly(d);
      return !day.isBefore(from) && !day.isAfter(to);
    }
    return AggregatedData(
      notes: data.notes.where((n) => inRange(n.date)).toList(),
      stateEntries: data.stateEntries.where((s) => inRange(s.createdAt)).toList(),
      medications: data.medications.where((m) => inRange(m.date)).toList(),
      appointments: data.appointments.where((a) => inRange(a.date)).toList(),
    );
  }

  double _avgMood(AggregatedData d) {
    final list = d.stateEntries.whereType<MoodEntry>().map((e) => e.value.toDouble()).toList();
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  double _avgSleep(AggregatedData d) {
    final list = d.stateEntries.whereType<SleepEntry>().map((e) => e.quality.toDouble()).toList();
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  double _avgEnergy(AggregatedData d) {
    final list = d.stateEntries.whereType<EnergyEntry>().map((e) => e.level.toDouble()).toList();
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  int _observationDays(AggregatedData d) {
    DateTime? first;
    DateTime? last;
    void consider(DateTime t) {
      first = first == null || t.isBefore(first!) ? t : first;
      last = last == null || t.isAfter(last!) ? t : last;
    }

    for (final n in d.notes) {
      consider(n.date);
    }
    for (final s in d.stateEntries) {
      consider(s.createdAt);
    }
    for (final m in d.medications) {
      consider(DateTime(m.date.year, m.date.month, m.date.day));
    }
    for (final a in d.appointments) {
      consider(DateTime(a.date.year, a.date.month, a.date.day));
    }
    if (first == null || last == null) return 0;
    return last!.difference(first!).inDays + 1;
  }

  int _activeDays(AggregatedData d) {
    final days = <DateTime>{};
    for (final n in d.notes) {
      days.add(DateTime(n.date.year, n.date.month, n.date.day));
    }
    for (final s in d.stateEntries) {
      days.add(DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day));
    }
    for (final m in d.medications) {
      days.add(DateTime(m.date.year, m.date.month, m.date.day));
    }
    for (final a in d.appointments) {
      days.add(DateTime(a.date.year, a.date.month, a.date.day));
    }
    return days.length;
  }
}
