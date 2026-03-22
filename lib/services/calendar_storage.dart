import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_entry.dart';

const _keyCalendar = 'calendar_entries';

class CalendarStorage {
  CalendarStorage._();
  static CalendarStorage get instance => _instance;
  static final _instance = CalendarStorage._();

  SharedPreferences? _prefs;

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<CalendarEntry>> loadAll() async {
    await _init();
    final raw = _prefs!.getString(_keyCalendar);
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
    await _init();
    final all = await loadAll();
    final idx = all.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      all[idx] = entry;
    } else {
      all.add(entry);
    }
    await _write(all);
  }

  Future<void> delete(String id) async {
    await _init();
    final all = await loadAll();
    all.removeWhere((e) => e.id == id);
    await _write(all);
  }

  Future<void> _write(List<CalendarEntry> list) async {
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs!.setString(_keyCalendar, encoded);
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
