import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/aggregated_data.dart';
import '../models/calendar_entry.dart';
import '../constants/privacy_copy.dart';
import '../models/foundation_score.dart';
import '../models/foundation_sphere.dart';
import '../models/state_entries.dart';
import '../models/user_profile.dart';
import 'user_scoped_store.dart';

class FoundationService {
  FoundationService._();
  static final FoundationService instance = FoundationService._();

  static const totalBricks = 72;
  static const trackingDays = 14;
  static const historyDays = 30;

  static const _keyGoals = 'foundation_goals_v2';
  static const _keyGoalsLegacy = 'foundation_goals_v1';
  static const prefsKeyQuestDoneDate = 'foundation_quest_done_date_v1';
  static const _prefsSmoothOverall = 'foundation_overall_display_smooth_v1';
  static const prefsKeyQuestCompletedDays = 'foundation_quest_completed_days_v1';
  static const prefsKeyEveningReminderEnabled =
      'foundation_quest_evening_reminder_enabled_v1';
  static const prefsKeyEveningReminderHour =
      'foundation_quest_evening_reminder_h_v1';
  static const prefsKeyEveningReminderMinute =
      'foundation_quest_evening_reminder_m_v1';

  Future<void> clearQuestDoneDate() async {
    final prefs = await SharedPreferences.getInstance();
    final qKey = await UserScopedStore.scopedKey(prefsKeyQuestDoneDate);
    await prefs.remove(qKey);
  }

  Future<FoundationGoals> loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final gKey = await UserScopedStore.scopedKey(_keyGoals);
    var raw = prefs.getString(gKey);
    if (raw == null || raw.isEmpty) {
      final legacyKey = await UserScopedStore.scopedKey(_keyGoalsLegacy);
      raw = prefs.getString(legacyKey);
    }
    if (raw == null || raw.isEmpty) return const FoundationGoals();
    try {
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      FoundationSpherePriorities priorities;
      if (m['priorities'] is Map) {
        priorities = FoundationSpherePriorities.fromJson(
          Map<String, dynamic>.from(m['priorities'] as Map),
        );
      } else {
        priorities = FoundationSpherePriorities.migrateFromLegacy(
          sleepWeight: (m['sleepWeight'] as num?)?.toDouble(),
          moodWeight: (m['moodWeight'] as num?)?.toDouble(),
          energyWeight: (m['energyWeight'] as num?)?.toDouble(),
        );
      }
      return FoundationGoals(
        sleepTarget: (m['sleepTarget'] as num?)?.toDouble() ?? 7.5,
        moodTarget: (m['moodTarget'] as num?)?.toDouble() ?? 7.0,
        energyTarget: (m['energyTarget'] as num?)?.toDouble() ?? 7.0,
        snackTarget: ((m['snackTarget'] as num?)?.toInt() ?? 1).clamp(0, 5),
        priorities: priorities,
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
        'snackTarget': goals.snackTarget,
        'priorities': goals.priorities.toJson(),
      }),
    );
  }

  Future<void> syncGoalsPrioritiesFromProfile(FoundationSpherePriorities p) async {
    final current = await loadGoals();
    await saveGoals(current.copyWith(priorities: p));
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
    final set = await _loadCompletedDayKeys();
    final day = _questDayKey(DateTime.now());
    if (!done) {
      await prefs.remove(qKey);
      set.remove(day);
      await _saveCompletedDayKeys(set);
      return;
    }
    await prefs.setString(qKey, DateTime.now().toIso8601String());
    set.add(day);
    await _saveCompletedDayKeys(set);
  }

  String _questDayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Set<String>> _loadCompletedDayKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await UserScopedStore.scopedKey(prefsKeyQuestCompletedDays);
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveCompletedDayKeys(Set<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await UserScopedStore.scopedKey(prefsKeyQuestCompletedDays);
    final sorted = keys.toList()..sort();
    await prefs.setString(key, jsonEncode(sorted));
  }

  Future<void> ensureQuestHistorySyncedWithLegacyFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final qKey = await UserScopedStore.scopedKey(prefsKeyQuestDoneDate);
    final raw = prefs.getString(qKey);
    if (raw == null) return;
    final d = DateTime.tryParse(raw);
    if (d == null) return;
    final now = DateTime.now();
    if (d.year != now.year || d.month != now.month || d.day != now.day) {
      return;
    }
    final day = _questDayKey(d);
    final set = await _loadCompletedDayKeys();
    if (!set.contains(day)) {
      set.add(day);
      await _saveCompletedDayKeys(set);
    }
  }

  Future<int> loadQuestCompletionStreak() async {
    await ensureQuestHistorySyncedWithLegacyFlag();
    final set = await _loadCompletedDayKeys();
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final todayKey = _questDayKey(today);
    var cursor =
        set.contains(todayKey) ? today : today.subtract(const Duration(days: 1));
    var streak = 0;
    while (set.contains(_questDayKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<bool> isQuestEveningReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final k = await UserScopedStore.scopedKey(prefsKeyEveningReminderEnabled);
    return prefs.getBool(k) ?? false;
  }

  Future<void> setQuestEveningReminderEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final k = await UserScopedStore.scopedKey(prefsKeyEveningReminderEnabled);
    await prefs.setBool(k, value);
  }

  Future<(int hour, int minute)> getQuestEveningReminderClock() async {
    final prefs = await SharedPreferences.getInstance();
    final h =
        prefs.getInt(await UserScopedStore.scopedKey(prefsKeyEveningReminderHour));
    final m =
        prefs.getInt(await UserScopedStore.scopedKey(prefsKeyEveningReminderMinute));
    return (h ?? 20, m ?? 30);
  }

  Future<void> setQuestEveningReminderClock(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      await UserScopedStore.scopedKey(prefsKeyEveningReminderHour),
      hour.clamp(0, 23),
    );
    await prefs.setInt(
      await UserScopedStore.scopedKey(prefsKeyEveningReminderMinute),
      minute.clamp(0, 59),
    );
  }

  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool todayStepSatisfiedByPlusData({
    required AggregatedData data,
    required UserProfile profile,
    required String nextStepSphereId,
    required FoundationGoals goals,
  }) {
    final today = dayOnly(DateTime.now());
    final dayData = _subsetForSingleDay(data, today);
    final p = _sphereProgressForDay(
      data: dayData,
      day: today,
      goals: goals,
      sphereId: nextStepSphereId,
    );
    if (p != null && p > 0) return true;

    if (profile.hasConditions) {
      if (profile.conditions.contains(MentalCondition.bipolar)) {
        return _sphereProgressForDay(
              data: dayData,
              day: today,
              goals: goals,
              sphereId: FoundationSphereIds.sleep,
            ) !=
            null;
      }
      if (profile.conditions.contains(MentalCondition.anxiety)) {
        return _sphereProgressForDay(
                  data: dayData,
                  day: today,
                  goals: goals,
                  sphereId: FoundationSphereIds.mood,
                ) !=
                null ||
            dayData.stateEntries.any((e) => e is EmotionsEntry);
      }
      if (profile.conditions.contains(MentalCondition.depression)) {
        return _sphereProgressForDay(
              data: dayData,
              day: today,
              goals: goals,
              sphereId: FoundationSphereIds.mood,
            ) !=
            null;
      }
    }
    return false;
  }

  FoundationScore compute(
    AggregatedData data,
    FoundationGoals goals, {
    required String statsPeriodCaption,
  }) {
    final today = dayOnly(DateTime.now());
    final priorities = goals.priorities;

    final dailyScores = <double>[];
    for (var i = 0; i < trackingDays; i++) {
      final day = today.subtract(Duration(days: i));
      dailyScores.add(
        dailyFoundationScore(
          data: data,
          day: day,
          goals: goals,
        ),
      );
    }
    final overall =
        dailyScores.isEmpty ? 0.0 : dailyScores.reduce((a, b) => a + b) / dailyScores.length;
    final filled = (overall * totalBricks).round().clamp(0, totalBricks);

    final todayData = _subsetForSingleDay(data, today);
    final sphereScores = _buildTodaySphereScores(
      data: data,
      todayData: todayData,
      today: today,
      goals: goals,
      totalBricks: totalBricks,
      overall: overall,
    );

    final visibleSpheres = sphereScores;

    final weakest = [...visibleSpheres]
      ..sort((a, b) {
        final c = a.progress.compareTo(b.progress);
        if (c != 0) return c;
        return a.id.compareTo(b.id);
      });
    final nextSphereId =
        weakest.isEmpty ? FoundationSphereIds.mood : weakest.first.id;

    final prevWeekScores = <double>[];
    final currWeekScores = <double>[];
    for (var i = 7; i < 14; i++) {
      prevWeekScores.add(
        dailyFoundationScore(
          data: data,
          day: today.subtract(Duration(days: i)),
          goals: goals,
        ),
      );
    }
    for (var i = 0; i < 7; i++) {
      currWeekScores.add(
        dailyFoundationScore(
          data: data,
          day: today.subtract(Duration(days: i)),
          goals: goals,
        ),
      );
    }
    final prevAvg = prevWeekScores.isEmpty
        ? 0.0
        : prevWeekScores.reduce((a, b) => a + b) / prevWeekScores.length;
    final currAvg = currWeekScores.isEmpty
        ? 0.0
        : currWeekScores.reduce((a, b) => a + b) / currWeekScores.length;
    final delta7 =
        ((currAvg - prevAvg) * totalBricks).round();

    final (cracks, cracksWhy) = _riskCracksWithExplanation(data);
    final (history, historyDetails) = _history30d(data, goals);

    final hasState = data.stateEntries.isNotEmpty;
    final hasMed = data.medications.isNotEmpty;
    final hasAnySignal = hasState || hasMed;

    final daysWithLog = _daysWithFoundationActivity(data, goals);
    final confidenceCap = daysWithLog < 3;

    final (medRate, medCaption) = _medicationAdherenceToday(data, today);
    final streak = _consecutiveDaysWithStateOrMed(data, goals);
    final weeklySub = streak == 0
        ? 'Начните с одного дня с отметками через «+» или календарь.'
        : '${_pluralDaysRu(streak)} подряд с записями в приложении.';

    final String hint;
    if (!hasAnySignal) {
      hint =
          'Пока нет данных — отмечайте сон, настроение, энергию, питание в «+» и приёмы в календаре.';
    } else if (confidenceCap) {
      hint =
          'За последние $trackingDays дней мало отметок — прогресс растёт, когда заходите каждый день. Пропущенные дни снижают фундамент.';
    } else {
      hint =
          'Фундамент за $trackingDays дней: средний дневной прогресс по активным сферам. Пропущенный день — 0% за этот день.';
    }

    final stateCount = data.stateEntries.length;
    final calendarCount = data.medications.length + data.appointments.length;
    final dataSourcesSummary =
        'В расчёте: записей «+» $stateCount · календарь $calendarCount (заметки не учитываются)';

    const missionTitle = 'Фундамент — не диагноз';
    const missionBody = PrivacyCopy.foundationMissionBody;

    return FoundationScore(
      totalBricks: totalBricks,
      filledBricks: filled,
      overallProgress: overall,
      rawOverallProgress: overall,
      spheres: visibleSpheres,
      nextStep: _nextStepFor(nextSphereId),
      nextStepSphereId: nextSphereId,
      activityStreak: streak,
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
      weeklyFocusTitle: 'Регулярность',
      weeklyFocusSubtitle: weeklySub,
      medicationAdherenceRate: medRate,
      medicationAdherenceCaption: medCaption,
      statsPeriodCaption: statsPeriodCaption,
    );
  }

  /// Дневной прогресс 0–1: среднее по включённым сферам (без весов).
  static double dailyFoundationScore({
    required AggregatedData data,
    required DateTime day,
    required FoundationGoals goals,
  }) {
    final dayData = _subsetForSingleDay(data, dayOnly(day));
    final active = goals.priorities;
    var sum = 0.0;
    var count = 0;
    for (final id in FoundationSphereIds.ordered) {
      if (!active.isActive(id)) continue;
      final prog = _sphereProgressForDay(
        data: dayData,
        day: dayOnly(day),
        goals: goals,
        sphereId: id,
      );
      if (prog == null) continue;
      sum += prog;
      count++;
    }
    if (count == 0) return 0;
    return (sum / count).clamp(0.0, 1.0);
  }

  static double? _sphereProgressForDay({
    required AggregatedData data,
    required DateTime day,
    required FoundationGoals goals,
    required String sphereId,
  }) {
    if (!goals.priorities.isActive(sphereId)) return null;

    switch (sphereId) {
      case FoundationSphereIds.sleep:
        final entries = data.stateEntries.whereType<SleepEntry>().toList();
        if (entries.isEmpty) return 0;
        final e = entries.first;
        return _ratio(e.quality.toDouble(), goals.sleepTarget);
      case FoundationSphereIds.mood:
        final entries = data.stateEntries.whereType<MoodEntry>().toList();
        if (entries.isEmpty) return 0;
        return _ratio(entries.first.value.toDouble(), goals.moodTarget);
      case FoundationSphereIds.energy:
        final entries = data.stateEntries.whereType<EnergyEntry>().toList();
        if (entries.isEmpty) return 0;
        return _ratio(entries.first.level.toDouble(), goals.energyTarget);
      case FoundationSphereIds.nutrition:
        final entries = data.stateEntries.whereType<NutritionEntry>().toList();
        if (entries.isEmpty) return 0;
        return nutritionProgressForEntry(entries.first, goals);
      case FoundationSphereIds.medication:
        final meds = _medicationsOnDay(data, day);
        if (meds.isEmpty) return null;
        return _medicationProgress(meds);
      default:
        return null;
    }
  }

  List<FoundationSphereScore> _buildTodaySphereScores({
    required AggregatedData data,
    required AggregatedData todayData,
    required DateTime today,
    required FoundationGoals goals,
    required int totalBricks,
    required double overall,
  }) {
    final scores = <FoundationSphereScore>[];
    final activeCount = goals.priorities.activeCount;
    for (final id in FoundationSphereIds.ordered) {
      if (!goals.priorities.isActive(id)) continue;

      final progress =
          _sphereProgressForDay(
            data: todayData,
            day: today,
            goals: goals,
            sphereId: id,
          ) ??
          0.0;

      final (target, current, detail, logged, configurable) =
          _sphereTodayDetails(id, todayData, today, goals, data);

      scores.add(
        FoundationSphereScore(
          id: id,
          label: id.foundationLabel,
          target: target,
          current: current,
          progress: progress,
          brickContribution: activeCount == 0
              ? 0
              : ((progress * totalBricks) / activeCount).round(),
          loggedToday: logged,
          detailLine: detail,
          isConfigurable: configurable,
        ),
      );
    }
    return scores;
  }

  (
    double target,
    double current,
    String detail,
    bool logged,
    bool configurable,
  ) _sphereTodayDetails(
    String id,
    AggregatedData todayData,
    DateTime today,
    FoundationGoals goals,
    AggregatedData allData,
  ) {
    switch (id) {
      case FoundationSphereIds.sleep:
        final sleepList = todayData.stateEntries.whereType<SleepEntry>().toList();
        final e = sleepList.isEmpty ? null : sleepList.first;
        if (e == null) {
          return (
            goals.sleepTarget,
            0,
            'Сегодня нет записи — отметьте сон в «+»',
            false,
            true,
          );
        }
        return (
          goals.sleepTarget,
          e.quality.toDouble(),
          'Качество ${e.quality} / цель ${goals.sleepTarget.toStringAsFixed(1)}',
          true,
          true,
        );
      case FoundationSphereIds.mood:
        final moodList = todayData.stateEntries.whereType<MoodEntry>().toList();
        final e = moodList.isEmpty ? null : moodList.first;
        if (e == null) {
          return (
            goals.moodTarget,
            0,
            'Сегодня нет записи — отметьте настроение в «+»',
            false,
            true,
          );
        }
        return (
          goals.moodTarget,
          e.value.toDouble(),
          'Оценка ${e.value} / цель ${goals.moodTarget.toStringAsFixed(1)}',
          true,
          true,
        );
      case FoundationSphereIds.energy:
        final energyList = todayData.stateEntries.whereType<EnergyEntry>().toList();
        final e = energyList.isEmpty ? null : energyList.first;
        if (e == null) {
          return (
            goals.energyTarget,
            0,
            'Сегодня нет записи — отметьте энергию в «+»',
            false,
            true,
          );
        }
        return (
          goals.energyTarget,
          e.level.toDouble(),
          'Уровень ${e.level} / цель ${goals.energyTarget.toStringAsFixed(1)}',
          true,
          true,
        );
      case FoundationSphereIds.nutrition:
        final nutList = todayData.stateEntries.whereType<NutritionEntry>().toList();
        final e = nutList.isEmpty ? null : nutList.first;
        if (e == null) {
          final snackLine = goals.snackTarget > 0
              ? ', перекусов ${goals.snackTarget}'
              : '';
          return (
            100,
            0,
            'Цель: ${FoundationGoals.mainMealsTarget} приёма$snackLine — отметьте в «+»',
            false,
            true,
          );
        }
        final progress = nutritionProgressForEntry(e, goals);
        final mainCount = countMainMeals(e);
        final snackLine = goals.snackTarget > 0
            ? ' · перекусы ${e.snackCount.clamp(0, goals.snackTarget)}/${goals.snackTarget}'
            : '';
        return (
          100,
          progress * 100,
          'Приёмы $mainCount/${FoundationGoals.mainMealsTarget}$snackLine',
          mainCount > 0 || e.snackCount > 0,
          true,
        );
      case FoundationSphereIds.medication:
        final meds = _medicationsOnDay(allData, today);
        var expected = 0;
        var taken = 0;
        for (final m in meds) {
          final slots = m.schedule.isEmpty ? 1 : m.schedule.length;
          expected += slots;
          taken += _takenSlots(m);
        }
        if (expected == 0) {
          return (
            0,
            0,
            'На сегодня нет приёмов в календаре — добавьте препарат',
            false,
            false,
          );
        }
        return (
          expected.toDouble(),
          taken.toDouble(),
          'Отмечено $taken из $expected приёмов (календарь)',
          taken > 0,
          false,
        );
      default:
        return (0, 0, '', false, true);
    }
  }

  static List<Medication> _medicationsOnDay(AggregatedData data, DateTime day) {
    final d = dayOnly(day);
    return data.medications
        .where((m) => dayOnly(m.date) == d)
        .toList();
  }

  static int _takenSlots(Medication m) {
    if (m.schedule.isEmpty) {
      return m.takenAtPerDose.isNotEmpty && m.takenAtPerDose[0] != null ? 1 : 0;
    }
    var taken = 0;
    for (var i = 0; i < m.schedule.length; i++) {
      if (i < m.takenAtPerDose.length && m.takenAtPerDose[i] != null) {
        taken++;
      }
    }
    return taken;
  }

  static double _medicationProgress(List<Medication> meds) {
    var expected = 0;
    var taken = 0;
    for (final m in meds) {
      final slots = m.schedule.isEmpty ? 1 : m.schedule.length;
      expected += slots;
      taken += _takenSlots(m);
    }
    if (expected == 0) return 0;
    return (taken / expected).clamp(0.0, 1.0);
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

  String _nextStepFor(String sphereId) {
    switch (sphereId) {
      case FoundationSphereIds.sleep:
        return 'Шаг на сегодня: отметьте сон через «+».';
      case FoundationSphereIds.mood:
        return 'Шаг на сегодня: отметьте настроение в «+».';
      case FoundationSphereIds.energy:
        return 'Шаг на сегодня: отметьте энергию в «+».';
      case FoundationSphereIds.nutrition:
        return 'Шаг на сегодня: отметьте приёмы пищи в «+».';
      case FoundationSphereIds.medication:
        return 'Шаг на сегодня: отметьте приём препаратов в календаре.';
      default:
        return 'Шаг на сегодня: отметьте данные в «+» или календаре.';
    }
  }

  static double _ratio(double current, double target) {
    if (target <= 0) return 0;
    return (current / target).clamp(0.0, 1.0);
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
        'Среди 5 последних оценок много значений ниже 5 — сигнал для осторожности, не диагноз.',
      );
    }
    if (lowMood >= 3 || lowEnergy >= 3) {
      return (
        1,
        'Несколько последних отметок ниже 5 — при ухудшении обратитесь к врачу.',
      );
    }
    return (0, null);
  }

  (List<int>, List<FoundationHistoryDayDetail>) _history30d(
    AggregatedData data,
    FoundationGoals goals,
  ) {
    final out = <int>[];
    final details = <FoundationHistoryDayDetail>[];
    final today = dayOnly(DateTime.now());
    for (var day = historyDays - 1; day >= 0; day--) {
      final d = today.subtract(Duration(days: day));
      final score = dailyFoundationScore(data: data, day: d, goals: goals);
      final bricks = (score * totalBricks).round().clamp(0, totalBricks);
      out.add(bricks);
      final snap = _subsetForSingleDay(data, d);
      details.add(
        FoundationHistoryDayDetail(
          windowEndDay: d,
          bricks: bricks,
          stateCount: snap.stateEntries.length,
          calendarCount: snap.medications.length + snap.appointments.length,
          dailyScorePercent: (score * 100).round(),
        ),
      );
    }
    return (out, details);
  }

  (double? rate, String caption) _medicationAdherenceToday(
    AggregatedData d,
    DateTime today,
  ) {
    final meds = _medicationsOnDay(d, today);
    if (meds.isEmpty) return (null, '');
    final progress = _medicationProgress(meds);
    var expected = 0;
    var taken = 0;
    for (final m in meds) {
      final slots = m.schedule.isEmpty ? 1 : m.schedule.length;
      expected += slots;
      taken += _takenSlots(m);
    }
    return (
      progress,
      'Сегодня в календаре: $taken из $expected приёмов (${(progress * 100).round()}%).',
    );
  }

  int _daysWithFoundationActivity(AggregatedData data, FoundationGoals goals) {
    final today = dayOnly(DateTime.now());
    var count = 0;
    for (var i = 0; i < trackingDays; i++) {
      final day = today.subtract(Duration(days: i));
      if (dailyFoundationScore(data: data, day: day, goals: goals) > 0) {
        count++;
      }
    }
    return count;
  }

  int _consecutiveDaysWithStateOrMed(AggregatedData d, FoundationGoals goals) {
    final today = dayOnly(DateTime.now());
    var streak = 0;
    for (var i = 0; i < 400; i++) {
      final day = today.subtract(Duration(days: i));
      if (dailyFoundationScore(data: d, day: day, goals: goals) > 0) {
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

  static const _mainMealNames = {'ЗАВТРАК', 'ОБЕД', 'УЖИН'};

  /// Сколько из трёх основных приёмов отмечено.
  static int countMainMeals(NutritionEntry entry) {
    return entry.meals
        .map((m) => m.toUpperCase())
        .where(_mainMealNames.contains)
        .toSet()
        .length;
  }

  /// Прогресс питания: все 3 приёма обязательны для 100%; перекусы — к цели из настроек.
  static double nutritionProgressForEntry(
    NutritionEntry entry,
    FoundationGoals goals,
  ) {
    final mainMarked =
        countMainMeals(entry).clamp(0, FoundationGoals.mainMealsTarget);
    final mealPart = mainMarked / FoundationGoals.mainMealsTarget;
    final snackTarget = goals.snackTarget;
    final snackPart = snackTarget <= 0
        ? 1.0
        : entry.snackCount.clamp(0, snackTarget) / snackTarget;
    return (mealPart * snackPart).clamp(0.0, 1.0);
  }

  static AggregatedData _subsetForSingleDay(AggregatedData data, DateTime day) {
    final d = dayOnly(day);
    bool same(DateTime t) => dayOnly(t) == d;
    return AggregatedData(
      notes: const [],
      stateEntries:
          data.stateEntries.where((s) => same(s.createdAt)).toList(),
      medications: data.medications.where((m) => same(m.date)).toList(),
      appointments: data.appointments.where((a) => same(a.date)).toList(),
    );
  }
}
