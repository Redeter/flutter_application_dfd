/// Пути Cloud Firestore для проекта dfd-diary.
class FirestorePaths {
  FirestorePaths._();

  static const articles = 'articles';

  static String userDoc(String uid) => 'users/$uid';
}
