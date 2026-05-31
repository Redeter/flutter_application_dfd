import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase/auth_email_mapper.dart';
import 'dev_data_seed_service.dart';
import 'firestore_repository.dart';
import 'secure_kv_service.dart';

class AuthUsernameTakenException implements Exception {
  AuthUsernameTakenException([this.message = 'Этот логин уже занят']);
  final String message;

  @override
  String toString() => message;
}

/// Аутентификация через Firebase (логин в UI → email `@dfd-diary.app`).
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const rememberSessionKey = 'auth_remember_v2';

  /// Для юнит-тестов: подставить uid без Firebase.
  String? debugSessionUserIdOverride;

  FirebaseAuth get _auth {
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase не инициализирован');
    }
    return FirebaseAuth.instance;
  }

  String _normalizeUsername(String raw) => raw.trim().toLowerCase();

  Future<void> enforceRememberPolicyOnColdStart() async {
    if (debugSessionUserIdOverride != null) return;
    final user = _auth.currentUser;
    if (user == null) return;
    final remember =
        await SecureKvService.instance.readString(rememberSessionKey);
    if (remember != 'true') {
      await _auth.signOut();
    }
  }

  Future<String?> sessionUserId() async {
    if (debugSessionUserIdOverride != null) {
      return debugSessionUserIdOverride;
    }
    return _auth.currentUser?.uid;
  }

  Future<String> requireSessionUserId() async {
    final id = await sessionUserId();
    if (id == null || id.isEmpty) {
      throw StateError('Нет активной сессии пользователя');
    }
    return id;
  }

  void setFixtureSessionUserId(String? userId) {
    debugSessionUserIdOverride = userId;
  }

  Future<bool> hasAnyRegisteredUser() async {
    return _auth.currentUser != null;
  }

  Future<bool> isUsernameTaken(String username) async {
    final email = AuthEmailMapper.emailForUsername(username);
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String?> username() async {
    final uid = await sessionUserId();
    if (uid == null) return null;
    final data = await FirestoreRepository.instance.loadProfileFields();
    return data?[FirestoreRepository.fieldLoginUsername] as String?;
  }

  Future<void> register({
    required String username,
    required String password,
  }) async {
    final display = username.trim();
    final norm = _normalizeUsername(username);
    if (norm.isEmpty) return;

    final email = AuthEmailMapper.emailForUsername(norm);
    if (await isUsernameTaken(norm)) {
      throw AuthUsernameTakenException();
    }

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user?.uid;
    if (uid == null) {
      throw StateError('Не удалось создать пользователя Firebase');
    }

    await FirestoreRepository.instance.saveProfileFields(
      name: display,
      conditions: const [],
      priorityFocus: 'mood',
      loginUsername: display,
    );
    await _setRememberSession(false);
  }

  Future<bool> login({
    required String username,
    required String password,
    bool rememberSession = false,
  }) async {
    final email = AuthEmailMapper.emailForUsername(username);
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _setRememberSession(rememberSession);
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return false;
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    if (debugSessionUserIdOverride != null) {
      debugSessionUserIdOverride = null;
      return;
    }
    await _auth.signOut();
    await _setRememberSession(false);
  }

  Future<bool> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final uid = user.uid;

    try {
      final email = user.email;
      if (email == null || email.isEmpty) return false;
      final cred = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
    } on FirebaseAuthException {
      return false;
    }

    await DevDataSeedService.instance.wipeScopedDataForUser(uid);
    await FirestoreRepository.instance.deleteUserDocument();
    await user.delete();
    await logout();
    return true;
  }

  Future<bool> shouldAutoLogin() async {
    if (debugSessionUserIdOverride != null) return true;
    await enforceRememberPolicyOnColdStart();
    final user = _auth.currentUser;
    if (user == null) return false;
    final remember =
        await SecureKvService.instance.readString(rememberSessionKey);
    return remember == 'true';
  }

  Future<void> _setRememberSession(bool remember) async {
    await SecureKvService.instance.writeString(
      rememberSessionKey,
      remember ? 'true' : 'false',
    );
  }
}
