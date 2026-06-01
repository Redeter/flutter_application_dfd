import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase/firestore_paths.dart';
import 'auth_service.dart';

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

  /// `null` — документа пользователя нет (читать локальный кэш).
  Future<List<Map<String, dynamic>>?> loadJsonList(String field) async {
    if (!_useCloud) return null;
    final data = await _userData();
    if (data == null) return null;
    final raw = data[field];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> saveJsonList(String field, List<Map<String, dynamic>> items) async {
    if (!_useCloud) return;
    await _mergeUser({field: items});
  }

  Future<Map<String, dynamic>?> loadProfileFields() async {
    if (!_useCloud) return null;
    return _userData();
  }

  Future<void> saveProfileFields({
    required String name,
    required List<String> conditions,
    required String priorityFocus,
    Map<String, int>? spherePriorities,
    String? profileEmail,
  }) async {
    if (!_useCloud) return;
    await _mergeUser({
      fieldProfileName: name,
      fieldProfileConditions: conditions,
      fieldProfilePriority: priorityFocus,
      if (spherePriorities != null)
        fieldProfileSpherePriorities: spherePriorities,
      if (profileEmail != null && profileEmail.isNotEmpty)
        fieldProfileEmail: profileEmail,
    });
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
}
