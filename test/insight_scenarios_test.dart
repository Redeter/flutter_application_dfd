import 'package:flutter/material.dart';
import 'package:flutter_application_dfd/models/aggregated_data.dart';
import 'package:flutter_application_dfd/models/calendar_entry.dart';
import 'package:flutter_application_dfd/models/note_item.dart';
import 'package:flutter_application_dfd/models/state_entries.dart';
import 'package:flutter_application_dfd/neural/aggregated_insight_signals.dart';
import 'package:flutter_application_dfd/neural/feature_extractor.dart';
import 'package:flutter_application_dfd/neural/neural_insights_service.dart';
import 'package:flutter_application_dfd/services/auth_service.dart';
import 'package:flutter_application_dfd/neural/recommendation_evidence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Фиксированные сценарии AggregatedData: гейты, доказательность советов, размер признаков.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDownAll(() {
    AuthService.instance.setFixtureSessionUserId(null);
  });

  const sleepRec = 'Обратите внимание на режим сна: старайтесь ложиться в одно время.';
  const energyRec = 'При низкой энергии полезны короткие прогулки и перерывы.';
  const moodRec = 'При сниженном настроении помогает запись мыслей в заметки.';
  const medsRec = 'Не забывайте о регулярном приёме препаратов.';
  const doctorRec = 'Ближайший визит к врачу — хорошая возможность обсудить состояние.';
  const notesRec = 'Регулярные заметки помогут лучше отслеживать динамику.';

  DateTime day(int daysAgo) {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).subtract(Duration(days: daysAgo));
  }

  AggregatedData empty() => AggregatedData(
        notes: const [],
        stateEntries: const [],
        medications: const [],
        appointments: const [],
      );

  AggregatedData sparseTwoDays() {
    return AggregatedData(
      notes: [
        NoteItem(date: day(1), title: 'a', tags: const [], preview: 'x'),
      ],
      stateEntries: [
        MoodEntry(createdAt: day(2), value: 5, factors: const []),
      ],
      medications: const [],
      appointments: const [],
    );
  }

  AggregatedData richTenDays() {
    final entries = <StateEntryBase>[];
    for (var i = 0; i < 10; i++) {
      final d = day(i);
      entries.add(MoodEntry(createdAt: d, value: 6, factors: const []));
      entries.add(SleepEntry(createdAt: d, quality: 6));
      entries.add(EnergyEntry(createdAt: d, level: 6));
    }
    return AggregatedData(
      notes: [
        NoteItem(
          date: day(0),
          title: 'день',
          tags: const ['тег'],
          preview: 'достаточно длинный текст для качества заметки и анализа',
        ),
      ],
      stateEntries: entries,
      medications: const [],
      appointments: const [],
    );
  }

  AggregatedData moodsOnlyNoLowSleepEvidence() {
    final entries = <StateEntryBase>[];
    for (var i = 0; i < 10; i++) {
      entries.add(MoodEntry(createdAt: day(i), value: 7, factors: const []));
    }
    return AggregatedData(
      notes: const [],
      stateEntries: entries,
      medications: const [],
      appointments: const [],
    );
  }

  AggregatedData strongLowSleepEvidence() {
    final entries = <StateEntryBase>[];
    for (var i = 0; i < 8; i++) {
      final d = day(i);
      entries.add(SleepEntry(createdAt: d, quality: 4));
      entries.add(SleepEntry(createdAt: d.add(const Duration(hours: 2)), quality: 4));
      entries.add(SleepEntry(createdAt: d.add(const Duration(hours: 5)), quality: 4));
    }
    return AggregatedData(
      notes: const [],
      stateEntries: entries,
      medications: const [],
      appointments: const [],
    );
  }

  AggregatedData oneLowSleepDayOnly() {
    final d = day(0);
    return AggregatedData(
      notes: const [],
      stateEntries: [
        SleepEntry(createdAt: d, quality: 3),
        SleepEntry(createdAt: d.add(const Duration(hours: 1)), quality: 3),
        SleepEntry(createdAt: d.add(const Duration(hours: 3)), quality: 3),
      ],
      medications: const [],
      appointments: const [],
    );
  }

  AggregatedData strongLowMoodEvidence() {
    final entries = <StateEntryBase>[];
    for (var i = 0; i < 8; i++) {
      final d = day(i);
      entries.add(MoodEntry(createdAt: d, value: 3, factors: const []));
      entries.add(MoodEntry(createdAt: d.add(const Duration(hours: 3)), value: 3, factors: const []));
      entries.add(MoodEntry(createdAt: d.add(const Duration(hours: 6)), value: 3, factors: const []));
    }
    return AggregatedData(
      notes: const [],
      stateEntries: entries,
      medications: const [],
      appointments: const [],
    );
  }

  AggregatedData strongLowEnergyEvidence() {
    final entries = <StateEntryBase>[];
    for (var i = 0; i < 8; i++) {
      final d = day(i);
      entries.add(EnergyEntry(createdAt: d, level: 3));
      entries.add(EnergyEntry(createdAt: d.add(const Duration(hours: 2)), level: 3));
      entries.add(EnergyEntry(createdAt: d.add(const Duration(hours: 5)), level: 3));
    }
    return AggregatedData(
      notes: const [],
      stateEntries: entries,
      medications: const [],
      appointments: const [],
    );
  }

  AggregatedData medsNoPrescriptionContext() {
    final entries = <StateEntryBase>[
      for (var i = 0; i < 10; i++) MoodEntry(createdAt: day(i), value: 7, factors: const []),
    ];
    return AggregatedData(
      notes: const [],
      stateEntries: entries,
      medications: const [],
      appointments: const [],
    );
  }

  AggregatedData medsWithPrescription() {
    final d = day(0);
    return AggregatedData(
      notes: const [],
      stateEntries: [
        MoodEntry(createdAt: d, value: 7, factors: const []),
      ],
      medications: [
        Medication(
          id: 'm1',
          date: d,
          time: const TimeOfDay(hour: 9, minute: 0),
          name: 'x',
          dosage: '1',
          schedule: const [
            MedicationDose(time: TimeOfDay(hour: 9, minute: 0), amount: '1'),
          ],
        ),
      ],
      appointments: const [],
    );
  }

  AggregatedData doctorWithUpcoming() {
    final d = day(0);
    return AggregatedData(
      notes: const [],
      stateEntries: [
        MoodEntry(createdAt: d, value: 6, factors: const []),
      ],
      medications: const [],
      appointments: [
        Appointment(
          id: 'a1',
          date: d,
          time: const TimeOfDay(hour: 10, minute: 0),
          title: 'Врач',
          meetingDate: DateTime.now().add(const Duration(days: 3)),
        ),
      ],
    );
  }

  AggregatedData doctorNoUpcoming() {
    final d = day(0);
    return AggregatedData(
      notes: const [],
      stateEntries: [
        MoodEntry(createdAt: d, value: 6, factors: const []),
      ],
      medications: const [],
      appointments: const [],
    );
  }

  AggregatedData notesAdviceWeak() {
    return AggregatedData(
      notes: [
        NoteItem(date: day(0), title: 't', tags: const [], preview: 'коротко'),
      ],
      stateEntries: [
        MoodEntry(createdAt: day(0), value: 8, factors: const []),
      ],
      medications: const [],
      appointments: const [],
    );
  }

  AggregatedData notesAdviceStrongAnxiety() {
    final notes = <NoteItem>[];
    for (var i = 0; i < 4; i++) {
      notes.add(NoteItem(
        date: day(i),
        title: 'n$i',
        tags: const [],
        preview: 'тревога стресс напряжение усталость',
      ));
    }
    return AggregatedData(
      notes: notes,
      stateEntries: [
        MoodEntry(createdAt: day(0), value: 6, factors: const []),
      ],
      medications: const [],
      appointments: const [],
    );
  }

  AggregatedData regularNotesWeakTracking() {
    return AggregatedData(
      notes: const [],
      stateEntries: [
        MoodEntry(createdAt: day(0), value: 6, factors: const []),
        MoodEntry(createdAt: day(3), value: 6, factors: const []),
      ],
      medications: const [],
      appointments: const [],
    );
  }

  AggregatedData regularNotesStrongTracking() {
    final entries = <StateEntryBase>[];
    for (var i = 0; i < 8; i++) {
      entries.add(MoodEntry(createdAt: day(i), value: 6, factors: const []));
    }
    return AggregatedData(
      notes: const [],
      stateEntries: entries,
      medications: const [],
      appointments: const [],
    );
  }

  test('FeatureExtractor: длина вектора и конечные значения', () {
    final v = FeatureExtractor.extract(richTenDays());
    expect(v.length, FeatureExtractor.featureCount);
    expect(v.every((x) => x.isFinite), isTrue);
  });

  test('Недостаточно данных: короткий горизонт', () {
    expect(AggregatedInsightSignals.neuralInsufficientGate(sparseTwoDays()), isTrue);
    expect(AggregatedInsightSignals.neuralInsufficientGate(richTenDays()), isFalse);
  });

  test('Доказательность: сон без серии плохих дней', () {
    expect(RecommendationEvidence.meetsMinimum(sleepRec, moodsOnlyNoLowSleepEvidence()), isFalse);
    expect(RecommendationEvidence.meetsMinimum(sleepRec, strongLowSleepEvidence()), isTrue);
    expect(RecommendationEvidence.meetsMinimum(sleepRec, oneLowSleepDayOnly()), isFalse);
  });

  test('Доказательность: настроение и энергия', () {
    expect(RecommendationEvidence.meetsMinimum(moodRec, moodsOnlyNoLowSleepEvidence()), isFalse);
    expect(RecommendationEvidence.meetsMinimum(moodRec, strongLowMoodEvidence()), isTrue);
    expect(RecommendationEvidence.meetsMinimum(energyRec, strongLowEnergyEvidence()), isTrue);
  });

  test('Доказательность: препараты и врач', () {
    expect(RecommendationEvidence.meetsMinimum(medsRec, medsNoPrescriptionContext()), isFalse);
    expect(RecommendationEvidence.meetsMinimum(medsRec, medsWithPrescription()), isTrue);
    expect(RecommendationEvidence.meetsMinimum(doctorRec, doctorNoUpcoming()), isFalse);
    expect(RecommendationEvidence.meetsMinimum(doctorRec, doctorWithUpcoming()), isTrue);
  });

  test('Доказательность: заметки и «регулярные заметки»', () {
    expect(RecommendationEvidence.meetsMinimum(moodRec, notesAdviceWeak()), isFalse);
    expect(RecommendationEvidence.meetsMinimum(moodRec, notesAdviceStrongAnxiety()), isTrue);
    expect(RecommendationEvidence.meetsMinimum(notesRec, regularNotesWeakTracking()), isFalse);
    expect(RecommendationEvidence.meetsMinimum(notesRec, regularNotesStrongTracking()), isTrue);
  });

  /// Пакет из 30+ микропроверок на комбинации сигналов.
  test('Матрица сценариев: гейт и meetsMinimum согласованы', () {
    final cases = <Map<String, dynamic>>[
      {'d': empty(), 'ins': true, 'sleep': false},
      {'d': sparseTwoDays(), 'ins': true, 'sleep': false},
      {'d': richTenDays(), 'ins': false, 'sleep': false},
      {'d': strongLowSleepEvidence(), 'ins': false, 'sleep': true},
      {'d': strongLowMoodEvidence(), 'ins': false, 'sleep': false},
      {'d': strongLowEnergyEvidence(), 'ins': false, 'sleep': false},
      {'d': medsWithPrescription(), 'ins': true, 'sleep': false},
      {'d': doctorWithUpcoming(), 'ins': true, 'sleep': false},
    ];

    for (final c in cases) {
      final d = c['d'] as AggregatedData;
      final ins = c['ins'] as bool;
      final sleep = c['sleep'] as bool;
      expect(AggregatedInsightSignals.neuralInsufficientGate(d), ins,
          reason: 'insufficient gate');
      expect(RecommendationEvidence.meetsMinimum(sleepRec, d), sleep, reason: 'sleep evidence');
    }

    for (var streak = 0; streak < 3; streak++) {
      final entries = <StateEntryBase>[];
      for (var i = 0; i < 14; i++) {
        entries.add(MoodEntry(createdAt: day(i), value: 5, factors: const []));
        entries.add(SleepEntry(createdAt: day(i), quality: 5));
      }
      final d = AggregatedData(
        notes: [
          NoteItem(
            date: day(streak),
            title: 'z',
            tags: const [],
            preview: 'длинный текст заметки для качества данных и анализа настроения',
          ),
        ],
        stateEntries: entries,
        medications: const [],
        appointments: const [],
      );
      expect(AggregatedInsightSignals.observationDays(d) >= 7, isTrue, reason: 'streak $streak');
      final v = FeatureExtractor.extract(d);
      expect(v.length, FeatureExtractor.featureCount);
    }
  });

  test('NeuralInsightsService: пустые данные — пустой результат', () async {
    SharedPreferences.setMockInitialValues({});
    NeuralInsightsService.debugResetForTests();
    final r = await NeuralInsightsService.instance.getInsights(empty());
    expect(r.recommendations, isEmpty);
    expect(r.stateSummary, isEmpty);
  });

  test('NeuralInsightsService: мало дней — insufficientData', () async {
    SharedPreferences.setMockInitialValues({});
    NeuralInsightsService.debugResetForTests();
    final r = await NeuralInsightsService.instance.getInsights(sparseTwoDays());
    expect(r.insufficientData, isTrue);
  });

  test('Пакет сценариев: evidence + insufficient (расширенный)', () {
    final entriesSleep2BadDays = <StateEntryBase>[
      for (var i = 0; i < 2; i++) ...[
        SleepEntry(createdAt: day(i), quality: 4),
        SleepEntry(createdAt: day(i).add(const Duration(hours: 2)), quality: 4),
      ],
    ];
    final dSleep2 = AggregatedData(
      notes: const [],
      stateEntries: entriesSleep2BadDays,
      medications: const [],
      appointments: const [],
    );
    expect(RecommendationEvidence.meetsMinimum(sleepRec, dSleep2), isFalse);

    final entriesSleep3Bad = <StateEntryBase>[
      for (var i = 0; i < 4; i++) ...[
        SleepEntry(createdAt: day(i), quality: 4),
        SleepEntry(createdAt: day(i).add(const Duration(hours: 1)), quality: 4),
      ],
    ];
    expect(
      RecommendationEvidence.meetsMinimum(
        sleepRec,
        AggregatedData(
          notes: const [],
          stateEntries: entriesSleep3Bad,
          medications: const [],
          appointments: const [],
        ),
      ),
      isTrue,
    );

    for (final k in List.generate(20, (i) => i)) {
      final moods = <StateEntryBase>[
        MoodEntry(createdAt: day(k % 5), value: 4, factors: const []),
      ];
      final d = AggregatedData(
        notes: const [],
        stateEntries: moods,
        medications: const [],
        appointments: const [],
      );
      expect(AggregatedInsightSignals.neuralInsufficientGate(d), isTrue);
      expect(RecommendationEvidence.meetsMinimum(moodRec, d), isFalse);
    }

    for (final k in List.generate(15, (i) => i)) {
      final e = <StateEntryBase>[
        for (var j = 0; j < 10; j++) MoodEntry(createdAt: day(j), value: 6 + (k % 2), factors: const []),
      ];
      final d = AggregatedData(
        notes: [
          NoteItem(
            date: day(0),
            title: 't$k',
            tags: const [],
            preview: 'достаточно длинный текст для оценки качества заметки и контекста',
          ),
        ],
        stateEntries: e,
        medications: const [],
        appointments: const [],
      );
      expect(AggregatedInsightSignals.neuralInsufficientGate(d), isFalse);
      expect(FeatureExtractor.extract(d).length, FeatureExtractor.featureCount);
    }
  });
}
