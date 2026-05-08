import 'package:shared_preferences/shared_preferences.dart';

import 'user_scoped_store.dart';

/// Диапазон недели статистики (Пн–Вс), чтобы фундамент мог считаться на тех же данных.
class StatsPeriodSync {
  StatsPeriodSync._();

  static const _kStart = 'stats_foundation_sync_week_start_v1';
  static const _kEnd = 'stats_foundation_sync_week_end_v1';

  static const _monthsShort = [
    'янв', 'фев', 'мар', 'апр', 'май', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
  ];

  /// Неделя календаря, содержащая [anchor] (как на экране статистики при «неделя»).
  static (DateTime start, DateTime end) weekRangeContaining(DateTime anchor) {
    final d = DateTime(anchor.year, anchor.month, anchor.day);
    final start = d.subtract(Duration(days: d.weekday - 1));
    final end = start.add(const Duration(days: 6));
    return (
      DateTime(start.year, start.month, start.day),
      DateTime(end.year, end.month, end.day),
    );
  }

  static Future<void> persistWeekContaining(DateTime selectedDay) async {
    final (s, e) = weekRangeContaining(selectedDay);
    final prefs = await SharedPreferences.getInstance();
    final startKey = await UserScopedStore.scopedKey(_kStart);
    final endKey = await UserScopedStore.scopedKey(_kEnd);
    await prefs.setString(startKey, s.toIso8601String());
    await prefs.setString(endKey, e.toIso8601String());
  }

  static Future<(DateTime?, DateTime?)> loadRange() async {
    final prefs = await SharedPreferences.getInstance();
    final startKey = await UserScopedStore.scopedKey(_kStart);
    final endKey = await UserScopedStore.scopedKey(_kEnd);
    final a = prefs.getString(startKey);
    final b = prefs.getString(endKey);
    if (a == null || b == null) return (null, null);
    return (DateTime.tryParse(a), DateTime.tryParse(b));
  }

  static String formatRangeRu(DateTime start, DateTime end) {
    String one(DateTime d) =>
        '${d.day} ${_monthsShort[d.month - 1]}${d.year != DateTime.now().year ? ' ${d.year}' : ''}';
    return '${one(start)} — ${one(end)}';
  }
}
