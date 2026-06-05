import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase/firestore_paths.dart';
import 'auth_service.dart';
import 'firestore_crypto_service.dart';

/// Чтение/запись пользовательских данных в Firestore (офлайн-кэш включён).
class FirestoreRepository {
  FirestoreRepository._();
  static final FirestoreRepository instance = FirestoreRepository._();

  static const fieldNotes = 'notesItems';
  static const fieldState = 'stateItems';
  static const fieldCalendar = 'calendarItems';
  static const fieldProfileName = 'profileName';
  static const fieldProfileConditions = 'profileConditions';
  static const fieldProfilePriority = 'profilePriority';
  static const fieldProfileSpherePriorities = 'profileSpherePriorities';
  static const fieldProfileEmail = 'profileEmail';
  /// Устаревшее поле (логин → synthetic email). Только для чтения старых документов.
  static const fieldLoginUsername = 'loginUsername';

  final _crypto = FirestoreCryptoService.instance;

  bool get _useCloud {
    if (AuthService.instance.debugSessionUserIdOverride != null) return false;
    if (Firebase.apps.isEmpty) return false;
    return FirebaseAuth.instance.currentUser != null;
  }

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.doc('users/$uid');
  }

  Future<Map<String, dynamic>?> _userData() async {
    final ref = _userRef();
    if (ref == null) return null;
    final snap = await ref.get(const GetOptions(source: Source.serverAndCache));
    if (!snap.exists) return null;
    return snap.data();
  }

  Future<void> _mergeUser(Map<String, dynamic> patch) async {
    final ref = _userRef();
    if (ref == null) return;
    await ref.set(patch, SetOptions(merge: true));
  }

  Future<FirestoreCryptoMeta> readCryptoMeta() async {
    if (!_useCloud) return const FirestoreCryptoMeta();
    final data = await _userData();
    if (data == null) return const FirestoreCryptoMeta();
    final saltRaw = data[FirestoreCryptoService.fieldCryptoSalt];
    final wrappedRaw = data[FirestoreCryptoService.fieldCryptoWrappedDek];
    return FirestoreCryptoMeta(
      salt: saltRaw is String ? _tryBase64Bytes(saltRaw) : null,
      wrappedDek: wrappedRaw is Map
          ? Map<String, dynamic>.from(wrappedRaw)
          : null,
    );
  }

  bool _documentHasEncryptedFields(Map<String, dynamic> data) {
    const fields = [
      fieldNotes,
      fieldState,
      fieldCalendar,
      fieldProfileName,
      fieldProfileConditions,
      fieldProfilePriority,
      fieldProfileSpherePriorities,
      fieldProfileEmail,
    ];
    return fields.any((f) => _crypto.isEncryptedEnvelope(data[f]));
  }

  /// Однократно шифрует legacy plaintext-поля в документе пользователя.
  Future<void> migratePlaintextToEncrypted() async {
    if (!_useCloud || !_crypto.isUnlocked) return;
    final data = await _userData();
    if (data == null) return;

    final patch = <String, dynamic>{};

    for (final field in [fieldNotes, fieldState, fieldCalendar]) {
      final raw = data[field];
      if (raw is List) {
        patch[field] = await _crypto.encryptPayload(jsonEncode(raw));
      }
    }

    Future<void> encryptStringField(String key) async {
      final raw = data[key];
      if (raw is String) {
        patch[key] = await _crypto.encryptPayload(raw);
      } else if (raw is List) {
        patch[key] = await _crypto.encryptPayload(jsonEncode(raw));
      } else if (raw is Map && !_crypto.isEncryptedEnvelope(raw)) {
        patch[key] = await _crypto.encryptPayload(jsonEncode(raw));
      }
    }

    await encryptStringField(fieldProfileName);
    await encryptStringField(fieldProfileConditions);
    await encryptStringField(fieldProfilePriority);
    await encryptStringField(fieldProfileSpherePriorities);
    await encryptStringField(fieldProfileEmail);

    if (patch.isNotEmpty) {
      await _mergeUser(patch);
    }
  }

  Future<void> saveCryptoMeta({
    required String saltBase64,
    required Map<String, dynamic> wrappedDek,
  }) async {
    if (!_useCloud) return;
    await _mergeUser({
      FirestoreCryptoService.fieldCryptoSalt: saltBase64,
      FirestoreCryptoService.fieldCryptoWrappedDek: wrappedDek,
    });
  }

  List<Map<String, dynamic>>? _decodeJsonList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (_crypto.isEncryptedEnvelope(raw)) {
      return null;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>?> loadJsonList(String field) async {
    if (!_useCloud) return null;
    final data = await _userData();
    if (data == null) return null;
    final raw = data[field];
    if (raw == null) return [];

    final legacy = _decodeJsonList(raw);
    if (legacy != null) return legacy;

    if (_crypto.isEncryptedEnvelope(raw)) {
      final clear = await _crypto.decryptPayload(raw);
      if (clear == null || clear.isEmpty) return null;
      try {
        final decoded = jsonDecode(clear);
        if (decoded is! List) return [];
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } catch (_) {
        return null;
      }
    }

    return [];
  }

  Future<void> saveJsonList(String field, List<Map<String, dynamic>> items) async {
    if (!_useCloud) return;
    if (!_crypto.isUnlocked) {
      await _mergeUser({field: items});
      return;
    }
    final envelope = await _crypto.encryptPayload(jsonEncode(items));
    await _mergeUser({field: envelope});
  }

  Future<Map<String, dynamic>?> loadProfileFields() async {
    if (!_useCloud) return null;
    final data = await _userData();
    if (data == null) return null;
    if (_documentHasEncryptedFields(data) && !_crypto.isUnlocked) {
      return null;
    }

    Future<String> readStringField(String key) async {
      final raw = data[key];
      if (_crypto.isEncryptedEnvelope(raw)) {
        return (await _crypto.decryptPayload(raw)) ?? '';
      }
      if (raw is String) return raw;
      return '';
    }

    Future<List<String>> readStringListField(String key) async {
      final raw = data[key];
      if (_crypto.isEncryptedEnvelope(raw)) {
        final clear = await _crypto.decryptPayload(raw);
        if (clear == null || clear.isEmpty) return [];
        try {
          final decoded = jsonDecode(clear);
          if (decoded is List) {
            return decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
        return [];
      }
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    }

    Future<Map<String, int>?> readIntMapField(String key) async {
      final raw = data[key];
      if (_crypto.isEncryptedEnvelope(raw)) {
        final clear = await _crypto.decryptPayload(raw);
        if (clear == null || clear.isEmpty) return null;
        try {
          final decoded = jsonDecode(clear);
          if (decoded is Map) {
            return _parseIntMap(decoded);
          }
        } catch (_) {}
        return null;
      }
      if (raw is Map && !_crypto.isEncryptedEnvelope(raw)) {
        return _parseIntMap(raw);
      }
      return null;
    }

    return {
      fieldProfileName: await readStringField(fieldProfileName),
      fieldProfileConditions: await readStringListField(fieldProfileConditions),
      fieldProfilePriority: await readStringField(fieldProfilePriority),
      fieldProfileSpherePriorities: await readIntMapField(fieldProfileSpherePriorities),
      fieldProfileEmail: await readStringField(fieldProfileEmail),
      if (data[fieldLoginUsername] != null)
        fieldLoginUsername: data[fieldLoginUsername],
    };
  }

  Future<void> saveProfileFields({
    required String name,
    required List<String> conditions,
    required String priorityFocus,
    Map<String, int>? spherePriorities,
    String? profileEmail,
  }) async {
    if (!_useCloud) return;

    if (!_crypto.isUnlocked) {
      await _mergeUser({
        fieldProfileName: name,
        fieldProfileConditions: conditions,
        fieldProfilePriority: priorityFocus,
        if (spherePriorities != null)
          fieldProfileSpherePriorities: spherePriorities,
        if (profileEmail != null && profileEmail.isNotEmpty)
          fieldProfileEmail: profileEmail,
      });
      return;
    }

    final patch = <String, dynamic>{
      fieldProfileName: await _crypto.encryptPayload(name),
      fieldProfileConditions:
          await _crypto.encryptPayload(jsonEncode(conditions)),
      fieldProfilePriority: await _crypto.encryptPayload(priorityFocus),
    };
    if (spherePriorities != null) {
      patch[fieldProfileSpherePriorities] =
          await _crypto.encryptPayload(jsonEncode(spherePriorities));
    }
    if (profileEmail != null && profileEmail.isNotEmpty) {
      patch[fieldProfileEmail] = await _crypto.encryptPayload(profileEmail);
    }
    await _mergeUser(patch);
  }

  /// Пустые списки в облаке (заметки, состояние, календарь). Профиль и crypto-meta не трогаем.
  Future<void> wipeSyncedContent() async {
    if (!_useCloud) return;
    await saveJsonList(fieldNotes, const []);
    await saveJsonList(fieldState, const []);
    await saveJsonList(fieldCalendar, const []);
  }

  Future<void> deleteUserDocument() async {
    final ref = _userRef();
    if (ref == null) return;
    await ref.delete();
  }

  Future<List<Map<String, dynamic>>> loadArticles() async {
    if (Firebase.apps.isEmpty) return [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection(FirestorePaths.articles)
          .orderBy('order')
          .get(const GetOptions(source: Source.serverAndCache));
      return snap.docs
          .map((d) => {...d.data(), 'id': d.id})
          .toList();
    } catch (_) {
      return [];
    }
  }

  Uint8List? _tryBase64Bytes(String raw) {
    try {
      return Uint8List.fromList(base64Decode(raw));
    } catch (_) {
      return null;
    }
  }

  Map<String, int> _parseIntMap(Map<dynamic, dynamic> raw) {
    return raw.map(
      (k, v) => MapEntry('$k', _parseIntValue(v)),
    );
  }

  int _parseIntValue(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
