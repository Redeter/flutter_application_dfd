/// Логин в UI → технический email для Firebase Authentication.
class AuthEmailMapper {
  AuthEmailMapper._();

  static const domain = 'dfd-diary.app';

  static String emailForUsername(String username) {
    final norm = username.trim().toLowerCase();
    return '$norm@$domain';
  }
}
