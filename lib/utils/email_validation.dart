/// Простая проверка email для форм входа и регистрации.
final RegExp kEmailPattern = RegExp(r'^[\w.+-]+@[\w.-]+\.\w{2,}$');

String normalizeEmail(String raw) => raw.trim().toLowerCase();

String? validateEmailField(String? value) {
  final email = (value ?? '').trim();
  if (email.isEmpty) return 'Введите почту';
  if (!kEmailPattern.hasMatch(email)) {
    return 'Введите корректный адрес почты';
  }
  return null;
}
