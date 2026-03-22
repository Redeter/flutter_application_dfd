import '../models/calendar_entry.dart';
import '../models/insight_result.dart';
import '../models/note_item.dart';
import '../models/state_entries.dart';
import 'calendar_storage.dart';
import 'local_insights_service.dart';
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

  /// Локальный анализ: ключевые слова, резюме, выводы, рекомендации.
  /// Система сохраняет паттерны (дни недели, связь сна и настроения)
  /// и со временем даёт более персонализированные советы.
  Future<InsightResult> getInsights(AggregatedData data) async {
    return LocalInsightsService.instance.getInsights(data);
  }
}

/// Агрегированные данные для анализа.
class AggregatedData {
  AggregatedData({
    required this.notes,
    required this.stateEntries,
    required this.medications,
    required this.appointments,
  });

  final List<NoteItem> notes;
  final List<StateEntryBase> stateEntries;
  final List<Medication> medications;
  final List<Appointment> appointments;
}
