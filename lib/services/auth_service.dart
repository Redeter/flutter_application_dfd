import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../utils/email_validation.dart';
import 'dev_data_seed_service.dart';
import 'firestore_crypto_service.dart';
import 'firestore_repository.dart';
import 'secure_kv_service.dart';
import 'pin_lock_service.dart';
import 'session_data_cache.dart';

class AuthEmailTakenException implements Exception {
  AuthEmailTakenException([this.message = 'Этот адрес почты уже зарегистрирован']);
  final String message;

  @override
  String toString() => message;
}

/// Аутентификация через Firebase Email/Password.
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

  Future<void> enforceRememberPolicyOnColdStart() async {
    if (debugSessionUserIdOverride != null) return;
    await _waitForAuthPersistenceReady();
    final user = _auth.currentUser;
    if (user == null) return;
    final remember = await _readRememberFlag();
    if (remember == null) {
      // Сессия Firebase есть, флаг в Secure Storage потерян (часто на release APK).
      await _setRememberSession(true);
      return;
    }
    if (remember != 'true') {
      DevDataSeedService.instance.cancelInFlight();
      SessionDataCache.clear();
      await _auth.signOut();
    }
  }

  /// Firebase восстанавливает persisted-сессию асинхронно — без ожидания
  /// [currentUser] на cold start часто null и пользователь видит экран входа.
  Future<void> _waitForAuthPersistenceReady() async {
    try {
      await _auth.authStateChanges().first.timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  Future<String?> _readRememberFlag() =>
      SecureKvService.instance.readWithMigration(rememberSessionKey);

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

  Future<bool> isEmailTaken(String email) async {
    final norm = normalizeEmail(email);
    if (norm.isEmpty) return false;
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(norm);
      return methods.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Почта текущего пользователя Firebase.
  Future<String?> userEmail() async {
    if (debugSessionUserIdOverride != null) return null;
    return _auth.currentUser?.email;
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    final norm = normalizeEmail(email);
    if (norm.isEmpty) return;

    if (await isEmailTaken(norm)) {
      throw AuthEmailTakenException();
    }

    SessionDataCache.clear();
    final cred = await _auth.createUserWithEmailAndPassword(
      email: norm,
      password: password,
    );
    if (cred.user?.uid == null) {
      throw StateError('Не удалось создать пользователя Firebase');
    }
    SessionDataCache.clear();
    // После регистрации пользователь уже в сессии — сохраняем её, как при «Запомнить меня».
    await _setRememberSession(true);
    await _bootstrapFirestoreCrypto(password);
  }

  Future<bool> login({
    required String email,
    required String password,
    bool rememberSession = false,
  }) async {
    final norm = normalizeEmail(email);
    try {
      SessionDataCache.clear();
      await _auth.signInWithEmailAndPassword(email: norm, password: password);
      SessionDataCache.clear();
      await _setRememberSession(rememberSession);
      await _bootstrapFirestoreCrypto(password);
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'invalid-email') {
        return false;
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    DevDataSeedService.instance.cancelInFlight();
    SessionDataCache.clear();
    if (debugSessionUserIdOverride != null) {
      debugSessionUserIdOverride = null;
      return;
    }
    await _auth.signOut();
    await _setRememberSession(false);
    FirestoreCryptoService.instance.lock();
    await PinLockService.instance.onLogout();
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
    var remember = await _readRememberFlag();
    if (remember == null) {
      await _setRememberSession(true);
      remember = 'true';
    }
    if (remember != 'true') return false;
    final cryptoReady =
        await FirestoreCryptoService.instance.ensureForActiveSession();
    if (!cryptoReady) {
      // Сессия Firebase сохранена — нужен повторный ввод пароля, не полный выход.
      return false;
    }
    return true;
  }

  Future<void> _bootstrapFirestoreCrypto(String password) async {
    await FirestoreCryptoService.instance.unlockWithPassword(password);
    await FirestoreRepository.instance.migratePlaintextToEncrypted();
  }

  Future<void> _setRememberSession(bool remember) async {
    await SecureKvService.instance.writeString(
      rememberSessionKey,
      remember ? 'true' : 'false',
    );
  }
}
