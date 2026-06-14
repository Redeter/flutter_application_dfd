import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_dfd/models/calendar_entry.dart';
import 'package:flutter_application_dfd/utils/stats_helpers.dart';

Medication _med({
  required String id,
  required DateTime date,
  String? seriesId,
  String name = 'Аспирин',
  String dosage = '100мг',
}) {
  return Medication(
    id: id,
    date: date,
    time: const TimeOfDay(hour: 8, minute: 0),
    name: name,
    dosage: dosage,
    schedule: const [
      MedicationDose(time: TimeOfDay(hour: 8, minute: 0), amount: '1 таблетка'),
    ],
    seriesId: seriesId,
  );
}

void main() {
  group('medicationsShareSeries', () {
    test('matches all days with the same seriesId', () {
      final anchor = _med(
        id: 'a',
        date: DateTime(2026, 1, 1),
        seriesId: 'series_1',
      );
      final distant = _med(
        id: 'b',
        date: DateTime(2026, 12, 31),
        seriesId: 'series_1',
      );

      expect(medicationsShareSeries(anchor, distant), isTrue);
    });

    test('matches legacy entries without seriesId by name dosage and schedule', () {
      final anchor = _med(
        id: 'a',
        date: DateTime(2026, 1, 1),
      );
      final distant = _med(
        id: 'b',
        date: DateTime(2026, 6, 1),
      );

      expect(medicationsShareSeries(anchor, distant), isTrue);
    });

    test('does not match different series with the same name', () {
      final anchor = _med(
        id: 'a',
        date: DateTime(2026, 1, 1),
        seriesId: 'series_1',
      );
      final otherSeries = _med(
        id: 'b',
        date: DateTime(2026, 6, 1),
        seriesId: 'series_2',
      );

      expect(medicationsShareSeries(anchor, otherSeries), isFalse);
    });
  });
}
