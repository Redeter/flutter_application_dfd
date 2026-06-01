import 'dart:math';
import 'dart:typed_data';

import '../utils/pbkdf2_sha256.dart';
import 'secure_kv_service.dart';
import 'user_scoped_store.dart';

/// Локальный PIN-код (как в банковских приложениях): хеш в Secure Storage, проверка в памяти сессии.
class PinLockService {
  PinLockService._();
  static final PinLockService instance = PinLockService._();

  static const pinLength = 4;
  static const maxAttempts = 5;
  static const lockoutSeconds = 30;

  static const _enabledKey = 'pin_enabled_v1';
  static const _hashKey = 'pin_hash_v1';
  static const _failedAttemptsKey = 'pin_failed_attempts_v1';
  static const _lockoutUntilKey = 'pin_lockout_until_v1';

  bool _sessionUnlocked = false;
  int _memoryFailedAttempts = 0;
  DateTime? _memoryLockoutUntil;

  bool get isSessionUnlocked => _sessionUnlocked;

  void unlockSession() {
    _sessionUnlocked = true;
    _memoryFailedAttempts = 0;
    _memoryLockoutUntil = null;
  }

  void lockSession() {
    _sessionUnlocked = false;
  }

  Future<bool> isEnabled() async {
    final key = await UserScopedStore.scopedKey(_enabledKey);
    final value = await SecureKvService.instance.readString(key);
    return value == 'true';
  }

  Future<DateTime?> lockoutUntil() async {
    if (_memoryLockoutUntil != null) return _memoryLockoutUntil;
    final key = await UserScopedStore.scopedKey(_lockoutUntilKey);
    final raw = await SecureKvService.instance.readString(key);
    if (raw == null || raw.isEmpty) return null;
    final ms = int.tryParse(raw);
    if (ms == null) return null;
    final until = DateTime.fromMillisecondsSinceEpoch(ms);
    if (DateTime.now().isAfter(until)) {
      await _clearLockout();
      return null;
    }
    _memoryLockoutUntil = until;
    return until;
  }

  Future<int> remainingAttempts() async {
    if (await lockoutUntil() != null) return 0;
    if (_memoryFailedAttempts > 0) {
      return max(0, maxAttempts - _memoryFailedAttempts);
    }
    final key = await UserScopedStore.scopedKey(_failedAttemptsKey);
    final raw = await SecureKvService.instance.readString(key);
    final failed = int.tryParse(raw ?? '') ?? 0;
    return max(0, maxAttempts - failed);
  }

  Future<bool> matchesPin(String pin) async {
    if (!_isValidPin(pin)) return false;
    if (await lockoutUntil() != null) return false;

    final hashKey = await UserScopedStore.scopedKey(_hashKey);
    final record = await SecureKvService.instance.readString(hashKey);
    if (record == null || record.isEmpty) return false;

    final ok = verifyPasswordAgainstRecord(pin, record);
    if (ok) {
      await _resetFailedAttempts();
      return true;
    }

    await _registerFailedAttempt();
    return false;
  }

  Future<bool> verifyPin(String pin) async {
    final ok = await matchesPin(pin);
    if (ok) unlockSession();
    return ok;
  }

  Future<void> setPin(String pin) async {
    if (!_isValidPin(pin)) {
      throw ArgumentError('PIN must be $pinLength digits');
    }
    final salt = _randomSalt();
    final hash = pbkdf2Sha256(
      password: pin.codeUnits,
      salt: salt,
    );
    final record = encodePasswordRecord(
      iterations: 310000,
      salt: salt,
      hash: hash,
    );

    final enabledKey = await UserScopedStore.scopedKey(_enabledKey);
    final hashKey = await UserScopedStore.scopedKey(_hashKey);
    await SecureKvService.instance.writeString(hashKey, record);
    await SecureKvService.instance.writeString(enabledKey, 'true');
    await _resetFailedAttempts();
    unlockSession();
  }

  Future<void> disablePin(String pin) async {
    final ok = await verifyPin(pin);
    if (!ok) {
      throw StateError('invalid_pin');
    }
    await _clearPinData();
    lockSession();
  }

  Future<void> changePin({required String oldPin, required String newPin}) async {
    if (!_isValidPin(newPin)) {
      throw ArgumentError('PIN must be $pinLength digits');
    }
    final hashKey = await UserScopedStore.scopedKey(_hashKey);
    final record = await SecureKvService.instance.readString(hashKey);
    if (record == null || !verifyPasswordAgainstRecord(oldPin, record)) {
      throw StateError('invalid_pin');
    }
    await setPin(newPin);
  }

  Future<void> onLogout() async {
    lockSession();
    _memoryFailedAttempts = 0;
    _memoryLockoutUntil = null;
  }

  bool _isValidPin(String pin) {
    if (pin.length != pinLength) return false;
    return RegExp(r'^\d+$').hasMatch(pin);
  }

  Uint8List _randomSalt() {
    final rnd = Random.secure();
    return Uint8List.fromList(List.generate(16, (_) => rnd.nextInt(256)));
  }

  Future<void> _registerFailedAttempt() async {
    _memoryFailedAttempts++;
    final key = await UserScopedStore.scopedKey(_failedAttemptsKey);
    final raw = await SecureKvService.instance.readString(key);
    final failed = (int.tryParse(raw ?? '') ?? 0) + 1;
    await SecureKvService.instance.writeString(key, '$failed');
    _memoryFailedAttempts = failed;

    if (failed >= maxAttempts) {
      final until = DateTime.now().add(const Duration(seconds: lockoutSeconds));
      _memoryLockoutUntil = until;
      final lockKey = await UserScopedStore.scopedKey(_lockoutUntilKey);
      await SecureKvService.instance.writeString(
        lockKey,
        '${until.millisecondsSinceEpoch}',
      );
      await SecureKvService.instance.writeString(key, '0');
      _memoryFailedAttempts = 0;
    }
  }

  Future<void> _resetFailedAttempts() async {
    _memoryFailedAttempts = 0;
    _memoryLockoutUntil = null;
    final failedKey = await UserScopedStore.scopedKey(_failedAttemptsKey);
    final lockKey = await UserScopedStore.scopedKey(_lockoutUntilKey);
    await SecureKvService.instance.delete(failedKey);
    await SecureKvService.instance.delete(lockKey);
  }

  Future<void> _clearLockout() async {
    _memoryLockoutUntil = null;
    final lockKey = await UserScopedStore.scopedKey(_lockoutUntilKey);
    await SecureKvService.instance.delete(lockKey);
  }

  Future<void> _clearPinData() async {
    final enabledKey = await UserScopedStore.scopedKey(_enabledKey);
    final hashKey = await UserScopedStore.scopedKey(_hashKey);
    await SecureKvService.instance.delete(enabledKey);
    await SecureKvService.instance.delete(hashKey);
    await _resetFailedAttempts();
  }
}
