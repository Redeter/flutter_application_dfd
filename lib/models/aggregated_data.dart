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

  /// Включительно по календарным дням [start]…[end] (00:00 локальных дат).
  AggregatedData filterByInclusiveDayRange(DateTime start, DateTime end) {
    DateTime d0(DateTime d) => DateTime(d.year, d.month, d.day);
    final s = d0(start);
    final e = d0(end);
    bool inR(DateTime d) {
      final c = d0(d);
      return !c.isBefore(s) && !c.isAfter(e);
    }

    return AggregatedData(
      notes: notes.where((n) => inR(n.date)).toList(),
      stateEntries: stateEntries.where((x) => inR(x.createdAt)).toList(),
      medications: medications.where((m) => inR(m.date)).toList(),
      appointments: appointments.where((a) => inR(a.date)).toList(),
    );
  }
}
