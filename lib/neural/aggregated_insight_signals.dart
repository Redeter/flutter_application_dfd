import '../models/aggregated_data.dart';

/// Сигналы «достаточности данных» в том же смысле, что и NeuralInsightsService (для тестов и UI).
class AggregatedInsightSignals {
  AggregatedInsightSignals._();

  static int observationDays(AggregatedData d) {
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

  static double neuralStyleQuality(AggregatedData d) {
    final total = d.notes.length + d.stateEntries.length;
    if (total == 0) return 0;
    final noteRichness = d.notes.isEmpty
        ? 0.6
        : d.notes
                .map((n) => ((n.title.length + n.preview.length) / 80).clamp(0.0, 1.0))
                .reduce((a, b) => a + b) /
            d.notes.length;
    final entryCoverage = (d.stateEntries.length / 20).clamp(0.0, 1.0);
    final days = (observationDays(d) / 14).clamp(0.0, 1.0);
    return (0.45 * noteRichness + 0.35 * entryCoverage + 0.2 * days).clamp(0.0, 1.0);
  }

  static bool neuralInsufficientGate(AggregatedData d) =>
      observationDays(d) < 7 || neuralStyleQuality(d) < 0.45;
}
