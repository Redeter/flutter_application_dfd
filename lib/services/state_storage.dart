import 'dart:convert';

import '../models/state_entries.dart';
import 'firestore_repository.dart';
import 'goals_dashboard_reload_hub.dart';
import 'secure_kv_service.dart';
import 'statistics_dashboard_reload_hub.dart';
import 'user_scoped_store.dart';

const _keyStateEntries = 'state_entries';

class StateStorage {
  StateStorage._();
  static StateStorage get instance => _instance;
  static final _instance = StateStorage._();

  List<StateEntryBase> _parseList(List<dynamic>? list) {
    if (list == null) return [];
    final result = <StateEntryBase>[];
    for (final item in list) {
      final map = item is Map<String, dynamic>
          ? item
          : item is Map
              ? Map<String, dynamic>.from(item)
              : null;
      if (map == null) continue;

      final type = map['type'] as String?;
      StateEntryBase? entry;
      switch (type) {
        case 'mood':
          entry = MoodEntry.fromJson(map);
          break;
        case 'emotions':
          entry = EmotionsEntry.fromJson(map);
          break;
        case 'sleep':
          entry = SleepEntry.fromJson(map);
          break;
        case 'nutrition':
          entry = NutritionEntry.fromJson(map);
          break;
        case 'energy':
          entry = EnergyEntry.fromJson(map);
          break;
      }
      if (entry != null) result.add(entry);
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<List<StateEntryBase>> loadAll() async {
    final cloud = await FirestoreRepository.instance
        .loadJsonList(FirestoreRepository.fieldState);
    if (cloud != null) {
      return _parseList(cloud);
    }

    final key = await UserScopedStore.scopedKey(_keyStateEntries);
    final raw = await SecureKvService.instance.readString(key);
    if (raw == null || raw.isEmpty) return [];

    try {
      return _parseList(jsonDecode(raw) as List<dynamic>?);
    } catch (_) {
      return [];
    }
  }

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _sameCalendarDay(DateTime a, DateTime b) =>
      _dayOnly(a) == _dayOnly(b);

  Future<void> save(StateEntryBase entry) async {
    final all = await loadAll();
    all.insert(0, entry);
    await _write(all);
  }

  /// Одна запись питания на календарный день (для целей и «+»).
  Future<void> saveOrReplaceNutritionForDay(NutritionEntry entry) async {
    final all = await loadAll();
    all.removeWhere(
      (e) => e is NutritionEntry && _sameCalendarDay(e.createdAt, entry.createdAt),
    );
    all.insert(0, entry);
    await _write(all);
  }

  Future<NutritionEntry?> loadNutritionForDay(DateTime day) async {
    final all = await loadAll();
    for (final e in all) {
      if (e is NutritionEntry && _sameCalendarDay(e.createdAt, day)) {
        return e;
      }
    }
    return null;
  }

  Future<void> clearNutritionForDay(DateTime day) async {
    final all = await loadAll();
    all.removeWhere(
      (e) => e is NutritionEntry && _sameCalendarDay(e.createdAt, day),
    );
    await _write(all);
  }

  Future<List<T>> loadByCategory<T extends StateEntryBase>(
    StateCategory category,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final all = await loadAll();
    return all
        .where((e) => e.category == category)
        .map((e) => fromJson(e.toJson()))
        .toList();
  }

  Future<void> _write(List<StateEntryBase> all) async {
    final encoded = all.map((e) => e.toJson()).toList();

    await FirestoreRepository.instance.saveJsonList(
      FirestoreRepository.fieldState,
      encoded.cast<Map<String, dynamic>>(),
    );

    final key = await UserScopedStore.scopedKey(_keyStateEntries);
    await SecureKvService.instance.writeString(key, jsonEncode(encoded));

    StatisticsDashboardReloadHub.instance.requestQuietReload();
    GoalsDashboardReloadHub.instance.requestQuietReload();
  }
}
