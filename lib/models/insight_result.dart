/// Результат ИИ-анализа для экрана статистики.
class InsightResult {
  const InsightResult({
    this.keywords = const [],
    this.stateSummary = '',
    this.overallInsight = '',
    this.recommendations = const [],
    this.recommendationReasons = const {},
    this.confidence = 0,
    this.dataQualityScore = 0,
    this.insufficientData = false,
    this.personalizationScores = const {},
    this.recommendationScores = const {},
    this.error,
  });

  final List<String> keywords;
  final String stateSummary;
  final String overallInsight;
  final List<String> recommendations;
  final Map<String, List<String>> recommendationReasons;
  final double confidence;
  final double dataQualityScore;
  final bool insufficientData;
  final Map<String, double> personalizationScores;
  final Map<String, double> recommendationScores;
  final String? error;

  bool get hasError => error != null && error!.isNotEmpty;

  static InsightResult fromError(String message) =>
      InsightResult(error: message);
}
