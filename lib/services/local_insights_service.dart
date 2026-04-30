import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/aggregated_data.dart';
import '../models/insight_result.dart';
import '../models/state_entries.dart';

/// Локальный анализ без облака. Извлекает ключевые слова, формирует резюме
/// и рекомендации. Паттерны сохраняются и «обучают» систему под пользователя.
class LocalInsightsService {
  LocalInsightsService._();
  static LocalInsightsService get instance => _instance;
  static final _instance = LocalInsightsService._();

  static const _keyPatterns = 'local_insights_patterns';

  /// Слова, которые пропускаем при извлечении ключевых слов.
  static const _stopWords = {
    'и', 'в', 'на', 'с', 'по', 'для', 'из', 'к', 'о', 'от', 'до', 'за', 'у',
    'при', 'не', 'нет', 'да', 'это', 'как', 'что', 'то', 'так', 'же', 'или',
    'а', 'но', 'бы', 'ли', 'уже', 'ещё', 'все', 'всё', 'мне', 'меня',
    'себя', 'тебя', 'его', 'её', 'них', 'мой', 'твой', 'наш', 'ваш',
  };

  /// Слова, отражающие эмоциональное/психологическое состояние.
  static const _emotionWords = {
    'хорошо', 'плохо', 'грустно', 'радость', 'рад', 'счастлив', 'счастье',
    'усталость', 'устал', 'устала', 'энергия', 'энергичен', 'спокойствие',
    'тревога', 'тревожность', 'страх', 'злость', 'злой', 'раздражение',
    'спокойный', 'волнение', 'волнуюсь', 'напряжение', 'напряжён',
    'сон', 'сплю', 'бессонница', 'отдых', 'отдохнул', 'вымотан',
    'мотивация', 'лень', 'апатия', 'интерес', 'скука', 'надежда',
    'разочарование', 'обида', 'благодарность', 'любовь', 'одиночество',
    'стресс', 'расслабление', 'медитация', 'спорт', 'прогулка',
  };

  Future<InsightResult> getInsights(AggregatedData data) async {
    if (data.notes.isEmpty &&
        data.stateEntries.isEmpty &&
        data.medications.isEmpty &&
        data.appointments.isEmpty) {
      return const InsightResult(
        keywords: [],
        stateSummary: '',
        overallInsight: '',
        recommendations: [],
      );
    }

    final quality = _dataQualityScore(data);
    final observationDays = _observationDays(data);
    if (observationDays < 7 || quality < 0.45) {
      return InsightResult(
        keywords: _extractKeywords(data).take(5).toList(),
        stateSummary: 'Пока недостаточно качественных данных для устойчивого анализа.',
        overallInsight: 'Добавляйте регулярные записи в течение хотя бы 7 дней.',
        recommendations: const ['Продолжайте вести записи — система станет точнее.'],
        confidence: (quality * 0.6).clamp(0.0, 0.6),
        dataQualityScore: quality,
        insufficientData: true,
      );
    }

    final keywords = _extractKeywords(data);
    final (stateSummary, overallInsight) = await _buildSummaries(data);
    final recommendations = await _buildRecommendations(data);
    final reasons = _buildRecommendationReasons(data, recommendations);

    await _updatePatterns(data);

    return InsightResult(
      keywords: keywords,
      stateSummary: stateSummary,
      overallInsight: overallInsight,
      recommendations: recommendations,
      recommendationReasons: reasons,
      confidence: _estimateConfidence(data, quality),
      dataQualityScore: quality,
    );
  }

  double _estimateConfidence(AggregatedData d, double quality) {
    final coverage = ((d.stateEntries.length + d.notes.length) / 40).clamp(0.0, 1.0);
    final richness = _observationDays(d) >= 7 ? 1.0 : 0.4;
    return (0.45 * quality + 0.4 * coverage + 0.15 * richness).clamp(0.0, 1.0);
  }

  int _observationDays(AggregatedData d) {
    DateTime? minDate;
    DateTime? maxDate;
    for (final n in d.notes) {
      minDate = minDate == null || n.date.isBefore(minDate) ? n.date : minDate;
      maxDate = maxDate == null || n.date.isAfter(maxDate) ? n.date : maxDate;
    }
    for (final e in d.stateEntries) {
      minDate = minDate == null || e.createdAt.isBefore(minDate) ? e.createdAt : minDate;
      maxDate = maxDate == null || e.createdAt.isAfter(maxDate) ? e.createdAt : maxDate;
    }
    if (minDate == null || maxDate == null) return 0;
    return maxDate.difference(minDate).inDays + 1;
  }

  double _dataQualityScore(AggregatedData d) {
    final total = (d.notes.length + d.stateEntries.length).toDouble();
    if (total == 0) return 0;

    var scoreSum = 0.0;
    for (final n in d.notes) {
      final text = '${n.title} ${n.preview}'.trim();
      final lenScore = (text.length / 80).clamp(0.0, 1.0);
      final tagsScore = n.tags.isNotEmpty ? 1.0 : 0.6;
      final spamPenalty = _looksSpam(text) ? 0.4 : 1.0;
      scoreSum += (0.7 * lenScore + 0.3 * tagsScore) * spamPenalty;
    }
    for (final e in d.stateEntries) {
      scoreSum += _stateEntryQuality(e);
    }
    return (scoreSum / total).clamp(0.0, 1.0);
  }

  bool _looksSpam(String text) {
    if (text.isEmpty) return true;
    final compact = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length < 4) return true;
    final repeatedChars = RegExp(r'(.)\1{5,}').hasMatch(compact);
    return repeatedChars;
  }

  double _stateEntryQuality(StateEntryBase e) {
    switch (e) {
      case MoodEntry(:final value, :final factors):
        if (value < 1 || value > 10) return 0;
        return factors.isNotEmpty ? 1.0 : 0.75;
      case SleepEntry(:final quality, :final tags):
        if (quality < 1 || quality > 10) return 0;
        return tags.isNotEmpty ? 1.0 : 0.8;
      case EnergyEntry(:final level, :final factors):
        if (level < 1 || level > 10) return 0;
        return factors.isNotEmpty ? 1.0 : 0.8;
      case EmotionsEntry(:final emotions):
        return emotions.isEmpty ? 0.5 : 1.0;
      case NutritionEntry(:final meals, :final sensations, :final emotionalConnection):
        final filled = [
          meals.isNotEmpty,
          sensations.isNotEmpty,
          emotionalConnection.isNotEmpty,
        ].where((v) => v).length;
        return (0.5 + filled / 6).clamp(0.0, 1.0);
      default:
        return 0.7;
    }
  }

  Map<String, List<String>> _buildRecommendationReasons(
    AggregatedData d,
    List<String> recommendations,
  ) {
    final reasons = <String, List<String>>{};
    final moodValues = d.stateEntries.whereType<MoodEntry>().map((e) => e.value).toList();
    final sleepValues = d.stateEntries.whereType<SleepEntry>().map((e) => e.quality).toList();
    final energyValues = d.stateEntries.whereType<EnergyEntry>().map((e) => e.level).toList();
    final recentLowSleep = sleepValues.where((v) => v < 6).length;
    final recentLowMood = moodValues.where((v) => v < 5).length;
    final recentLowEnergy = energyValues.where((v) => v < 5).length;
    final anxiousWords = _extractKeywords(d).where((w) =>
        w.contains('трев') || w.contains('стресс') || w.contains('устал')).length;

    for (final rec in recommendations) {
      final r = <String>[];
      if (rec.contains('сна') && recentLowSleep > 0) {
        r.add('обнаружено дней с низким качеством сна: $recentLowSleep');
      }
      if (rec.contains('энерг') && recentLowEnergy > 0) {
        r.add('часто фиксируется низкая энергия: $recentLowEnergy записей');
      }
      if (rec.contains('настроен') && recentLowMood > 0) {
        r.add('есть повторяющиеся записи со сниженным настроением');
      }
      if (rec.contains('замет') && anxiousWords > 0) {
        r.add('в тексте заметок встречаются тревожные маркеры');
      }
      if (r.isEmpty) {
        r.add('рекомендация основана на суммарном тренде последних записей');
      }
      reasons[rec] = r.take(3).toList();
    }
    return reasons;
  }

  List<String> _extractKeywords(AggregatedData d) {
    final candidates = <String, int>{};
    final allText = StringBuffer();

    for (final n in d.notes) {
      allText.writeln('${n.title} ${n.preview} ${n.tags.join(' ')}');
    }
    for (final e in d.stateEntries) {
      switch (e) {
        case MoodEntry(factors: final factors):
          for (final f in factors) {
            candidates[f.toLowerCase()] = (candidates[f.toLowerCase()] ?? 0) + 2;
          }
        case EmotionsEntry(emotions: final ems):
          for (final em in ems) {
            candidates[em.toLowerCase()] = (candidates[em.toLowerCase()] ?? 0) + 3;
          }
        case SleepEntry(tags: final tags):
          for (final t in tags) {
            candidates[t.toLowerCase()] = (candidates[t.toLowerCase()] ?? 0) + 2;
          }
        case NutritionEntry(sensations: final sens, emotionalConnection: final emotConn):
          for (final s in sens) {
            candidates[s.toLowerCase()] = (candidates[s.toLowerCase()] ?? 0) + 1;
          }
          for (final ec in emotConn) {
            candidates[ec.toLowerCase()] = (candidates[ec.toLowerCase()] ?? 0) + 2;
          }
        case EnergyEntry(character: final char, factors: final factors):
          if (char != null) {
            candidates[char.toLowerCase()] = (candidates[char.toLowerCase()] ?? 0) + 2;
          }
          for (final f in factors) {
            candidates[f.toLowerCase()] = (candidates[f.toLowerCase()] ?? 0) + 1;
          }
        default:
          break;
      }
    }

    final words = RegExp(r'[а-яёa-z]+', caseSensitive: false)
        .allMatches(allText.toString())
        .map((m) => m.group(0)!.toLowerCase())
        .where((w) => w.length > 2 && !_stopWords.contains(w));

    for (final w in words) {
      if (_emotionWords.contains(w) || w.length >= 4) {
        candidates[w] = (candidates[w] ?? 0) + 1;
      }
    }

    final sorted = candidates.entries
        .where((e) => e.value >= 1)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(10).map((e) => e.key).toList();
  }

  Future<(String, String)> _buildSummaries(AggregatedData d) async {
    double? avgMood;
    double? avgSleep;
    double? avgEnergy;
    int moodCount = 0, sleepCount = 0, energyCount = 0;
    double moodSum = 0, sleepSum = 0, energySum = 0;
    final emotions = <String>[];

    for (final e in d.stateEntries) {
      switch (e) {
        case MoodEntry(:final value):
          moodSum += value;
          moodCount++;
        case EmotionsEntry(emotions: final ems):
          emotions.addAll(ems);
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

    final parts = <String>[];
    if (avgMood != null) {
      if (avgMood >= 7) {
        parts.add('Настроение в целом хорошее (${avgMood.toStringAsFixed(1)}/10)');
      } else if (avgMood >= 5) {
        parts.add('Настроение среднее (${avgMood.toStringAsFixed(1)}/10)');
      } else {
        parts.add('Настроение снижено (${avgMood.toStringAsFixed(1)}/10)');
      }
    }
    if (avgSleep != null) {
      if (avgSleep >= 7) {
        parts.add('Качество сна хорошее');
      } else if (avgSleep < 5) {
        parts.add('Качество сна нуждается во внимании');
      }
    }
    if (avgEnergy != null) {
      if (avgEnergy < 5) {
        parts.add('Уровень энергии низкий');
      } else if (avgEnergy >= 7) {
        parts.add('Энергия в норме');
      }
    }
    if (emotions.isNotEmpty) {
      final unique = emotions.toSet().take(5).join(', ');
      parts.add('Отмеченные эмоции: $unique');
    }

    final stateSummary = parts.isEmpty
        ? 'Пока мало данных для резюме. Добавляйте записи о состоянии.'
        : parts.join('. ');

    final patterns = await _loadPatterns();
    String overallInsight = '';
    if (patterns.isNotEmpty) {
      final insights = <String>[];
      if (patterns['mood_weekday_low'] != null) {
        insights.add('По наблюдениям, настроение ниже в определённые дни недели.');
      }
      if (patterns['sleep_mood_link'] == true) {
        insights.add('Плохой сон часто совпадает со снижением настроения.');
      }
      if (insights.isNotEmpty) {
        overallInsight = insights.join(' ');
      }
    }
    if (avgMood != null && avgMood < 5 && avgSleep != null && avgSleep < 5) {
      overallInsight = '${overallInsight.isNotEmpty ? '$overallInsight ' : ''}Сон и настроение связаны — улучшение сна может помочь.';
    }

    return (stateSummary, overallInsight);
  }

  Future<Map<String, dynamic>> _loadPatterns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyPatterns);
      if (raw == null) return {};
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<List<String>> _buildRecommendations(AggregatedData d) async {
    final recs = <String>[];

    double? avgMood, avgSleep, avgEnergy;
    int moodCount = 0, sleepCount = 0, energyCount = 0;
    double moodSum = 0, sleepSum = 0, energySum = 0;

    for (final e in d.stateEntries) {
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

    if (avgSleep != null && avgSleep < 6) {
      recs.add('Обратите внимание на режим сна: старайтесь ложиться в одно время.');
    }
    if (avgEnergy != null && avgEnergy < 5) {
      recs.add('При низкой энергии полезны короткие прогулки и перерывы.');
    }
    if (avgMood != null && avgMood < 5) {
      recs.add('При сниженном настроении помогает запись мыслей в заметки.');
    }
    if (d.medications.isNotEmpty) {
      recs.add('Не забывайте о регулярном приёме препаратов.');
    }
    if (d.appointments.isNotEmpty) {
      final upcoming = d.appointments.where((a) =>
          a.meetingDate != null && a.meetingDate!.isAfter(DateTime.now()));
      if (upcoming.isNotEmpty) {
        recs.add('Ближайший визит к врачу — хорошая возможность обсудить состояние.');
      }
    }
    if (d.notes.length < 3 && (avgMood == null || avgMood < 6)) {
      recs.add('Регулярные заметки помогут лучше отслеживать динамику.');
    }

    if (recs.isEmpty) {
      recs.add('Продолжайте вести записи — со временем появятся персонализированные рекомендации.');
    }

    return recs;
  }

  Future<void> _updatePatterns(AggregatedData d) async {
    final prefs = await SharedPreferences.getInstance();
    final patterns = <String, dynamic>{};

    final moodByWeekday = <int, List<int>>{};
    final sleepQualities = <double>[];
    final moodSameDay = <double>[];

    for (final e in d.stateEntries) {
      switch (e) {
        case MoodEntry(:final value, :final createdAt):
          final wd = createdAt.weekday;
          moodByWeekday.putIfAbsent(wd, () => []).add(value);
        case SleepEntry(:final quality, :final createdAt):
          final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
          for (final m in d.stateEntries) {
            if (m is MoodEntry) {
              final md = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
              if (day == md) {
                sleepQualities.add(quality.toDouble());
                moodSameDay.add(m.value.toDouble());
                break;
              }
            }
          }
        default:
          break;
      }
    }

    final moodEntries = d.stateEntries.whereType<MoodEntry>();
    if (moodByWeekday.isNotEmpty && moodEntries.isNotEmpty) {
      final weekdayAvgs = <int, double>{};
      for (final e in moodByWeekday.entries) {
        weekdayAvgs[e.key] = e.value.reduce((a, b) => a + b) / e.value.length;
      }
      final allMoods = moodByWeekday.values.expand((l) => l).toList();
      final overallAvg = allMoods.reduce((a, b) => a + b) / allMoods.length;
      final lowDays = weekdayAvgs.entries
          .where((e) => e.value < overallAvg - 0.5)
          .map((e) => e.key)
          .toList();
      if (lowDays.isNotEmpty) {
        patterns['mood_weekday_low'] = lowDays;
      }
    }

    if (sleepQualities.length >= 3 && moodSameDay.length == sleepQualities.length) {
      var lowSleepLowMood = 0;
      for (var i = 0; i < sleepQualities.length; i++) {
        if (sleepQualities[i] < 6 && moodSameDay[i] < 6) lowSleepLowMood++;
      }
      if (lowSleepLowMood >= sleepQualities.length ~/ 2) {
        patterns['sleep_mood_link'] = true;
      }
    }

    if (patterns.isNotEmpty) {
      await prefs.setString(_keyPatterns, jsonEncode(patterns));
    }
  }
}
