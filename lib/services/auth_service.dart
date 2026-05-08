import 'dart:convert';

import 'secure_kv_service.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _keyUsername = 'auth_username_v1';
  static const _keyPassword = 'auth_password_v1';

  Future<bool> hasAccount() async {
    final username = await SecureKvService.instance.readString(_keyUsername);
    final password = await SecureKvService.instance.readString(_keyPassword);
    return (username?.isNotEmpty ?? false) && (password?.isNotEmpty ?? false);
  }

  Future<String?> username() async {
    return SecureKvService.instance.readString(_keyUsername);
  }

  Future<void> register({
    required String username,
    required String password,
  }) async {
    await SecureKvService.instance.writeString(_keyUsername, username.trim());
    await SecureKvService.instance.writeString(
      _keyPassword,
      _encode(password),
    );
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    final savedUsername = await SecureKvService.instance.readString(_keyUsername);
    final savedPassword = await SecureKvService.instance.readString(_keyPassword);
    if (savedUsername == null || savedPassword == null) return false;
    return savedUsername.trim() == username.trim() &&
        savedPassword == _encode(password);
  }

  Future<void> logout() async {
    await SecureKvService.instance.delete(_keyUsername);
    await SecureKvService.instance.delete(_keyPassword);
  }

  String _encode(String value) => base64Encode(utf8.encode(value));
}
