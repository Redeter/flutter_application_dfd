import 'dart:convert';

import '../models/calendar_entry.dart';
import 'secure_kv_service.dart';

const _keyCalendar = 'calendar_entries';

class CalendarStorage {
  CalendarStorage._();
  static CalendarStorage get instance => _instance;
  static final _instance = CalendarStorage._();

  Future<List<CalendarEntry>> loadAll() async {
    final raw = await SecureKvService.instance.readWithMigration(_keyCalendar);
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>?;
      if (list == null) return [];

      final result = <CalendarEntry>[];
      for (final item in list) {
        final map = item as Map<String, dynamic>?;
        if (map == null) continue;

        final type = map['type'] as String?;
        switch (type) {
          case 'medication':
            result.add(Medication.fromJson(map));
            break;
          case 'appointment':
            result.add(Appointment.fromJson(map));
            break;
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<void> save(CalendarEntry entry) async {
    final all = await loadAll();
    final idx = all.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      all[idx] = entry;
    } else {
      all.add(entry);
    }
    await _write(all);
  }

  /// Одна запись на диск вместо многократного [save] (например серия ежедневных приёмов).
  Future<void> saveMany(List<CalendarEntry> entries) async {
    if (entries.isEmpty) return;
    final all = await loadAll();
    for (final entry in entries) {
      final idx = all.indexWhere((e) => e.id == entry.id);
      if (idx >= 0) {
        all[idx] = entry;
      } else {
        all.add(entry);
      }
    }
    await _write(all);
  }

  Future<void> delete(String id) async {
    final all = await loadAll();
    all.removeWhere((e) => e.id == id);
    await _write(all);
  }

  /// Удаляет препарат: если у записи есть [Medication.seriesId], убираются все дни этой серии.
  Future<void> deleteMedication(Medication m) async {
    final all = await loadAll();
    final sid = m.seriesId;
    if (sid != null && sid.isNotEmpty) {
      all.removeWhere((e) => e is Medication && e.seriesId == sid);
    } else {
      all.removeWhere((e) => e.id == m.id);
    }
    await _write(all);
  }

  Future<void> _write(List<CalendarEntry> list) async {
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await SecureKvService.instance.writeString(_keyCalendar, encoded);
  }

  Future<List<CalendarEntry>> loadForDate(DateTime date) async {
    final all = await loadAll();
    final d = DateTime(date.year, date.month, date.day);
    return all.where((e) {
      final ed = DateTime(e.date.year, e.date.month, e.date.day);
      return ed == d;
    }).toList()
      ..sort((a, b) {
        final ta = a.time.hour * 60 + a.time.minute;
        final tb = b.time.hour * 60 + b.time.minute;
        return ta.compareTo(tb);
      });
  }
}
