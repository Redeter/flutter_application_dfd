import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/insight_result.dart';
import '../models/state_entries.dart';
import 'insights_service.dart';

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

    final keywords = _extractKeywords(data);
    final (stateSummary, overallInsight) = await _buildSummaries(data);
    final recommendations = await _buildRecommendations(data);

    await _updatePatterns(data);

    return InsightResult(
      keywords: keywords,
      stateSummary: stateSummary,
      overallInsight: overallInsight,
      recommendations: recommendations,
    );
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
