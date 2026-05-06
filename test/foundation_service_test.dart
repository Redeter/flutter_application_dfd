import 'package:flutter_application_dfd/models/aggregated_data.dart';
import 'package:flutter_application_dfd/models/calendar_entry.dart';
import 'package:flutter_application_dfd/models/foundation_score.dart';
import 'package:flutter_application_dfd/models/note_item.dart';
import 'package:flutter_application_dfd/services/foundation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  const goals = FoundationGoals();
  const cap = 'Тестовый период';

  test('compute empty data — ноль кирпичей и пояснение', () {
    final data = AggregatedData(
      notes: const [],
      stateEntries: const [],
      medications: const [],
      appointments: const [],
    );
    final s = FoundationService.instance.compute(data, goals, statsPeriodCaption: cap);
    expect(s.filledBricks, 0);
    expect(s.rawOverallProgress, 0);
    expect(s.history30d.length, 30);
    expect(s.historyDayDetails.length, 30);
    expect(s.medicationAdherenceRate, isNull);
  });

  test('только заметки — регулярность и окно > 0', () {
    final day = DateTime(2026, 1, 10);
    final data = AggregatedData(
      notes: [
        NoteItem(
          date: day,
          title: 't',
          tags: const [],
          preview: 'p',
          sticker: NoteStickerKind.sun,
        ),
      ],
      stateEntries: const [],
      medications: const [],
      appointments: const [],
    );
    final s = FoundationService.instance.compute(data, goals, statsPeriodCaption: cap);
    expect(s.spheres.any((e) => e.id == 'consistency'), true);
    expect(s.dataSourcesSummary.contains('заметок 1'), true);
  });

  test('только календарь — adherence при отмеченном приёме', () {
    final day = DateTime(2026, 2, 1);
    final med = Medication(
      id: '1',
      date: day,
      time: const TimeOfDay(hour: 9, minute: 0),
      name: 'x',
      dosage: '1',
      schedule: const [
        MedicationDose(time: TimeOfDay(hour: 9, minute: 0), amount: '1'),
      ],
      takenAtPerDose: [day.add(const Duration(hours: 1))],
    );
    final data = AggregatedData(
      notes: const [],
      stateEntries: const [],
      medications: [med],
      appointments: const [],
    );
    final s = FoundationService.instance.compute(data, goals, statsPeriodCaption: cap);
    expect(s.medicationAdherenceRate, closeTo(1.0, 0.01));
    expect(s.medicationAdherenceCaption, isNotEmpty);
  });

  test('filterByInclusiveDayRange отсекает вне диапазона', () {
    final d0 = DateTime(2026, 3, 1);
    final d1 = DateTime(2026, 3, 15);
    final data = AggregatedData(
      notes: [
        NoteItem(
          date: d0,
          title: 'a',
          tags: const [],
          preview: '',
          sticker: NoteStickerKind.sun,
        ),
        NoteItem(
          date: d1,
          title: 'b',
          tags: const [],
          preview: '',
          sticker: NoteStickerKind.sun,
        ),
      ],
      stateEntries: const [],
      medications: const [],
      appointments: const [],
    );
    final f = data.filterByInclusiveDayRange(
      DateTime(2026, 3, 1),
      DateTime(2026, 3, 5),
    );
    expect(f.notes.length, 1);
  });
}
