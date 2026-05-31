import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Инициализация Firebase-сервисов после [Firebase.initializeApp].
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<void> init() async {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );

    await _initCrashlytics();
    await FirebaseAnalytics.instance.logAppOpen();
    await _initMessaging();
  }

  static Future<void> _initCrashlytics() async {
    if (kDebugMode) return;
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  static Future<void> _initMessaging() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {}
  }
}
