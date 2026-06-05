import 'calendar_storage.dart';

/// Сброс in-memory кэша при смене пользователя (вход, регистрация, выход).
class SessionDataCache {
  SessionDataCache._();

  static void clear() {
    CalendarStorage.instance.clearCache();
  }
}
