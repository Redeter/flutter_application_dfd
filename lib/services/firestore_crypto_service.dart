import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../utils/pbkdf2_sha256.dart';
import 'auth_service.dart';
import 'firestore_repository.dart';
import 'secure_kv_service.dart';
import 'user_storage_keys.dart';

/// Клиентское шифрование чувствительных полей Firestore (AES-256-GCM).
///
/// DEK хранится на устройстве; в облаке — только обёрнутый ключ (нужен пароль).
class FirestoreCryptoService {
  FirestoreCryptoService._();
  static final FirestoreCryptoService instance = FirestoreCryptoService._();

  static const encVersion = 2;
  static const encAlg = 'aes256gcm';
  static const fieldCryptoSalt = 'cryptoSalt';
  static const fieldCryptoWrappedDek = 'cryptoWrappedDek';

  static const _dekStorageBase = 'firestore_dek_v1';

  final AesGcm _aes = AesGcm.with256bits();
  Uint8List? _dek;

  bool get isUnlocked => _dek != null;

  /// После входа/регистрации: восстановить или создать DEK по паролю.
  Future<void> unlockWithPassword(String password) async {
    final uid = await AuthService.instance.requireSessionUserId();
    final cached = await _loadDekFromStorage(uid);
    if (cached != null) {
      _dek = cached;
      await uploadWrappedDekIfNeeded(password);
      return;
    }

    final cloud = await FirestoreRepository.instance.readCryptoMeta();
    final salt = cloud.salt;
    final wrapped = cloud.wrappedDek;

    if (salt != null && wrapped != null) {
      final kek = _deriveKek(password: password, uid: uid, salt: salt);
      final dek = await _unwrapDek(wrapped, kek);
      if (dek == null) {
        throw StateError('Не удалось расшифровать ключ данных. Проверьте пароль.');
      }
      _dek = dek;
      await _saveDekToStorage(uid, dek);
      return;
    }

    final dek = _randomBytes(32);
    _dek = dek;
    await _saveDekToStorage(uid, dek);
    await _uploadWrappedDek(uid: uid, password: password, dek: dek);
  }

  /// Холодный старт с «Запомнить меня»: DEK из Secure Storage или новый для legacy.
  ///
  /// Возвращает `false`, если в облаке уже есть wrapped DEK, а локального ключа нет
  /// (нужен повторный вход с паролем).
  Future<bool> ensureForActiveSession() async {
    if (_dek != null) return true;

    final uid = await AuthService.instance.sessionUserId();
    if (uid == null) return false;

    final cached = await _loadDekFromStorage(uid);
    if (cached != null) {
      _dek = cached;
      return true;
    }

    final cloud = await FirestoreRepository.instance.readCryptoMeta();
    if (cloud.wrappedDek != null) return false;

    final dek = _randomBytes(32);
    _dek = dek;
    await _saveDekToStorage(uid, dek);
    return true;
  }

  Future<void> uploadWrappedDekIfNeeded(String password) async {
    if (_dek == null) return;
    final cloud = await FirestoreRepository.instance.readCryptoMeta();
    if (cloud.wrappedDek != null) return;
    final uid = await AuthService.instance.requireSessionUserId();
    await _uploadWrappedDek(uid: uid, password: password, dek: _dek!);
  }

  void lock() {
    _dek = null;
  }

  @visibleForTesting
  void debugSetDek(Uint8List dek) {
    _dek = dek;
  }

  Future<Map<String, dynamic>> encryptPayload(String plaintext) async {
    final dek = _requireDek();
    final nonce = _randomBytes(12);
    final box = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(dek),
      nonce: nonce,
    );
    return {
      'v': encVersion,
      'alg': encAlg,
      'iv': base64Encode(box.nonce),
      'ct': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
  }

  Future<String?> decryptPayload(dynamic raw) async {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    if ((map['v'] as num?)?.toInt() != encVersion || map['alg'] != encAlg) {
      return null;
    }
    final iv = map['iv'];
    final ct = map['ct'];
    final mac = map['mac'];
    if (iv is! String || ct is! String || mac is! String) return null;

    final dek = _dek;
    if (dek == null) return null;

    try {
      final box = SecretBox(
        base64Decode(ct),
        nonce: base64Decode(iv),
        mac: Mac(base64Decode(mac)),
      );
      final clear = await _aes.decrypt(
        box,
        secretKey: SecretKey(dek),
      );
      return utf8.decode(clear);
    } catch (_) {
      return null;
    }
  }

  bool isEncryptedEnvelope(dynamic raw) {
    if (raw is! Map) return false;
    return (raw['v'] as num?)?.toInt() == encVersion && raw['alg'] == encAlg;
  }

  Uint8List _requireDek() {
    final dek = _dek;
    if (dek == null) {
      throw StateError('Ключ шифрования Firestore не инициализирован');
    }
    return dek;
  }

  Uint8List _deriveKek({
    required String password,
    required String uid,
    required Uint8List salt,
  }) {
    return pbkdf2Sha256(
      password: utf8.encode('$password|$uid|firestore_dek_v1'),
      salt: salt,
      iterations: 210000,
      dkLen: 32,
    );
  }

  Future<void> _uploadWrappedDek({
    required String uid,
    required String password,
    required Uint8List dek,
  }) async {
    final salt = _randomBytes(16);
    final kek = _deriveKek(password: password, uid: uid, salt: salt);
    final wrapped = await _wrapDek(dek, kek);
    await FirestoreRepository.instance.saveCryptoMeta(
      saltBase64: base64Encode(salt),
      wrappedDek: wrapped,
    );
  }

  Future<Map<String, dynamic>> _wrapDek(Uint8List dek, Uint8List kek) async {
    final nonce = _randomBytes(12);
    final box = await _aes.encrypt(
      dek,
      secretKey: SecretKey(kek),
      nonce: nonce,
    );
    return {
      'v': encVersion,
      'alg': encAlg,
      'iv': base64Encode(box.nonce),
      'ct': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
  }

  Future<Uint8List?> _unwrapDek(Map<String, dynamic> wrapped, Uint8List kek) async {
    try {
      final box = SecretBox(
        base64Decode(wrapped['ct'] as String),
        nonce: base64Decode(wrapped['iv'] as String),
        mac: Mac(base64Decode(wrapped['mac'] as String)),
      );
      final clear = await _aes.decrypt(box, secretKey: SecretKey(kek));
      if (clear.length != 32) return null;
      return Uint8List.fromList(clear);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _loadDekFromStorage(String uid) async {
    final key = UserStorageKeys.forUser(uid, _dekStorageBase);
    final raw = await SecureKvService.instance.readString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final bytes = base64Decode(raw);
      if (bytes.length != 32) return null;
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveDekToStorage(String uid, Uint8List dek) async {
    final key = UserStorageKeys.forUser(uid, _dekStorageBase);
    await SecureKvService.instance.writeString(key, base64Encode(dek));
  }

  Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rnd.nextInt(256)));
  }
}

class FirestoreCryptoMeta {
  const FirestoreCryptoMeta({this.salt, this.wrappedDek});

  final Uint8List? salt;
  final Map<String, dynamic>? wrappedDek;
}
