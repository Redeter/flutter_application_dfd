import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/aggregated_data.dart';
import '../models/calendar_entry.dart';
import '../models/insight_result.dart';
import '../models/note_item.dart';
import '../models/state_entries.dart';
import '../services/local_insights_service.dart';
import 'feature_extractor.dart';
import 'neural_net.dart';

/// Тексты рекомендаций (индексы 0–5 соответствуют выходам нейросети).
const _recTexts = [
  'Обратите внимание на режим сна: старайтесь ложиться в одно время.',
  'При низкой энергии полезны короткие прогулки и перерывы.',
  'При сниженном настроении помогает запись мыслей в заметки.',
  'Не забывайте о регулярном приёме препаратов.',
  'Ближайший визит к врачу — хорошая возможность обсудить состояние.',
  'Регулярные заметки помогут лучше отслеживать динамику.',
];

const _defaultRec =
    'Продолжайте вести записи — со временем появятся персонализированные рекомендации.';

/// Локальная нейросеть для анализа состояния и выдачи советов.
/// Обучена на данных, сгенерированных правилами LocalInsightsService.
class NeuralInsightsService {
  NeuralInsightsService._();
  static NeuralInsightsService get instance => _instance;
  static final _instance = NeuralInsightsService._();

  static const _keyModel = 'neural_insights_model';
  static const _keyTrained = 'neural_insights_trained';
  static const _keyModelVersion = 'neural_insights_version';
  static const _keyLastRetrainCount = 'neural_last_retrain_count';
  static const _keyRecFeedback = 'qm_rec_feedback_v1';
  static const _keyInsightEvents = 'qm_insight_events_v1';
  static const _modelVersion = 3;

  static const _inputSize = 33;
  static const _hiddenSizes = [48, 24];
  static const _outputSize = 10;

  NeuralNet? _net;
  bool _trained = false;
  bool _initCalled = false;

  /// Инициализация (загрузка модели). Вызвать при старте приложения.
  Future<void> init() async {
    if (_initCalled) return;
    _initCalled = true;
    _net = await _loadModel();
  }

  Future<NeuralNet> _loadModel() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVersion = prefs.getInt(_keyModelVersion) ?? 0;
    if (savedVersion != _modelVersion) {
      _trained = false;
    } else {
      _trained = prefs.getBool(_keyTrained) ?? false;
    }

    final raw = prefs.getString(_keyModel);
    if (raw != null && savedVersion == _modelVersion) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final net = NeuralNet.fromJson(json);
        if (net.inputSize == _inputSize) return net;
      } catch (_) {}
    }

    return NeuralNet(
      inputSize: _inputSize,
      hiddenSizes: _hiddenSizes,
      outputSize: _outputSize,
    );
  }

  /// Получить инсайты через нейросеть. Если модель не обучена, используется rule-based fallback.
  Future<InsightResult> getInsights(AggregatedData data) async {
    await init();
    final sanitized = _sanitizeData(data);
    final quality = _estimateDataQuality(sanitized);
    final observationDays = _observationDays(sanitized);

    if (sanitized.notes.isEmpty &&
        sanitized.stateEntries.isEmpty &&
        sanitized.medications.isEmpty &&
        sanitized.appointments.isEmpty) {
      return const InsightResult(
        keywords: [],
        stateSummary: '',
        overallInsight: '',
        recommendations: [],
      );
    }

    if (observationDays < 7 || quality < 0.45) {
      return InsightResult(
        keywords: _extractKeywords(sanitized).take(5).toList(),
        stateSummary: 'Недостаточно стабильных данных для надежного вывода.',
        overallInsight: 'Заполняйте данные регулярно минимум неделю.',
        recommendations: const ['Сделайте 1-2 короткие записи в день в течение недели.'],
        confidence: (quality * 0.6).clamp(0.0, 0.6),
        dataQualityScore: quality,
        insufficientData: true,
      );
    }

    if (!_trained || _net == null) {
      final result = await LocalInsightsService.instance.getInsights(sanitized);
      unawaited(_trainInBackground(sanitized));
      return result;
    }

    unawaited(_maybeRetrainWithRealData(sanitized));

    final features = FeatureExtractor.extract(sanitized);
    if (features.length < _inputSize) {
      final padded = List<double>.filled(_inputSize, 0);
      for (var i = 0; i < features.length; i++) {
        padded[i] = features[i];
      }
      return _runInference(padded, sanitized, quality);
    }
    return _runInference(features, sanitized, quality);
  }

  Future<InsightResult> _runInference(
    List<double> features,
    AggregatedData data,
    double quality,
  ) async {
    final outList = _net!.forward(features);

    final recScores = outList.sublist(0, 6);
    final summaryScores = outList.sublist(6, 10);

    final recommendations = <String>[];
    for (var i = 0; i < 6; i++) {
      if (recScores[i] >= 0.5) {
        recommendations.add(_recTexts[i]);
      }
    }
    if (recommendations.isEmpty) {
      recommendations.add(_defaultRec);
    }
    final ranked = await _rankRecommendations(
      recommendations,
      recScores,
      data,
    );
    final filteredRecommendations = ranked.keys.take(3).toList();
    final safeRecommendations = filteredRecommendations.isEmpty
        ? recommendations.take(3).toList()
        : filteredRecommendations;

    final (stateSummary, overallInsight) = _buildSummaryFromScores(
      summaryScores,
      data,
    );

    final keywords = _extractKeywords(data);

    return InsightResult(
      keywords: keywords,
      stateSummary: stateSummary,
      overallInsight: overallInsight,
      recommendations: safeRecommendations,
      recommendationReasons: _buildRecommendationReasons(data, safeRecommendations),
      confidence: _predictionConfidence(outList, quality, data),
      dataQualityScore: quality,
      personalizationScores: _personalizationScores(data),
      recommendationScores: ranked.isEmpty
          ? {
              for (var i = 0; i < safeRecommendations.length; i++)
                safeRecommendations[i]: (i < recScores.length ? recScores[i] : 0.5)
            }
          : ranked,
    );
  }

  Future<Map<String, double>> _rankRecommendations(
    List<String> recs,
    List<double> recScores,
    AggregatedData data,
  ) async {
    final scores = <String, double>{};
    final personalization = _personalizationScores(data);
    final fatigue = await _recentRecommendationFatigue();
    final intervention = await _interventionResponseScore();
    final baselineDev = _personalBaselineDeviation(data);
    final recency = personalization['recency'] ?? 0.5;
    final consistency = personalization['consistency'] ?? 0.5;
    final stability = personalization['stability'] ?? 0.5;
    final novelty = _noveltyScore(fatigue);
    final diversityBoost = <String, double>{};

    for (var i = 0; i < recs.length; i++) {
      final rec = recs[i];
      final base = i < recScores.length ? recScores[i] : 0.5;
      final actionability = _actionabilityScore(rec, data);
      final fatiguePenalty = (fatigue[rec] ?? 0).clamp(0, 4) / 4;
      final weighted = (0.45 * base) +
          (0.15 * recency) +
          (0.1 * consistency) +
          (0.08 * stability) +
          (0.1 * baselineDev) +
          (0.05 * intervention) +
          (0.12 * actionability) +
          (0.1 * novelty) -
          (0.2 * fatiguePenalty);
      scores[rec] = weighted;
      diversityBoost[rec] = _categoryDiversityFactor(rec);
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) {
        final av = a.value + (diversityBoost[a.key] ?? 0);
        final bv = b.value + (diversityBoost[b.key] ?? 0);
        return bv.compareTo(av);
      });
    final evidence = _evidenceByRecommendation(data, recs);
    final filtered = sorted
        .where((e) => (e.value >= 0.45) && (evidence[e.key]?.isNotEmpty ?? false))
        .toList();
    final categoryLimited = _applyCategoryLimits(filtered.map((e) => e.key).toList());
    return {
      for (final rec in categoryLimited)
        rec: (scores[rec] ?? 0.0).clamp(0.0, 1.0),
    };
  }

  List<String> _applyCategoryLimits(List<String> ordered) {
    final perCategory = <String, int>{};
    final out = <String>[];
    for (final rec in ordered) {
      final c = _recommendationCategory(rec);
      final used = perCategory[c] ?? 0;
      final maxInCategory = c == 'routine' ? 1 : 2;
      if (used >= maxInCategory) continue;
      perCategory[c] = used + 1;
      out.add(rec);
      if (out.length >= 3) break;
    }
    return out;
  }

  Map<String, double> _personalizationScores(AggregatedData data) {
    final recency = _recencyScore(data);
    final consistency = _consistencyScore(data);
    final stability = _stabilityIndex(data);
    final baselineDev = _personalBaselineDeviation(data);
    return {
      'recency': recency,
      'consistency': consistency,
      'stability': stability,
      'baselineDeviation': baselineDev,
    };
  }

  double _recencyScore(AggregatedData data) {
    if (data.stateEntries.isEmpty) return 0.3;
    final now = DateTime.now();
    final weights = data.stateEntries.map((e) {
      final ageDays = now.difference(e.createdAt).inHours / 24;
      return exp(-ageDays / 7);
    }).toList();
    return weights.reduce((a, b) => a + b) / weights.length;
  }

  double _consistencyScore(AggregatedData data) {
    if (data.stateEntries.isEmpty && data.notes.isEmpty) return 0;
    final days = <DateTime>{};
    for (final e in data.stateEntries) {
      days.add(DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day));
    }
    for (final n in data.notes) {
      days.add(DateTime(n.date.year, n.date.month, n.date.day));
    }
    final obs = _observationDays(data);
    if (obs <= 0) return 0;
    return (days.length / obs).clamp(0.0, 1.0);
  }

  double _stabilityIndex(AggregatedData data) {
    final moods = data.stateEntries.whereType<MoodEntry>().map((e) => e.value.toDouble()).toList();
    if (moods.length < 3) return 0.6;
    final mean = moods.reduce((a, b) => a + b) / moods.length;
    final variance = moods.map((m) => (m - mean) * (m - mean)).reduce((a, b) => a + b) / moods.length;
    return (1 - (variance / 12)).clamp(0.0, 1.0);
  }

  double _personalBaselineDeviation(AggregatedData data) {
    final moods = data.stateEntries.whereType<MoodEntry>().toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (moods.length < 6) return 0.5;
    final half = moods.length ~/ 2;
    final baseline = moods.sublist(0, half).map((e) => e.value).reduce((a, b) => a + b) / half;
    final current = moods.sublist(half).map((e) => e.value).reduce((a, b) => a + b) / (moods.length - half);
    final delta = (current - baseline).abs() / 10;
    return delta.clamp(0.0, 1.0);
  }

  double _actionabilityScore(String rec, AggregatedData data) {
    var score = 0.55;
    if (rec.contains('прогул')) score += 0.15;
    if (rec.contains('замет')) score += 0.1;
    if (rec.contains('режим сна')) score += 0.1;
    if (rec.contains('врач') && data.appointments.isEmpty) score -= 0.1;
    return score.clamp(0.0, 1.0);
  }

  double _categoryDiversityFactor(String rec) {
    if (rec.contains('сна')) return 0.02;
    if (rec.contains('энерг')) return 0.03;
    if (rec.contains('настроен')) return 0.03;
    if (rec.contains('врач')) return 0.01;
    if (rec.contains('замет')) return 0.02;
    return 0;
  }

  double _noveltyScore(Map<String, int> fatigue) {
    if (fatigue.isEmpty) return 1.0;
    final avg = fatigue.values.reduce((a, b) => a + b) / fatigue.length;
    return (1 - avg / 6).clamp(0.0, 1.0);
  }

  Future<Map<String, int>> _recentRecommendationFatigue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyInsightEvents);
    if (raw == null) return {};
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final now = DateTime.now();
      final counts = <String, int>{};
      for (final item in list) {
        final ts = DateTime.tryParse('${item['ts']}');
        if (ts == null || now.difference(ts).inDays > 10) continue;
        final recs = (item['recommendations'] as List<dynamic>? ?? [])
            .map((e) => '$e')
            .toList();
        for (final r in recs) {
          counts[r] = (counts[r] ?? 0) + 1;
        }
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  Future<double> _interventionResponseScore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyRecFeedback);
    if (raw == null) return 0.5;
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (list.isEmpty) return 0.5;
      final accepted = list.where((e) => e['accepted'] == true).length;
      final helpful = list.where((e) => e['helpful'] == true).length;
      return ((0.6 * accepted / list.length) + (0.4 * helpful / list.length)).clamp(0.0, 1.0);
    } catch (_) {
      return 0.5;
    }
  }

  double _predictionConfidence(List<double> out, double quality, AggregatedData data) {
    final margin = out.map((e) => (e - 0.5).abs()).reduce((a, b) => a + b) / out.length;
    final coverage = ((data.notes.length + data.stateEntries.length) / 40).clamp(0.0, 1.0);
    return (0.4 * quality + 0.35 * coverage + 0.25 * (margin * 2)).clamp(0.0, 1.0);
  }

  Map<String, List<String>> _buildRecommendationReasons(
    AggregatedData d,
    List<String> recs,
  ) {
    final evidence = _evidenceByRecommendation(d, recs);
    final reasons = <String, List<String>>{};
    for (final rec in recs) {
      final list = evidence[rec] ?? const <String>[];
      reasons[rec] = list.isEmpty
          ? const ['совет основан на суммарной динамике показателей']
          : list.take(3).toList();
    }
    return reasons;
  }

  Map<String, List<String>> _evidenceByRecommendation(
    AggregatedData d,
    List<String> recs,
  ) {
    final byRec = <String, List<String>>{};
    final now = DateTime.now();
    final from14 = now.subtract(const Duration(days: 14));

    final sleep14 = d.stateEntries.whereType<SleepEntry>().where((e) => !e.createdAt.isBefore(from14)).toList();
    final mood14 = d.stateEntries.whereType<MoodEntry>().where((e) => !e.createdAt.isBefore(from14)).toList();
    final energy14 = d.stateEntries.whereType<EnergyEntry>().where((e) => !e.createdAt.isBefore(from14)).toList();
    final lowSleepDays = sleep14.where((e) => e.quality < 6).length;
    final lowMoodDays = mood14.where((e) => e.value < 5).length;
    final lowEnergyDays = energy14.where((e) => e.level < 5).length;
    final energyTrend = _linearTrend(energy14.map((e) => e.level.toDouble()).toList());
    final anxiousFreq = _anxiousWordFrequency(d);
    final baselineShift = _personalBaselineDeviation(d);
    final medsCount = d.medications.length;
    final upcomingVisits = d.appointments
        .where((a) => a.meetingDate != null && a.meetingDate!.isAfter(now))
        .length;
    final notes14 = d.notes.where((n) => !n.date.isBefore(from14)).length;
    final trackedDays = d.stateEntries
        .where((e) => !e.createdAt.isBefore(from14))
        .map((e) => DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day))
        .toSet()
        .length;

    for (final rec in recs) {
      final facts = <String>[];
      if (rec.contains('сна') && sleep14.isNotEmpty) {
        facts.add('низкий сон: $lowSleepDays дней за 14');
      }
      if (rec.contains('энерг') && energy14.isNotEmpty) {
        facts.add('тренд энергии: ${energyTrend >= 0 ? '+' : ''}${energyTrend.toStringAsFixed(2)}');
        facts.add('низкая энергия: $lowEnergyDays дней за 14');
      }
      if (rec.contains('настроен') && mood14.isNotEmpty) {
        facts.add('сниженное настроение: $lowMoodDays дней за 14');
      }
      if (rec.contains('замет')) {
        facts.add('тревожные маркеры в заметках: ${(anxiousFreq * 100).round()}%');
        facts.add('заметок за 14 дней: $notes14');
      }
      if (rec.contains('препарат')) {
        facts.add('активных записей о препаратах: $medsCount');
      }
      if (rec.contains('врач')) {
        facts.add('ближайших визитов в календаре: $upcomingVisits');
      }
      if (rec.contains('регуляр')) {
        facts.add('дней с записями за 14 дней: $trackedDays');
      }
      if (baselineShift > 0.2) {
        facts.add('отклонение от личной нормы: ${(baselineShift * 100).round()}%');
      }
      if (facts.isEmpty) {
        facts.add('наблюдений за 14 дней: ${sleep14.length + mood14.length + energy14.length}');
        facts.add('данных по состоянию достаточно для трендового анализа');
      }
      byRec[rec] = facts;
    }
    return byRec;
  }

  double _linearTrend(List<double> values) {
    if (values.length < 2) return 0;
    var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0;
    for (var i = 0; i < values.length; i++) {
      sumX += i;
      sumY += values[i];
      sumXY += i * values[i];
      sumX2 += i * i;
    }
    final n = values.length.toDouble();
    final denom = n * sumX2 - sumX * sumX;
    if (denom.abs() < 1e-9) return 0;
    return ((n * sumXY - sumX * sumY) / denom / 10).clamp(-1.0, 1.0);
  }

  double _anxiousWordFrequency(AggregatedData d) {
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

  String _recommendationCategory(String rec) {
    if (rec.contains('сна')) return 'sleep';
    if (rec.contains('энерг')) return 'energy';
    if (rec.contains('настроен')) return 'mood';
    return 'routine';
  }

  (String, String) _buildSummaryFromScores(List<double> scores, AggregatedData data) {
    final moodScore = scores.isNotEmpty ? scores[0] : 0.5;
    final sleepScore = scores.length > 1 ? scores[1] : 0.5;
    final energyScore = scores.length > 2 ? scores[2] : 0.5;
    final hasEmotions = scores.length > 3 && scores[3] > 0.5;

    double? avgMood;
    double? avgSleep;
    double? avgEnergy;
    final emotions = <String>[];

    var moodSum = 0.0;
    var moodCount = 0;
    var sleepSum = 0.0;
    var sleepCount = 0;
    var energySum = 0.0;
    var energyCount = 0;
    for (final e in data.stateEntries) {
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
      if (moodScore >= 0.7) {
        parts.add('Настроение в целом хорошее (${avgMood.toStringAsFixed(1)}/10)');
      } else if (moodScore >= 0.5) {
        parts.add('Настроение среднее (${avgMood.toStringAsFixed(1)}/10)');
      } else {
        parts.add('Настроение снижено (${avgMood.toStringAsFixed(1)}/10)');
      }
    }
    if (avgSleep != null) {
      if (sleepScore >= 0.7) {
        parts.add('Качество сна хорошее');
      } else if (sleepScore < 0.5) {
        parts.add('Качество сна нуждается во внимании');
      }
    }
    if (avgEnergy != null) {
      if (energyScore < 0.5) {
        parts.add('Уровень энергии низкий');
      } else if (energyScore >= 0.7) {
        parts.add('Энергия в норме');
      }
    }
    if (hasEmotions && emotions.isNotEmpty) {
      final unique = emotions.toSet().take(5).join(', ');
      parts.add('Отмеченные эмоции: $unique');
    }

    final stateSummary = parts.isEmpty
        ? 'Пока мало данных для резюме. Добавляйте записи о состоянии.'
        : parts.join('. ');

    String overallInsight = '';
    if (moodScore < 0.5 && sleepScore < 0.5) {
      overallInsight = 'Сон и настроение связаны — улучшение сна может помочь.';
    }

    return (stateSummary, overallInsight);
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

    const stopWords = {
      'и', 'в', 'на', 'с', 'по', 'для', 'из', 'к', 'о', 'от', 'до', 'за', 'у',
      'при', 'не', 'нет', 'да', 'это', 'как', 'что', 'то', 'так', 'же', 'или',
    };
    final words = RegExp(r'[а-яёa-z]+', caseSensitive: false)
        .allMatches(allText.toString())
        .map((m) => m.group(0)!.toLowerCase())
        .where((w) => w.length > 2 && !stopWords.contains(w));

    for (final w in words) {
      if (w.length >= 4) candidates[w] = (candidates[w] ?? 0) + 1;
    }

    final sorted = candidates.entries
        .where((e) => e.value >= 1)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(10).map((e) => e.key).toList();
  }

  Future<void> _trainInBackground(AggregatedData? existingData) async {
    var model = _net;
    if (model == null) {
      model = await _loadModel();
      _net = model;
    }
    if (_trained) return;

    final samples = _generateTrainingData(existingData);
    const epochs = 150;
    const lr = 0.1;

    for (var ep = 0; ep < epochs; ep++) {
      samples.shuffle(Random(ep));
      var epochLoss = 0.0;
      for (final s in samples) {
        epochLoss += model.trainStep(s.features, s.targets, lr * (1 - ep / epochs) * s.weight);
      }
      if (ep > 20 && epochLoss / samples.length < 0.02) {
        break;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyModel, jsonEncode(model.toJson()));
    await prefs.setBool(_keyTrained, true);
    await prefs.setInt(_keyModelVersion, _modelVersion);
    await prefs.setInt(_keyLastRetrainCount, _countEntries(existingData));
    _trained = true;
    _net = model;
  }

  int _countEntries(AggregatedData? d) =>
      d?.stateEntries.length ?? 0;

  /// Периодическое дообучение на реальных данных пользователя.
  Future<void> _maybeRetrainWithRealData(AggregatedData data) async {
    if (_net == null || !_trained) return;
    final prefs = await SharedPreferences.getInstance();
    final lastCount = prefs.getInt(_keyLastRetrainCount) ?? 0;
    final currentCount = data.stateEntries.length;
    if (currentCount < 15) return;
    if (currentCount - lastCount < 20) return;

    final samples = _generateTrainingData(data);
    if (samples.length < 50) return;

    var model = _net!;
    const epochs = 50;
    const lr = 0.05;

    for (var ep = 0; ep < epochs; ep++) {
      samples.shuffle(Random(ep + 1000));
      for (final s in samples) {
        model.trainStep(s.features, s.targets, lr * s.weight);
      }
    }

    await prefs.setString(_keyModel, jsonEncode(model.toJson()));
    await prefs.setInt(_keyLastRetrainCount, currentCount);
    _net = model;
  }

  List<_TrainingSample> _generateTrainingData(AggregatedData? realData) {
    final r = Random(42);
    final samples = <_TrainingSample>[];

    if (realData != null && realData.stateEntries.length >= 5) {
      for (var i = 0; i < 3; i++) {
        final features = FeatureExtractor.extract(realData);
        if (features.length >= _inputSize) {
          final padded = _padFeatures(features);
          samples.add(_TrainingSample(
            features: padded,
            targets: _getRuleTargets(realData),
            weight: 1.25,
          ));
        }
      }
    }

    for (var i = 0; i < 200; i++) {
      final data = _randomAggregatedData(r);
      final features = FeatureExtractor.extract(data);
      if (features.length < _inputSize) continue;

      final padded = _padFeatures(features);
      samples.add(_TrainingSample(
        features: padded,
        targets: _getRuleTargets(data),
        weight: 0.7,
      ));
    }

    return samples;
  }

  AggregatedData _sanitizeData(AggregatedData data) {
    final dedupNotes = <NoteItem>[];
    final seenNoteKeys = <String>{};
    for (final n in data.notes) {
      final key = '${n.date.year}-${n.date.month}-${n.date.day}:${n.title.trim().toLowerCase()}:${n.preview.trim().toLowerCase()}';
      if (seenNoteKeys.add(key)) {
        dedupNotes.add(n);
      }
    }

    final sortedEntries = [...data.stateEntries]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final filteredEntries = <StateEntryBase>[];
    for (final e in sortedEntries) {
      if (!_isValidEntry(e)) continue;
      if (_isBurstNoise(e, filteredEntries)) continue;
      if (_isSharpOscillationNoise(e, filteredEntries)) continue;
      filteredEntries.add(e);
    }

    return AggregatedData(
      notes: dedupNotes,
      stateEntries: filteredEntries,
      medications: data.medications,
      appointments: data.appointments,
    );
  }

  bool _isValidEntry(StateEntryBase e) {
    switch (e) {
      case MoodEntry(:final value):
        return value >= 1 && value <= 10;
      case SleepEntry(:final quality):
        return quality >= 1 && quality <= 10;
      case EnergyEntry(:final level):
        return level >= 1 && level <= 10;
      default:
        return true;
    }
  }

  bool _isBurstNoise(StateEntryBase e, List<StateEntryBase> accepted) {
    final recent = accepted.where((x) =>
        x.runtimeType == e.runtimeType &&
        e.createdAt.difference(x.createdAt).inMinutes.abs() <= 2);
    return recent.length >= 8;
  }

  bool _isSharpOscillationNoise(StateEntryBase e, List<StateEntryBase> accepted) {
    if (accepted.length < 2) return false;
    final lastSame = accepted.where((x) => x.runtimeType == e.runtimeType).toList();
    if (lastSame.length < 2) return false;
    final a = lastSame[lastSame.length - 2];
    final b = lastSame[lastSame.length - 1];
    if (e.createdAt.difference(b.createdAt).inMinutes.abs() > 15) return false;
    int? va;
    int? vb;
    int? vc;
    if (a is MoodEntry && b is MoodEntry && e is MoodEntry) {
      va = a.value;
      vb = b.value;
      vc = e.value;
    } else if (a is SleepEntry && b is SleepEntry && e is SleepEntry) {
      va = a.quality;
      vb = b.quality;
      vc = e.quality;
    } else if (a is EnergyEntry && b is EnergyEntry && e is EnergyEntry) {
      va = a.level;
      vb = b.level;
      vc = e.level;
    }
    if (va == null || vb == null || vc == null) return false;
    return (va - vb).abs() >= 7 && (vb - vc).abs() >= 7;
  }

  double _estimateDataQuality(AggregatedData d) {
    final total = d.notes.length + d.stateEntries.length;
    if (total == 0) return 0;
    final noteRichness = d.notes.isEmpty
        ? 0.6
        : d.notes
                .map((n) => ((n.title.length + n.preview.length) / 80).clamp(0.0, 1.0))
                .reduce((a, b) => a + b) /
            d.notes.length;
    final entryCoverage = (d.stateEntries.length / 20).clamp(0.0, 1.0);
    final days = (_observationDays(d) / 14).clamp(0.0, 1.0);
    return (0.45 * noteRichness + 0.35 * entryCoverage + 0.2 * days).clamp(0.0, 1.0);
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

  List<double> _padFeatures(List<double> features) {
    final padded = List<double>.filled(_inputSize, 0);
    for (var j = 0; j < features.length && j < _inputSize; j++) {
      padded[j] = features[j];
    }
    return padded;
  }

  List<double> _getRuleTargets(AggregatedData d) {
    double? avgMood, avgSleep, avgEnergy;
    var moodSum = 0.0, sleepSum = 0.0, energySum = 0.0;
    var moodCount = 0, sleepCount = 0, energyCount = 0;

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

    final emotions = d.stateEntries
        .whereType<EmotionsEntry>()
        .expand((e) => e.emotions)
        .toList();

    final recSleep = (avgSleep != null && avgSleep < 6) ? 1.0 : 0.0;
    final recEnergy = (avgEnergy != null && avgEnergy < 5) ? 1.0 : 0.0;
    final recMood = (avgMood != null && avgMood < 5) ? 1.0 : 0.0;
    final recMeds = d.medications.isNotEmpty ? 1.0 : 0.0;
    final hasUpcoming = d.appointments.any((a) =>
        a.meetingDate != null && a.meetingDate!.isAfter(DateTime.now()));
    final recDoctor = hasUpcoming ? 1.0 : 0.0;
    final recNotes =
        (d.notes.length < 3 && (avgMood == null || avgMood < 6)) ? 1.0 : 0.0;

    final moodOk = avgMood != null ? (avgMood >= 7 ? 1.0 : (avgMood >= 5 ? 0.6 : 0.2)) : 0.5;
    final sleepOk = avgSleep != null ? (avgSleep >= 7 ? 1.0 : (avgSleep < 5 ? 0.2 : 0.6)) : 0.5;
    final energyOk = avgEnergy != null ? (avgEnergy >= 7 ? 1.0 : (avgEnergy < 5 ? 0.2 : 0.6)) : 0.5;
    final emotionPresent = emotions.isNotEmpty ? 1.0 : 0.0;

    return [
      recSleep,
      recEnergy,
      recMood,
      recMeds,
      recDoctor,
      recNotes,
      moodOk,
      sleepOk,
      energyOk,
      emotionPresent,
    ];
  }

  AggregatedData _randomAggregatedData(Random r) {
    final notes = <NoteItem>[];
    final stateEntries = <StateEntryBase>[];
    final meds = <Medication>[];
    final appointments = <Appointment>[];

    const previewTemplates = [
      'сегодня плохо спал устал',
      'хорошо выспался много энергии',
      'тревожно напряжён стресс',
      'радость спокойствие отдохнул',
      'бессонница не могу уснуть',
    ];
    for (var i = 0; i < r.nextInt(15); i++) {
      final t = previewTemplates[r.nextInt(previewTemplates.length)];
      notes.add(NoteItem(
        date: DateTime.now().subtract(Duration(days: r.nextInt(14))),
        title: 'Note $i',
        tags: [],
        preview: t,
      ));
    }

    for (var i = 0; i < r.nextInt(20); i++) {
      final day = DateTime.now().subtract(Duration(days: r.nextInt(14)));
      stateEntries.add(MoodEntry(
        createdAt: day,
        value: r.nextInt(10) + 1,
        factors: [],
      ));
    }
    for (var i = 0; i < r.nextInt(15); i++) {
      stateEntries.add(SleepEntry(
        createdAt: DateTime.now().subtract(Duration(days: r.nextInt(14))),
        quality: r.nextInt(10) + 1,
      ));
    }
    for (var i = 0; i < r.nextInt(15); i++) {
      stateEntries.add(EnergyEntry(
        createdAt: DateTime.now().subtract(Duration(days: r.nextInt(14))),
        level: r.nextInt(10) + 1,
      ));
    }
    for (var i = 0; i < r.nextInt(5); i++) {
      stateEntries.add(EmotionsEntry(
        createdAt: DateTime.now().subtract(Duration(days: r.nextInt(7))),
        emotions: ['радость', 'спокойствие', 'тревога'].sublist(0, r.nextInt(3) + 1),
      ));
    }

    if (r.nextBool()) {
      final d = DateTime.now();
      meds.add(Medication(
        id: 'm${r.nextInt(1000)}',
        date: d,
        time: const TimeOfDay(hour: 8, minute: 0),
        name: 'Препарат',
        dosage: '10мг',
        schedule: [
          MedicationDose(time: const TimeOfDay(hour: 8, minute: 0), amount: '1 таб'),
        ],
      ));
    }
    if (r.nextBool()) {
      final d = DateTime.now();
      appointments.add(Appointment(
        id: 'a${r.nextInt(1000)}',
        date: d,
        time: const TimeOfDay(hour: 15, minute: 0),
        title: 'Врач',
        meetingDate: d.add(const Duration(days: 7)),
      ));
    }

    return AggregatedData(
      notes: notes,
      stateEntries: stateEntries,
      medications: meds,
      appointments: appointments,
    );
  }
}

void unawaited(Future<void> f) {}

class _TrainingSample {
  _TrainingSample({
    required this.features,
    required this.targets,
    required this.weight,
  });
  final List<double> features;
  final List<double> targets;
  final double weight;
}
