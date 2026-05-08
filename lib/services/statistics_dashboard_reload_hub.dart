/// Одноактивный экран статистики подписывается перезагрузкой данных после записи через «Плюс».
class StatisticsDashboardReloadHub {
  StatisticsDashboardReloadHub._();
  static final StatisticsDashboardReloadHub instance =
      StatisticsDashboardReloadHub._();

  Object? _owner;
  void Function()? _reloadQuiet;

  void attachQuietReload(Object owner, void Function() reloadQuiet) {
    _owner = owner;
    _reloadQuiet = reloadQuiet;
  }

  void detachQuietReload(Object owner) {
    if (_owner == owner) {
      _owner = null;
      _reloadQuiet = null;
    }
  }

  void requestQuietReload() => _reloadQuiet?.call();
}
