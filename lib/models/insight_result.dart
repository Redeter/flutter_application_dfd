/// Результат ИИ-анализа для экрана статистики.
class InsightResult {
  const InsightResult({
    this.keywords = const [],
    this.stateSummary = '',
    this.overallInsight = '',
    this.recommendations = const [],
    this.error,
  });

  final List<String> keywords;
  final String stateSummary;
  final String overallInsight;
  final List<String> recommendations;
  final String? error;

  bool get hasError => error != null && error!.isNotEmpty;

  static InsightResult fromError(String message) =>
      InsightResult(error: message);
}
