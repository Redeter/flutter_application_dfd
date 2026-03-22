/// API-ключ для Gemini. Получить: https://aistudio.google.com/apikey
/// Варианты: dart-define=GEMINI_API_KEY=xxx или ввод в приложении (сохраняется локально)
const String geminiApiKey = String.fromEnvironment(
  'GEMINI_API_KEY',
  defaultValue: '',
);
