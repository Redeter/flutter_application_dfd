import 'dart:convert';

import '../models/aggregated_data.dart';
import '../models/calendar_entry.dart';
import '../models/insight_result.dart';
import '../models/note_item.dart';
import '../models/state_entries.dart';
import '../models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'calendar_storage.dart';
import 'insight_safety_service.dart';
import 'local_insights_service.dart';
import '../neural/neural_insights_service.dart';
import 'notes_storage.dart';
import 'quality_metrics_service.dart';
import 'recommendation_personalizer.dart';
import 'state_storage.dart';
import 'user_profile_service.dart';
import 'user_scoped_store.dart';

/// Агрегирует все данные и получает инсайты для экрана статистики.
/// Выводы строятся локально на устройстве; записи синхронизируются с Firebase.
class InsightsService {
  static const _keyAbMode = 'insights_ab_mode';
  static const _keyAbUpdatedAt = 'insights_ab_updated_at';
  static const _keyAbManualMode = 'insights_ab_manual_mode';
  static const _keyRecFeedback = 'qm_rec_feedback_v1';
  static const _keyPersonalLexicon = 'insights_personal_lexicon_v1';

  InsightsService._();
  static InsightsService get instance => _instance;
  static final _instance = InsightsService._();

  Future<AggregatedData> aggregateData({
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) async {
    final notes = _dedupeNotesNoise(await NotesStorage.instance.loadAll());
    final stateEntries = await StateStorage.instance.loadAll();
    final calendarEntries = await CalendarStorage.instance.loadAll();

    var data = AggregatedData(
      notes: notes,
      stateEntries: stateEntries,
      medications: calendarEntries.whereType<Medication>().toList(),
      appointments: calendarEntries.whereType<Appointment>().toList(),
    );
    if (rangeStart != null && rangeEnd != null) {
      data = data.filterByInclusiveDayRange(rangeStart, rangeEnd);
    }
    return data;
  }

  /// Локальный анализ нейросетью: ключевые слова, резюме, выводы, рекомендации.
  /// Самописная нейросеть анализирует заметки и записи о состоянии.
  Future<InsightResult> getInsights(AggregatedData data) async {
    final mode = await _resolveAbMode();
    InsightResult result;
    if (mode == 'rule') {
      result = await LocalInsightsService.instance.getInsights(data);
    } else {
      result = await NeuralInsightsService.instance.getInsights(data);
    }
    final calibrated = await _withCalibratedConfidence(result);
    final enriched = await _enrichResult(calibrated, data);
    return InsightSafetyService.instance.apply(enriched);
  }

  Future<InsightResult> _withCalibratedConfidence(InsightResult input) async {
    final calibratedConfidence =
        await QualityMetricsService.instance.calibrateConfidence(input.confidence);
    return InsightResult(
      keywords: input.keywords,
      stateSummary: input.stateSummary,
      overallInsight: input.overallInsight,
      recommendations: input.recommendations,
      recommendationReasons: input.recommendationReasons,
      confidence: calibratedConfidence,
      dataQualityScore: input.dataQualityScore,
      insufficientData: input.insufficientData,
      personalizationScores: input.personalizationScores,
      recommendationScores: input.recommendationScores,
      weeklyDigest: input.weeklyDigest,
      burnoutAlert: input.burnoutAlert,
      topTriggers: input.topTriggers,
      causalInsights: input.causalInsights,
      confidenceReasons: input.confidenceReasons,
      recommendationExplanations: input.recommendationExplanations,
      recommendationVariantKeys: input.recommendationVariantKeys,
      error: input.error,
    );
  }

  Future<InsightResult> _enrichResult(InsightResult input, AggregatedData data) async {
    final profile = await UserProfileService.instance.load();
    final baselineLine = _baselineNarrative(data);
    final weeklyDigest = _buildWeeklyDigest(data);
    final topTriggers = await _computeWeeklyTriggersWithLexicon(data);
    final causal = _computeLagInsights(data);
    final burnout = _burnoutAlert(data, topTriggers, causal, profile.conditions);
    final confidenceReasons = _buildConfidenceReasons(data, input.confidence);
    final rewritten = await _rewriteRecommendationsForExperiment(
      _profileAwareRecommendations(input.recommendations, profile.conditions),
    );
    final remappedReasons = <String, List<String>>{};
    final recExplanations = <String, String>{};
    final shownRecs = <String>[];
    final variantKeys = <String>[];
    for (var i = 0; i < rewritten.length; i++) {
      final oldRec = i < input.recommendations.length ? input.recommendations[i] : rewritten[i];
      final newRec = rewritten[i];
      final reasons = input.recommendationReasons[oldRec] ?? const <String>[];
      final rendered =
          await RecommendationPersonalizer.instance.render(newRec, data, profile);
      final shown = rendered.text;
      shownRecs.add(shown);
      variantKeys.add(rendered.variantKey);
      remappedReasons[shown] = reasons;
      final short = reasons.take(2).join('; ');
      recExplanations[shown] = short.isEmpty ? 'Основано на динамике последних дней.' : short;
    }

    final remappedScores = <String, double>{};
    for (var i = 0; i < shownRecs.length; i++) {
      final oldRec = i < input.recommendations.length ? input.recommendations[i] : rewritten[i];
      final newRec = rewritten[i];
      final shown = shownRecs[i];
      final sk = input.recommendationScores.containsKey(oldRec)
          ? oldRec
          : (input.recommendationScores.containsKey(newRec) ? newRec : null);
      remappedScores[shown] = sk != null
          ? input.recommendationScores[sk]!
          : (input.recommendationScores[newRec] ?? 0.5);
    }

    final extraOverall = [
      input.overallInsight,
      if (baselineLine.isNotEmpty) baselineLine,
      if (profile.hasConditions) 'Режим профиля: ${profile.conditions.map((e) => e.label).join(', ')}.',
      if (causal.isNotEmpty) 'Связи по времени: ${causal.take(2).join(' ')}',
    ].where((e) => e.trim().isNotEmpty).join(' ');

    return InsightResult(
      keywords: input.keywords,
      stateSummary: input.stateSummary,
      overallInsight: extraOverall,
      recommendations: shownRecs,
      recommendationReasons: remappedReasons,
      confidence: input.confidence,
      dataQualityScore: input.dataQualityScore,
      insufficientData: input.insufficientData,
      personalizationScores: input.personalizationScores,
      recommendationScores: remappedScores,
      weeklyDigest: weeklyDigest,
      burnoutAlert: burnout,
      topTriggers: topTriggers,
      causalInsights: causal,
      confidenceReasons: confidenceReasons,
      recommendationExplanations: recExplanations,
      recommendationVariantKeys: variantKeys,
      error: input.error,
    );
  }

  List<String> _profileAwareRecommendations(
    List<String> recs,
    List<MentalCondition> conditions,
  ) {
    final out = [...recs];
    bool has(MentalCondition c) => conditions.contains(c);
    if (has(MentalCondition.bipolar)) {
      out.add('Стабилизируйте ритм сна: одинаковое время подъема и отбоя в ближайшие 3 дня.');
    }
    if (has(MentalCondition.depression)) {
      out.add('Сделайте один маленький активирующий шаг сегодня и зафиксируйте эффект в заметке.');
    }
    if (has(MentalCondition.anxiety)) {
      out.add('При росте тревоги используйте 3-минутное дыхание и отметьте триггер.');
    }
    if (has(MentalCondition.bpd)) {
      out.add('При резкой эмоции примените паузу STOP: стоп, дыхание, наблюдение, действие.');
    }
    if (has(MentalCondition.ed)) {
      out.add('Поддерживайте регулярный режим питания и отмечайте самочувствие без оценочных ярлыков.');
    }
    if (has(MentalCondition.ptsd)) {
      out.add('При перегрузке используйте мягкое заземление 5-4-3-2-1 и снизьте стимулы.');
    }
    final seen = <String>{};
    return out.where(seen.add).take(5).toList();
  }

  List<NoteItem> _dedupeNotesNoise(List<NoteItem> notes) {
    if (notes.length < 2) return notes;
    final sorted = [...notes]..sort((a, b) => a.date.compareTo(b.date));
    final out = <NoteItem>[];
    final titleDayCounts = <String, int>{};
    for (final note in sorted) {
      final text = '${note.title} ${note.preview}'.toLowerCase().trim();
      final titleKey =
          '${note.date.year}-${note.date.month}-${note.date.day}:${note.title.trim().toLowerCase()}';
      final prev = out.isEmpty ? null : out.last;
      if (prev != null) {
        final sameDay = prev.date.year == note.date.year &&
            prev.date.month == note.date.month &&
            prev.date.day == note.date.day;
        final prevText = '${prev.title} ${prev.preview}'.toLowerCase();
        final sim = _jaccard(prevText, text);
        if (sameDay && sim >= 0.78) {
          continue;
        }
        final nearDupAdjacent = !sameDay &&
            sim >= 0.92 &&
            note.date.difference(prev.date).inDays.abs() <= 2;
        if (nearDupAdjacent) {
          continue;
        }
      }
      if (note.preview.trim().length < 6 && note.title.trim().length < 14) {
        final c = (titleDayCounts[titleKey] ?? 0) + 1;
        titleDayCounts[titleKey] = c;
        if (c >= 3) {
          continue;
        }
      }
      out.add(note);
    }
    return out..sort((a, b) => b.date.compareTo(a.date));
  }

  double _jaccard(String a, String b) {
    final wa = RegExp(r'[а-яёa-z0-9]+', caseSensitive: false)
        .allMatches(a)
        .map((m) => m.group(0)!)
        .toSet();
    final wb = RegExp(r'[а-яёa-z0-9]+', caseSensitive: false)
        .allMatches(b)
        .map((m) => m.group(0)!)
        .toSet();
    if (wa.isEmpty || wb.isEmpty) return 0;
    final inter = wa.intersection(wb).length.toDouble();
    final union = wa.union(wb).length.toDouble();
    return inter / union;
  }

  String _baselineNarrative(AggregatedData data) {
    final moods = data.stateEntries.whereType<MoodEntry>().toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (moods.length < 10) return '';
    final splitDate = DateTime.now().subtract(const Duration(days: 14));
    final baseline = moods.where((m) => m.createdAt.isBefore(splitDate)).toList();
    final recent = moods.where((m) => !m.createdAt.isBefore(splitDate)).toList();
    if (baseline.length < 4 || recent.length < 3) return '';
    final baseAvg = baseline.map((e) => e.value).reduce((a, b) => a + b) / baseline.length;
    final recentAvg = recent.map((e) => e.value).reduce((a, b) => a + b) / recent.length;
    final delta = recentAvg - baseAvg;
    if (delta.abs() < 0.45) return 'Последние 14 дней близки к вашей личной норме.';
    if (delta > 0) return 'Последние 14 дней выше вашей долгосрочной нормы примерно на ${delta.toStringAsFixed(1)} балла.';
    return 'Последние 14 дней ниже вашей долгосрочной нормы примерно на ${delta.abs().toStringAsFixed(1)} балла.';
  }

  String _buildWeeklyDigest(AggregatedData data) {
    DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    final today = dayOnly(DateTime.now());
    final recentStart = today.subtract(const Duration(days: 6));
    final prevStart = today.subtract(const Duration(days: 13));
    final prevEnd = today.subtract(const Duration(days: 7));
    double avg<T extends StateEntryBase>(
      Iterable<T> list,
      int Function(T) getValue,
      DateTime Function(T) getDate, {
      required bool recent,
    }) {
      final scoped = list.where((e) {
        final d = dayOnly(getDate(e));
        return recent
            ? (!d.isBefore(recentStart) && !d.isAfter(today))
            : (!d.isBefore(prevStart) && !d.isAfter(prevEnd));
      }).toList();
      if (scoped.isEmpty) return 0;
      return scoped.map(getValue).reduce((a, b) => a + b) / scoped.length;
    }

    final moodEntries = data.stateEntries.whereType<MoodEntry>();
    final sleepEntries = data.stateEntries.whereType<SleepEntry>();
    final energyEntries = data.stateEntries.whereType<EnergyEntry>();
    final moodDelta = avg(moodEntries, (e) => e.value, (e) => e.createdAt, recent: true) -
        avg(moodEntries, (e) => e.value, (e) => e.createdAt, recent: false);
    final sleepDelta = avg(sleepEntries, (e) => e.quality, (e) => e.createdAt, recent: true) -
        avg(sleepEntries, (e) => e.quality, (e) => e.createdAt, recent: false);
    final energyDelta = avg(energyEntries, (e) => e.level, (e) => e.createdAt, recent: true) -
        avg(energyEntries, (e) => e.level, (e) => e.createdAt, recent: false);

    String trend(double delta, String label) {
      if (delta > 0.35) return '$label улучшилось';
      if (delta < -0.35) return '$label просело';
      return '$label стабильно';
    }

    return '${trend(moodDelta, 'Настроение')}, ${trend(sleepDelta, 'сон')}, ${trend(energyDelta, 'энергия')}.';
  }

  List<String> _computeWeeklyTriggers(AggregatedData data) {
    final from = DateTime.now().subtract(const Duration(days: 7));
    final counts = <String, int>{};
    const map = <String, List<String>>{
      'сон': ['сон', 'бессон', 'отбой', 'пробуж'],
      'работа': ['работ', 'дедлайн', 'офис', 'проект'],
      'отношения': ['конфликт', 'семья', 'партнер', 'друз'],
      'стресс': ['стресс', 'тревог', 'паник', 'напряж'],
      'здоровье': ['врач', 'бол', 'симптом', 'самочув'],
      'восстановление': ['прогул', 'спорт', 'отдых', 'медитац'],
    };
    for (final n in data.notes.where((n) => !n.date.isBefore(from))) {
      final text = '${n.title} ${n.preview} ${n.tags.join(' ')}'.toLowerCase();
      for (final entry in map.entries) {
        if (entry.value.any(text.contains)) {
          counts[entry.key] = (counts[entry.key] ?? 0) + 1;
        }
      }
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).map((e) => '${e.key} (${e.value})').toList();
  }

  Future<List<String>> _computeWeeklyTriggersWithLexicon(AggregatedData data) async {
    final direct = _computeWeeklyTriggers(data);
    final lex = await _updateAndLoadPersonalLexicon(data);
    if (lex.isEmpty) return direct;
    final fromLex = lex.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final merged = <String>[
      ...direct,
      ...fromLex.take(2).map((e) => '${e.key} (${e.value})'),
    ];
    final unique = <String>[];
    final seen = <String>{};
    for (final item in merged) {
      final key = item.split(' ').first;
      if (seen.add(key)) unique.add(item);
    }
    return unique.take(3).toList();
  }

  Future<Map<String, int>> _updateAndLoadPersonalLexicon(
    AggregatedData data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final lexKey = await UserScopedStore.scopedKey(_keyPersonalLexicon);
    final current = <String, int>{};
    final raw = prefs.getString(lexKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        for (final e in m.entries) {
          current[e.key] = (e.value as num?)?.toInt() ?? 0;
        }
      } catch (_) {}
    }

    final from = DateTime.now().subtract(const Duration(days: 14));
    for (final n in data.notes.where((n) => !n.date.isBefore(from))) {
      final words = RegExp(r'[а-яёa-z]{4,}', caseSensitive: false)
          .allMatches('${n.title} ${n.preview}'.toLowerCase())
          .map((m) => m.group(0)!)
          .where((w) => !_stopWords.contains(w))
          .toSet();
      for (final w in words) {
        current[w] = (current[w] ?? 0) + 1;
      }
    }
    final sorted = current.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final trimmed = {
      for (final e in sorted.take(50)) e.key: e.value,
    };
    await prefs.setString(lexKey, jsonEncode(trimmed));
    return trimmed;
  }

  static const _stopWords = {
    'и', 'в', 'на', 'с', 'по', 'для', 'из', 'к', 'о', 'от', 'до', 'за', 'у',
    'при', 'не', 'нет', 'да', 'это', 'как', 'что', 'то', 'так', 'же', 'или',
    'если', 'когда', 'чтобы', 'потом', 'было', 'были', 'после',
  };

  List<String> _computeLagInsights(AggregatedData data) {
    final sleepByDay = <DateTime, double>{};
    final moodByDay = <DateTime, double>{};
    final energyByDay = <DateTime, double>{};
    DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
    for (final s in data.stateEntries.whereType<SleepEntry>()) {
      sleepByDay[day(s.createdAt)] = s.quality.toDouble();
    }
    for (final m in data.stateEntries.whereType<MoodEntry>()) {
      moodByDay[day(m.createdAt)] = m.value.toDouble();
    }
    for (final e in data.stateEntries.whereType<EnergyEntry>()) {
      energyByDay[day(e.createdAt)] = e.level.toDouble();
    }
    final out = <String>[];
    int linked1 = 0;
    int base1 = 0;
    int linked2 = 0;
    int base2 = 0;
    for (final entry in sleepByDay.entries) {
      final d1 = entry.key.add(const Duration(days: 1));
      final d2 = entry.key.add(const Duration(days: 2));
      final lowSleep = entry.value < 6;
      if (moodByDay.containsKey(d1)) {
        base1++;
        if (lowSleep && (moodByDay[d1]! < 6 || (energyByDay[d1] ?? 10) < 6)) linked1++;
      }
      if (moodByDay.containsKey(d2)) {
        base2++;
        if (lowSleep && (moodByDay[d2]! < 6 || (energyByDay[d2] ?? 10) < 6)) linked2++;
      }
    }
    if (base1 >= 4 && linked1 / base1 >= 0.5) {
      out.add('плохой сон часто влияет на следующий день (t+1)');
    }
    if (base2 >= 4 && linked2 / base2 >= 0.45) {
      out.add('эффект сна заметен и через 2 дня (t+2)');
    }
    return out;
  }

  String _burnoutAlert(
    AggregatedData data,
    List<String> triggers,
    List<String> causal,
    List<MentalCondition> conditions,
  ) {
    final moods = data.stateEntries.whereType<MoodEntry>().toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final energies = data.stateEntries.whereType<EnergyEntry>().toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (moods.length < 4 || energies.length < 4) return '';
    final stricter = conditions.contains(MentalCondition.bipolar) ||
        conditions.contains(MentalCondition.depression) ||
        conditions.contains(MentalCondition.bpd);
    final threshold = stricter ? 2 : 3;
    final streakMoodCount = moods.reversed.take(5).where((m) => m.value < 5).length;
    final streakEnergyCount = energies.reversed.take(5).where((e) => e.level < 5).length;
    if (streakMoodCount < threshold && streakEnergyCount < threshold) return '';
    final triggerText = triggers.isEmpty ? 'нагрузку и режим' : triggers.first;
    final nextStep = causal.isEmpty ? 'сфокусируйтесь на сне и коротких паузах.' : 'проверьте режим сна и восстановление в ближайшие 2 дня.';
    return 'Мягкий риск выгорания: последние дни нестабильны. Частый триггер — $triggerText, next step: $nextStep';
  }

  List<String> _buildConfidenceReasons(AggregatedData data, double confidence) {
    final days = _observationDays(data);
    final total = data.notes.length + data.stateEntries.length;
    final coverage = days == 0 ? 0 : total / days;
    final reasons = <String>[
      'дней наблюдений: $days',
      'объем данных: $total записей',
      'покрытие: ${coverage.toStringAsFixed(1)} записи/день',
    ];
    if (confidence < 0.45) {
      reasons.add('сигналы пока нестабильны');
    } else if (confidence >= 0.72) {
      reasons.add('сигналы согласованы между заметками и состояниями');
    } else {
      reasons.add('часть сигналов согласована, часть требует больше данных');
    }
    return reasons;
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

  Future<List<String>> _rewriteRecommendationsForExperiment(List<String> recs) async {
    final prefs = await SharedPreferences.getInstance();
    final fbKey = await UserScopedStore.scopedKey(_keyRecFeedback);
    final variant = await _resolveRecommendationVariant(prefs, fbKey);
    return recs.map((rec) {
      if (variant == 'supportive') {
        return rec
            .replaceFirst('Обратите внимание на', 'Попробуйте мягко улучшить')
            .replaceFirst('Не забывайте', 'Поддерживайте')
            .replaceFirst('При ', 'Если замечаете ');
      }
      return rec;
    }).toList();
  }

  Future<String> _resolveRecommendationVariant(
    SharedPreferences prefs,
    String fbKey,
  ) async {
    final raw = prefs.getString(fbKey);
    if (raw == null || raw.isEmpty) return 'default';
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (list.length < 12) return 'default';
      final helpfulRate = list.where((e) => e['helpful'] == true).length / list.length;
      return helpfulRate < 0.4 ? 'supportive' : 'default';
    } catch (_) {
      return 'default';
    }
  }

  Future<String> _resolveAbMode() async {
    final prefs = await SharedPreferences.getInstance();
    final manualKey = await UserScopedStore.scopedKey(_keyAbManualMode);
    final updatedKey = await UserScopedStore.scopedKey(_keyAbUpdatedAt);
    final modeKey = await UserScopedStore.scopedKey(_keyAbMode);
    final manual = prefs.getString(manualKey);
    if (manual == null || manual.isEmpty) {
      await prefs.setString(manualKey, 'ml');
      return 'ml';
    }
    if (manual != 'auto') {
      return manual;
    }
    final now = DateTime.now();
    final updatedAtRaw = prefs.getString(updatedKey);
    final mode = prefs.getString(modeKey);
    if (updatedAtRaw != null && mode != null) {
      final updatedAt = DateTime.tryParse(updatedAtRaw);
      if (updatedAt != null && now.difference(updatedAt).inDays < 1) {
        return mode;
      }
    }

    // Simple on-device A/B: alternate by day to compare rule-only vs rule+ML.
    final nextMode = now.day.isEven ? 'ml' : 'rule';
    await prefs.setString(modeKey, nextMode);
    await prefs.setString(updatedKey, now.toIso8601String());
    return nextMode;
  }

  Future<void> setManualAbMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    final manualKey = await UserScopedStore.scopedKey(_keyAbManualMode);
    await prefs.setString(manualKey, mode);
  }

  Future<String> getManualAbMode() async {
    final prefs = await SharedPreferences.getInstance();
    final manualKey = await UserScopedStore.scopedKey(_keyAbManualMode);
    return prefs.getString(manualKey) ?? 'ml';
  }
}
