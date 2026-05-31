// Generated from android/app/google-services.json (project dfd-diary).
// Re-run `flutterfire configure` after installing Firebase CLI to refresh.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web Firebase is not configured. Run flutterfire configure with web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'iOS Firebase is not configured. Add iOS app in console and run flutterfire configure.',
        );
      default:
        throw UnsupportedError(
          'Firebase is only configured for Android in this project.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDZuV3EoI9Q5wXl4j7CWY2-R0I0LZNHiDI',
    appId: '1:44511263447:android:28ca77777151fd83a50e92',
    messagingSenderId: '44511263447',
    projectId: 'dfd-diary',
    storageBucket: 'dfd-diary.firebasestorage.app',
  );
}
