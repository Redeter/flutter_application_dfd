import '../models/aggregated_data.dart';
import '../models/calendar_entry.dart';
import '../models/insight_result.dart';
import 'calendar_storage.dart';
import '../neural/neural_insights_service.dart';
import 'notes_storage.dart';
import 'state_storage.dart';

/// Агрегирует все данные и получает инсайты для экрана статистики.
/// Анализ выполняется локально на устройстве — данные никуда не отправляются.
class InsightsService {
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
    return NeuralInsightsService.instance.getInsights(data);
  }
}
