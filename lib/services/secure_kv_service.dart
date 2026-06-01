import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureKvService {
  SecureKvService._();
  static final SecureKvService instance = SecureKvService._();

  /// EncryptedSharedPreferences стабильнее на части Samsung/Release-сборок.
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
  );

  Future<String?> readString(String key) async {
    return _secure.read(key: key);
  }

  Future<void> writeString(String key, String value) async {
    await _secure.write(key: key, value: value);
  }

  Future<void> delete(String key) async {
    await _secure.delete(key: key);
  }

  Future<String?> readWithMigration(String key) async {
    final secureValue = await readString(key);
    if (secureValue != null && secureValue.isNotEmpty) {
      return secureValue;
    }

    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(key);
    if (legacy != null && legacy.isNotEmpty) {
      await writeString(key, legacy);
      await prefs.remove(key);
      return legacy;
    }
    return null;
  }
}
