import '../models/aggregated_data.dart';
import '../models/calendar_entry.dart';
import '../models/insight_result.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'calendar_storage.dart';
import 'insight_safety_service.dart';
import 'local_insights_service.dart';
import '../neural/neural_insights_service.dart';
import 'notes_storage.dart';
import 'quality_metrics_service.dart';
import 'state_storage.dart';

/// Агрегирует все данные и получает инсайты для экрана статистики.
/// Анализ выполняется локально на устройстве — данные никуда не отправляются.
class InsightsService {
  static const _keyAbMode = 'insights_ab_mode';
  static const _keyAbUpdatedAt = 'insights_ab_updated_at';
  static const _keyAbManualMode = 'insights_ab_manual_mode';

  InsightsService._();
  static InsightsService get instance => _instance;
  static final _instance = InsightsService._();

  Future<AggregatedData> aggregateData() async {
    final notes = await NotesStorage.instance.loadAll();
    final stateEntries = await StateStorage.instance.loadAll();
    final calendarEntries = await CalendarStorage.instance.loadAll();

    return AggregatedData(
      notes: notes,
      stateEntries: stateEntries,
      medications: calendarEntries.whereType<Medication>().toList(),
      appointments: calendarEntries.whereType<Appointment>().toList(),
    );
  }

  /// Локальный анализ нейросетью: ключевые слова, резюме, выводы, рекомендации.
  /// Самописная нейросеть анализирует заметки и записи о состоянии.
  Future<InsightResult> getInsights(AggregatedData data) async {
    final mode = await _resolveAbMode();
    InsightResult result;
    if (mode == 'rule') {
      result = await LocalInsightsService.instance.getInsights(data);
    } else {
      result = await NeuralInsightsService.instance.getInsights(data);
    }
    final calibrated = await _withCalibratedConfidence(result);
    return InsightSafetyService.instance.apply(calibrated);
  }

  Future<InsightResult> _withCalibratedConfidence(InsightResult input) async {
    final calibratedConfidence =
        await QualityMetricsService.instance.calibrateConfidence(input.confidence);
    return InsightResult(
      keywords: input.keywords,
      stateSummary: input.stateSummary,
      overallInsight: input.overallInsight,
      recommendations: input.recommendations,
      recommendationReasons: input.recommendationReasons,
      confidence: calibratedConfidence,
      dataQualityScore: input.dataQualityScore,
      insufficientData: input.insufficientData,
      personalizationScores: input.personalizationScores,
      recommendationScores: input.recommendationScores,
      error: input.error,
    );
  }

  Future<String> _resolveAbMode() async {
    final prefs = await SharedPreferences.getInstance();
    final manual = prefs.getString(_keyAbManualMode);
    if (manual == null || manual.isEmpty) {
      await prefs.setString(_keyAbManualMode, 'ml');
      return 'ml';
    }
    if (manual != 'auto') {
      return manual;
    }
    final now = DateTime.now();
    final updatedAtRaw = prefs.getString(_keyAbUpdatedAt);
    final mode = prefs.getString(_keyAbMode);
    if (updatedAtRaw != null && mode != null) {
      final updatedAt = DateTime.tryParse(updatedAtRaw);
      if (updatedAt != null && now.difference(updatedAt).inDays < 1) {
        return mode;
      }
    }

    // Simple on-device A/B: alternate by day to compare rule-only vs rule+ML.
    final nextMode = now.day.isEven ? 'ml' : 'rule';
    await prefs.setString(_keyAbMode, nextMode);
    await prefs.setString(_keyAbUpdatedAt, now.toIso8601String());
    return nextMode;
  }

  Future<void> setManualAbMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAbManualMode, mode);
  }

  Future<String> getManualAbMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAbManualMode) ?? 'ml';
  }
}
