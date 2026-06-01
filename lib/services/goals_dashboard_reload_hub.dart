/// Экран целей подписывается на тихую перезагрузку после записи через «Плюс».
class GoalsDashboardReloadHub {
  GoalsDashboardReloadHub._();
  static final GoalsDashboardReloadHub instance = GoalsDashboardReloadHub._();

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
