# Firebase (dfd-diary)

## Уже в проекте

- `android/app/google-services.json`
- `lib/firebase_options.dart`
- Auth (логин → `логин@dfd-diary.app`), Firestore, Analytics, Crashlytics, FCM init
- Правила: `firestore.rules` (скопировать в консоль)

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
