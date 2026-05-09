import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../utils/pbkdf2_sha256.dart';
import 'dev_data_seed_service.dart';
import 'secure_kv_service.dart';

class AuthUsernameTakenException implements Exception {
  AuthUsernameTakenException([this.message = 'Это имя пользователя уже занято']);
  final String message;

  @override
  String toString() => message;
}

/// Локальная аутентификация и текущая сессия пользователя.
///
/// Несколько аккаунтов на одном устройстве: каждый имеет свой `userId` и своё
/// поддерево ключей (`user:{userId}:…`).
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const registryKey = 'auth_registry_v2';
  static const sessionUserIdKey = 'auth_session_user_id_v2';
  static const rememberSessionKey = 'auth_remember_v2';

  static String credentialStorageKeyFor(String userId) => 'auth_cred_v2_$userId';

  static const _pbkdf2Iterations = 310000;

  final _uuid = const Uuid();

  /// Для юнит-тестов: подставить активного пользователя без Secure Storage.
  String? debugSessionUserIdOverride;

  String _normalizeUsername(String raw) => raw.trim().toLowerCase();

  Future<Map<String, dynamic>> _registryRoot() async {
    final raw = await SecureKvService.instance.readString(registryKey);
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

  Future<void> _saveRegistry(Map<String, dynamic> root) async {
    await SecureKvService.instance.writeString(registryKey, jsonEncode(root));
  }

  Future<String?> sessionUserId() async {
    if (debugSessionUserIdOverride != null) {
      return debugSessionUserIdOverride;
    }
    final id = await SecureKvService.instance.readString(sessionUserIdKey);
    if (id == null || id.isEmpty) return null;
    return id;
  }

  Future<String> requireSessionUserId() async {
    final id = await sessionUserId();
    if (id == null || id.isEmpty) {
      throw StateError('Нет активной сессии пользователя');
    }
    return id;
  }

  /// Только тесты и [NeuralInsightsService.debugResetForTests]: подставить сессию без Secure Storage.
  void setFixtureSessionUserId(String? userId) {
    debugSessionUserIdOverride = userId;
  }

  Future<bool> hasAnyRegisteredUser() async {
    final root = await _registryRoot();
    final users = Map<String, dynamic>.from(root['users'] as Map? ?? {});
    return users.isNotEmpty;
  }

  Future<bool> isUsernameTaken(String username) async {
    final norm = _normalizeUsername(username);
    if (norm.isEmpty) return false;
    final root = await _registryRoot();
    final users = Map<String, dynamic>.from(root['users'] as Map? ?? {});
    return users.containsKey(norm);
  }

  Future<String?> username() async {
    final uid = await sessionUserId();
    if (uid == null) return null;
    final root = await _registryRoot();
    final displays =
        Map<String, dynamic>.from(root['displayNames'] as Map? ?? {});
    return displays[uid] as String?;
  }

  Future<void> register({
    required String username,
    required String password,
  }) async {
    final display = username.trim();
    final norm = _normalizeUsername(username);
    if (norm.isEmpty) return;

    final root = await _registryRoot();
    final users = Map<String, dynamic>.from(root['users'] as Map? ?? {});
    final displays =
        Map<String, dynamic>.from(root['displayNames'] as Map? ?? {});

    if (users.containsKey(norm)) {
      throw AuthUsernameTakenException();
    }

    final userId = _uuid.v4();
    users[norm] = userId;
    displays[userId] = display;

    await SecureKvService.instance.writeString(
      credentialStorageKeyFor(userId),
      _encodePassword(password),
    );

    root['users'] = users;
    root['displayNames'] = displays;
    await _saveRegistry(root);

    await SecureKvService.instance.writeString(sessionUserIdKey, userId);
    await SecureKvService.instance.writeString(rememberSessionKey, 'false');
  }

  Future<bool> login({
    required String username,
    required String password,
    bool rememberSession = false,
  }) async {
    final norm = _normalizeUsername(username);
    final root = await _registryRoot();
    final users = Map<String, dynamic>.from(root['users'] as Map? ?? {});
    final userId = users[norm] as String?;
    if (userId == null) return false;

    final ok =
        await _verifyPassword(userId: userId, password: password);
    if (!ok) return false;

    await SecureKvService.instance.writeString(sessionUserIdKey, userId);
    await _setRememberSession(rememberSession);
    return true;
  }

  Future<void> logout() async {
    await SecureKvService.instance.delete(sessionUserIdKey);
    await SecureKvService.instance.writeString(rememberSessionKey, 'false');
  }

  /// Полное удаление текущего аккаунта на устройстве (локальные данные, учётная запись, пароль).
  /// Возвращает `false`, если пароль неверный или нет активной сессии.
  Future<bool> deleteAccount({required String password}) async {
    final uid = await sessionUserId();
    if (uid == null) return false;
    if (!await _verifyPassword(userId: uid, password: password)) return false;

    await DevDataSeedService.instance.wipeScopedDataForUser(uid);

    final root = await _registryRoot();
    final users = Map<String, dynamic>.from(root['users'] as Map? ?? {});
    final displays = Map<String, dynamic>.from(root['displayNames'] as Map? ?? {});

    String? normToRemove;
    for (final e in users.entries) {
      if (e.value == uid) {
        normToRemove = e.key;
        break;
      }
    }
    if (normToRemove != null) users.remove(normToRemove);
    displays.remove(uid);

    root['users'] = users;
    root['displayNames'] = displays;
    await _saveRegistry(root);

    await SecureKvService.instance.delete(credentialStorageKeyFor(uid));
    await logout();
    return true;
  }

  Future<bool> shouldAutoLogin() async {
    if (debugSessionUserIdOverride != null) {
      return true;
    }
    final remember =
        await SecureKvService.instance.readString(rememberSessionKey);
    final uid = await SecureKvService.instance.readString(sessionUserIdKey);
    return remember == 'true' && uid != null && uid.isNotEmpty;
  }

  Future<void> _setRememberSession(bool remember) async {
    await SecureKvService.instance.writeString(
      rememberSessionKey,
      remember ? 'true' : 'false',
    );
  }

  String _encodePassword(String password) {
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    final hash = pbkdf2Sha256(
      password: utf8.encode(password),
      salt: salt,
      iterations: _pbkdf2Iterations,
      dkLen: 32,
    );
    return encodePasswordRecord(
      iterations: _pbkdf2Iterations,
      salt: salt,
      hash: hash,
    );
  }

  Future<bool> _verifyPassword({
    required String userId,
    required String password,
  }) async {
    final stored = await SecureKvService.instance.readString(
      credentialStorageKeyFor(userId),
    );
    if (stored == null || stored.isEmpty) return false;

    if (verifyPasswordAgainstRecord(password, stored)) {
      return true;
    }

    final trimmed = stored.trim();
    if (trimmed.length == 64 &&
        RegExp(r'^[a-f0-9]+$').hasMatch(trimmed)) {
      final h = sha256.convert(utf8.encode(password)).toString();
      if (h == trimmed) {
        await _upgradeStoredPassword(userId, password);
        return true;
      }
    }

    if (trimmed == _legacyEncode(password)) {
      await _upgradeStoredPassword(userId, password);
      return true;
    }

    return false;
  }

  Future<void> _upgradeStoredPassword(String userId, String password) async {
    await SecureKvService.instance.writeString(
      credentialStorageKeyFor(userId),
      _encodePassword(password),
    );
  }

  String _legacyEncode(String value) => base64Encode(utf8.encode(value));
}
