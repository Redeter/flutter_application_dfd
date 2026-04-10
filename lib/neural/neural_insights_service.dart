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

    if (!_trained || _net == null) {
      final result = await LocalInsightsService.instance.getInsights(data);
      unawaited(_trainInBackground(data));
      return result;
    }

    unawaited(_maybeRetrainWithRealData(data));

    final features = FeatureExtractor.extract(data);
    if (features.length < _inputSize) {
      final padded = List<double>.filled(_inputSize, 0);
      for (var i = 0; i < features.length; i++) {
        padded[i] = features[i];
      }
      return _runInference(padded, data);
    }
    return _runInference(features, data);
  }

  Future<InsightResult> _runInference(List<double> features, AggregatedData data) async {
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

    final (stateSummary, overallInsight) = _buildSummaryFromScores(
      summaryScores,
      data,
    );

    final keywords = _extractKeywords(data);

    return InsightResult(
      keywords: keywords,
      stateSummary: stateSummary,
      overallInsight: overallInsight,
      recommendations: recommendations,
    );
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
      for (final s in samples) {
        model.trainStep(s.features, s.targets, lr * (1 - ep / epochs));
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
        model.trainStep(s.features, s.targets, lr);
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
          ));
        }
      }
    }

    for (var i = 0; i < 200; i++) {
      final data = _randomAggregatedData(r);
      final features = FeatureExtractor.extract(data);
      if (features.length < _inputSize) continue;

      final padded = _padFeatures(features);
      samples.add(_TrainingSample(features: padded, targets: _getRuleTargets(data)));
    }

    return samples;
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
  _TrainingSample({required this.features, required this.targets});
  final List<double> features;
  final List<double> targets;
}
