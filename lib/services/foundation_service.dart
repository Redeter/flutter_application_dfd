import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/aggregated_data.dart';
import '../models/foundation_score.dart';
import '../models/state_entries.dart';

class FoundationService {
  FoundationService._();
  static final FoundationService instance = FoundationService._();

  static const _keyGoals = 'foundation_goals_v1';
  static const _keyQuestDoneDate = 'foundation_quest_done_date_v1';

  Future<FoundationGoals> loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyGoals);
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
    await prefs.setString(
      _keyGoals,
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
    final raw = prefs.getString(_keyQuestDoneDate);
    if (raw == null) return false;
    final now = DateTime.now();
    final d = DateTime.tryParse(raw);
    if (d == null) return false;
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Future<void> setQuestDoneToday(bool done) async {
    final prefs = await SharedPreferences.getInstance();
    if (!done) {
      await prefs.remove(_keyQuestDoneDate);
      return;
    }
    await prefs.setString(_keyQuestDoneDate, DateTime.now().toIso8601String());
  }

  FoundationScore compute(AggregatedData data, FoundationGoals goals) {
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
            ))
        .toList();

    final weakest = [...spheres]
      ..sort((a, b) => (a.progress * a.confidence).compareTo(b.progress * b.confidence));
    final next = _nextStepFor(weakest.first.id);
    final previousWeek = _subset(data, fromDaysAgo: 14, toDaysAgo: 7);
    final currentWeek = _subset(data, fromDaysAgo: 7, toDaysAgo: 0);
    final prevFilled = _computeBricks(previousWeek, goals);
    final currFilled = _computeBricks(currentWeek, goals);
    final delta7 = currFilled - prevFilled;
    final cracks = _riskCracks(data);
    final history = _history30d(data, goals, totalBricks);
    final hint = confidenceCap
        ? 'Фундамент показывает тренд, но данных пока мало: это предварительная оценка.'
        : 'Каждый кирпич — вклад реальных данных за последние недели.';

    return FoundationScore(
      totalBricks: totalBricks,
      filledBricks: filled,
      overallProgress: overall,
      spheres: spheres,
      nextStep: next,
      brickDelta7d: delta7,
      riskCracks: cracks,
      history30d: history,
      confidenceCap: confidenceCap,
      userHint: hint,
    );
  }

  String _nextStepFor(String sphereId) {
    switch (sphereId) {
      case 'sleep':
        return 'Шаг на сегодня: лечь спать на 30 минут раньше обычного.';
      case 'mood':
        return 'Шаг на сегодня: добавить 1 короткую заметку о том, что помогло дню.';
      case 'energy':
        return 'Шаг на сегодня: 20 минут прогулки до вечера.';
      default:
        return 'Шаг на сегодня: добавить минимум 1 запись состояния и 1 заметку.';
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

  int _riskCracks(AggregatedData data) {
    final moods = data.stateEntries.whereType<MoodEntry>().toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final energies = data.stateEntries.whereType<EnergyEntry>().toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final lowMood = moods.take(5).where((m) => m.value < 5).length;
    final lowEnergy = energies.take(5).where((e) => e.level < 5).length;
    if (lowMood >= 4 || lowEnergy >= 4) return 2;
    if (lowMood >= 3 || lowEnergy >= 3) return 1;
    return 0;
  }

  List<int> _history30d(AggregatedData data, FoundationGoals goals, int totalBricks) {
    final out = <int>[];
    for (var day = 29; day >= 0; day--) {
      final snap = _subset(data, fromDaysAgo: day + 14, toDaysAgo: day);
      out.add(_computeBricks(snap, goals).clamp(0, totalBricks));
    }
    return out;
  }

  AggregatedData _subset(
    AggregatedData data, {
    required int fromDaysAgo,
    required int toDaysAgo,
  }) {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: fromDaysAgo));
    final to = now.subtract(Duration(days: toDaysAgo));
    return AggregatedData(
      notes: data.notes.where((n) => !n.date.isBefore(from) && !n.date.isAfter(to)).toList(),
      stateEntries: data.stateEntries
          .where((s) => !s.createdAt.isBefore(from) && !s.createdAt.isAfter(to))
          .toList(),
      medications: data.medications.where((m) => !m.date.isBefore(from) && !m.date.isAfter(to)).toList(),
      appointments: data.appointments.where((a) => !a.date.isBefore(from) && !a.date.isAfter(to)).toList(),
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
    for (final n in d.notes) {
      first = first == null || n.date.isBefore(first) ? n.date : first;
      last = last == null || n.date.isAfter(last) ? n.date : last;
    }
    for (final s in d.stateEntries) {
      first = first == null || s.createdAt.isBefore(first) ? s.createdAt : first;
      last = last == null || s.createdAt.isAfter(last) ? s.createdAt : last;
    }
    if (first == null || last == null) return 0;
    return last.difference(first).inDays + 1;
  }

  int _activeDays(AggregatedData d) {
    final days = <DateTime>{};
    for (final n in d.notes) {
      days.add(DateTime(n.date.year, n.date.month, n.date.day));
    }
    for (final s in d.stateEntries) {
      days.add(DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day));
    }
    return days.length;
  }
}
