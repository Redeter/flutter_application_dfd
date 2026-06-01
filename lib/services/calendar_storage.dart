import 'dart:convert';

import '../models/calendar_entry.dart';
import 'firestore_repository.dart';
import 'secure_kv_service.dart';
import 'user_scoped_store.dart';

const _keyCalendar = 'calendar_entries';

class CalendarStorage {
  CalendarStorage._();
  static CalendarStorage get instance => _instance;
  static final _instance = CalendarStorage._();

  List<CalendarEntry>? _cache;

  void clearCache() {
    _cache = null;
  }

  List<CalendarEntry> _parseList(List<dynamic>? list) {
    if (list == null) return [];
    final result = <CalendarEntry>[];
    for (final item in list) {
      final map = item is Map<String, dynamic>
          ? item
          : item is Map
              ? Map<String, dynamic>.from(item)
              : null;
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
  }

  Future<List<CalendarEntry>> loadAll({bool forceRemote = false}) async {
    if (!forceRemote && _cache != null) {
      return List<CalendarEntry>.from(_cache!);
    }

    final cloud = await FirestoreRepository.instance
        .loadJsonList(FirestoreRepository.fieldCalendar);
    if (cloud != null) {
      final parsed = _parseList(cloud);
      _cache = parsed;
      return List<CalendarEntry>.from(parsed);
    }

    final key = await UserScopedStore.scopedKey(_keyCalendar);
    final raw = await SecureKvService.instance.readString(key);
    if (raw == null || raw.isEmpty) {
      _cache = const [];
      return [];
    }

    try {
      final parsed = _parseList(jsonDecode(raw) as List<dynamic>?);
      _cache = parsed;
      return List<CalendarEntry>.from(parsed);
    } catch (_) {
      _cache = const [];
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
    final encoded = list.map((e) => e.toJson()).toList();
    _cache = List<CalendarEntry>.from(list);

    final key = await UserScopedStore.scopedKey(_keyCalendar);
    await SecureKvService.instance.writeString(key, jsonEncode(encoded));

    await FirestoreRepository.instance.saveJsonList(
      FirestoreRepository.fieldCalendar,
      encoded.cast<Map<String, dynamic>>(),
    );
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
