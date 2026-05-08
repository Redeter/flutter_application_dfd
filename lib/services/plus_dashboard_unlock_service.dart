import 'package:shared_preferences/shared_preferences.dart';

import 'statistics_dashboard_reload_hub.dart';
import 'user_scoped_store.dart';

/// Кольца сводки и карточки метрик на статистике доступны после первой сохранённой
/// записи состояния через меню центральной кнопки «Плюс».
class PlusDashboardUnlockService {
  PlusDashboardUnlockService._();
  static final PlusDashboardUnlockService instance = PlusDashboardUnlockService._();

  static const prefsBaseKey = 'stats_dashboard_unlocked_via_center_plus_v1';

  Future<void> markUnlockedAfterPlusEntry() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await UserScopedStore.scopedKey(prefsBaseKey);
    await prefs.setBool(key, true);
    StatisticsDashboardReloadHub.instance.requestQuietReload();
  }

  Future<bool> isUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await UserScopedStore.scopedKey(prefsBaseKey);
    return prefs.getBool(key) ?? false;
  }
}
