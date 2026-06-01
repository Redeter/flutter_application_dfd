# Firebase (dfd-diary)

## Уже в проекте

- `android/app/google-services.json`
- `lib/firebase_options.dart`
- Auth (email/пароль), Firestore, Analytics, Crashlytics, FCM init
- Правила: `firestore.rules` (скопировать в консоль)
- Записи пользователя в Firestore — **в зашифрованном виде** (клиентское AES-256-GCM)

## Что куда попадает

| Данные | Локально | Firebase |
|--------|----------|----------|
| Заметки, состояние, календарь, профиль | Secure Storage (копия) | Firestore, зашифровано |
| PIN | Secure Storage (хеш) | нет |
| Модель советов, настройки UI | SharedPreferences | нет |
| Вход | — | Firebase Auth |
| Статистика использования | — | Firebase Analytics (обезличенно) |
| Сбои приложения | — | Firebase Crashlytics |

Советы в «Статистике» считаются **на устройстве**; текст заметок не отправляется во внешние ИИ.

## Один раз в консоли

1. ~~**Firestore → Rules** — вставить `firestore.rules` → **Publish**~~ — **сделано**
2. ~~Коллекция `articles`~~ — пока не используем

## Запуск

```bash
flutter pub get
flutter run
```

Регистрация и вход требуют интернет. Данные кэшируются офлайн (Firestore persistence).

## Старые локальные аккаунты

После перехода на Firebase нужна **новая регистрация**. Старые данные на устройстве привязаны к другому `userId`.
