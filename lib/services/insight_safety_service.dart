import '../models/insight_result.dart';

class InsightSafetyService {
  InsightSafetyService._();
  static final InsightSafetyService instance = InsightSafetyService._();

  static const _unsafeDiagnosisTerms = [
    'диагноз',
    'диагностирован',
    'расстройство',
    'клинический',
  ];

  InsightResult apply(InsightResult input) {
    var summary = _sanitizeText(input.stateSummary);
    var overall = _sanitizeText(input.overallInsight);
    final recs = input.recommendations.map(_sanitizeText).toList();

    final safeRecs = recs.take(3).toList();
    final safeReasons = <String, List<String>>{};
    for (final rec in safeRecs) {
      final reasons = (input.recommendationReasons[rec] ?? const <String>[])
          .map(_sanitizeText)
          .take(3)
          .toList();
      safeReasons[rec] = reasons;
    }

    if (_isSevereRisk(input)) {
      overall = [
        overall,
        'При длительном ухудшении состояния обратитесь к врачу или специалисту.',
      ].where((e) => e.isNotEmpty).join(' ');
    }

    if (summary.isEmpty && overall.isEmpty && safeRecs.isEmpty) {
      summary = 'Недостаточно данных для безопасного вывода.';
    }

    return InsightResult(
      keywords: input.keywords.take(10).toList(),
      stateSummary: summary,
      overallInsight: overall,
      recommendations: safeRecs,
      recommendationReasons: safeReasons,
      confidence: input.confidence,
      dataQualityScore: input.dataQualityScore,
      insufficientData: input.insufficientData,
      personalizationScores: input.personalizationScores,
      recommendationScores: input.recommendationScores,
      error: input.error,
    );
  }

  bool _isSevereRisk(InsightResult input) {
    final text = '${input.stateSummary} ${input.overallInsight}'.toLowerCase();
    return text.contains('снижено') &&
        input.confidence >= 0.7 &&
        input.recommendations.any((r) => r.toLowerCase().contains('сна'));
  }

  String _sanitizeText(String text) {
    var out = text.trim();
    for (final term in _unsafeDiagnosisTerms) {
      out = out.replaceAll(RegExp(term, caseSensitive: false), 'состояние');
    }
    return out;
  }
}
