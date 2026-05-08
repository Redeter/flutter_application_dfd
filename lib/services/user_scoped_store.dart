import 'auth_service.dart';
import 'user_storage_keys.dart';

/// Префикс локальных ключей для активной сессии пользователя.
class UserScopedStore {
  UserScopedStore._();

  static Future<String> scopedKey(String baseKey) async {
    final uid = await AuthService.instance.requireSessionUserId();
    return UserStorageKeys.forUser(uid, baseKey);
  }
}
