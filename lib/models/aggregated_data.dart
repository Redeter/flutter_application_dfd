import 'calendar_entry.dart';
import 'note_item.dart';
import 'state_entries.dart';

/// Агрегированные данные для анализа (заметки, состояние, календарь).
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
