import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_kv_service.dart';
import 'user_storage_keys.dart';

/// Одноразовая миграция с общих ключей на ключи вида `user:{userId}:*`.
class StorageMigrationService {
  StorageMigrationService._();
  static final StorageMigrationService instance = StorageMigrationService._();

  static const _doneFlag = 'storage_migration_v3_done';
  static const _sessionUserIdKey = 'auth_session_user_id_v2';
  static const _rememberKey = 'auth_remember_v2';

  static String _credentialKey(String userId) => 'auth_cred_v2_$userId';

  Future<void> ensureMigrated() async {
    if (await SecureKvService.instance.readString(_doneFlag) == 'true') {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final legacyUser = await SecureKvService.instance.readString('auth_username_v1');
    final legacyPw = await SecureKvService.instance.readString('auth_password_v1');

    Map<String, dynamic> registry = _parseRegistry(
      await SecureKvService.instance.readString('auth_registry_v2'),
    );

    final users = Map<String, dynamic>.from(registry['users'] as Map? ?? {});
    final displays = Map<String, dynamic>.from(registry['displayNames'] as Map? ?? {});

    String? targetId;

    if (legacyUser != null && legacyUser.trim().isNotEmpty) {
      final norm = legacyUser.trim().toLowerCase();
      final uid = users[norm] as String? ??
          'legacy_${sha256.convert(utf8.encode(norm)).toString()}';
      targetId = uid;
      users[norm] = uid;
      displays[uid] = legacyUser.trim();

      if (legacyPw != null && legacyPw.isNotEmpty) {
        await SecureKvService.instance.writeString(_credentialKey(uid), legacyPw);
      }
    } else if (await _hasAnyLegacyGlobalData(prefs)) {
      targetId = 'legacy_device_unauthenticated';
    }

    if (targetId != null) {
      for (final base in UserStorageKeys.secureStringBases) {
        await _migrateSecureString(prefs, targetId, base);
      }
      for (final base in UserStorageKeys.prefsOnlyBases) {
        await _migratePrefsEntry(prefs, targetId, base);
      }

      registry['users'] = users;
      registry['displayNames'] = displays;
      await SecureKvService.instance.writeString(
        'auth_registry_v2',
        jsonEncode(registry),
      );

      await SecureKvService.instance.writeString(_sessionUserIdKey, targetId);

      final rememberLegacy =
          await SecureKvService.instance.readString('auth_remember_session_v1');
      await SecureKvService.instance.writeString(
        _rememberKey,
        rememberLegacy ?? 'false',
      );

      await SecureKvService.instance.delete('auth_username_v1');
      await SecureKvService.instance.delete('auth_password_v1');
      await SecureKvService.instance.delete('auth_remember_session_v1');
    }

    await SecureKvService.instance.writeString(_doneFlag, 'true');
  }

  Map<String, dynamic> _parseRegistry(String? raw) {
    if (raw == null || raw.isEmpty) {
      return {
        'users': <String, dynamic>{},
        'displayNames': <String, dynamic>{},
      };
    }
    try {
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      m['users'] = Map<String, dynamic>.from(m['users'] as Map? ?? {});
      m['displayNames'] =
          Map<String, dynamic>.from(m['displayNames'] as Map? ?? {});
      return m;
    } catch (_) {
      return {
        'users': <String, dynamic>{},
        'displayNames': <String, dynamic>{},
      };
    }
  }

  Future<bool> _hasAnyLegacyGlobalData(SharedPreferences prefs) async {
    for (final base in UserStorageKeys.secureStringBases) {
      final s = await SecureKvService.instance.readString(base);
      if (s != null && s.isNotEmpty) return true;
    }
    for (final base in UserStorageKeys.prefsOnlyBases) {
      if (prefs.containsKey(base)) return true;
    }
    return false;
  }

  Future<void> _migrateSecureString(
    SharedPreferences prefs,
    String userId,
    String base,
  ) async {
    var raw = await SecureKvService.instance.readString(base);
    raw ??= prefs.getString(base);
    if (raw == null || raw.isEmpty) return;
    final scoped = UserStorageKeys.forUser(userId, base);
    await SecureKvService.instance.writeString(scoped, raw);
    await SecureKvService.instance.delete(base);
    await prefs.remove(base);
  }

  Future<void> _migratePrefsEntry(
    SharedPreferences prefs,
    String userId,
    String base,
  ) async {
    if (!prefs.containsKey(base)) return;
    final scoped = UserStorageKeys.forUser(userId, base);
    final val = prefs.get(base);
    if (val is String) {
      await prefs.setString(scoped, val);
    } else if (val is int) {
      await prefs.setInt(scoped, val);
    } else if (val is bool) {
      await prefs.setBool(scoped, val);
    } else if (val is double) {
      await prefs.setDouble(scoped, val);
    }
    await prefs.remove(base);
  }
}
