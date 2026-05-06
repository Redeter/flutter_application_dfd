import '../models/aggregated_data.dart';
import '../models/calendar_entry.dart';
import '../models/insight_result.dart';
import '../models/note_item.dart';
import '../models/state_entries.dart';

class OfflineValidationResult {
  const OfflineValidationResult({
    required this.score,
    required this.totalCases,
  });
  final double score;
  final int totalCases;
}

class OfflineValidationService {
  OfflineValidationService._();
  static final OfflineValidationService instance = OfflineValidationService._();

  Future<OfflineValidationResult> evaluate(
    Future<InsightResult> Function(AggregatedData data) predictor,
  ) async {
    final cases = _cases();
    var passed = 0;
    for (final c in cases) {
      final result = await predictor(c.data);
      if (_matchesExpectation(result, c.expectedKeywords)) {
        passed++;
      }
    }
    return OfflineValidationResult(
      score: cases.isEmpty ? 0 : passed / cases.length,
      totalCases: cases.length,
    );
  }

  bool _matchesExpectation(InsightResult r, List<String> expectedKeywords) {
    final all = [
      ...r.keywords.map((e) => e.toLowerCase()),
      ...r.recommendations.map((e) => e.toLowerCase()),
      r.stateSummary.toLowerCase(),
      r.overallInsight.toLowerCase(),
    ];
    for (final kw in expectedKeywords) {
      if (!all.any((x) => x.contains(kw))) return false;
    }
    return true;
  }

  List<_OfflineCase> _cases() {
    final now = DateTime.now();
    return [
      _OfflineCase(
        data: AggregatedData(
          notes: [
            NoteItem(date: now.subtract(const Duration(days: 1)), title: 'Тяжелый день', tags: const [], preview: 'плохо спал и устал'),
          ],
          stateEntries: [
            SleepEntry(createdAt: now.subtract(const Duration(days: 1)), quality: 3),
            MoodEntry(createdAt: now.subtract(const Duration(days: 1)), value: 4),
            EnergyEntry(createdAt: now.subtract(const Duration(days: 1)), level: 3),
          ],
          medications: const <Medication>[],
          appointments: const <Appointment>[],
        ),
        expectedKeywords: const ['14', 'сон', 'энерг', 'настро'],
      ),
      _OfflineCase(
        data: AggregatedData(
          notes: [
            NoteItem(date: now.subtract(const Duration(days: 2)), title: 'Стабильно', tags: const ['спорт'], preview: 'хорошо выспался и бодрый'),
          ],
          stateEntries: [
            SleepEntry(createdAt: now.subtract(const Duration(days: 2)), quality: 8),
            MoodEntry(createdAt: now.subtract(const Duration(days: 2)), value: 8),
            EnergyEntry(createdAt: now.subtract(const Duration(days: 2)), level: 8),
          ],
          medications: const <Medication>[],
          appointments: const <Appointment>[],
        ),
        expectedKeywords: const ['хорош'],
      ),
    ];
  }
}

class _OfflineCase {
  const _OfflineCase({
    required this.data,
    required this.expectedKeywords,
  });

  final AggregatedData data;
  final List<String> expectedKeywords;
}
