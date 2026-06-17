import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../security/security_config.dart';

/// Firebase Core + Crashlytics on cold start.
class FirebaseBootstrap {
  static const bool firebaseEnabled = bool.fromEnvironment(
    'FIREBASE_ENABLED',
    defaultValue: true,
  );
  FirebaseBootstrap._();

  static bool _initialized = false;
  static bool _crashlyticsWired = false;

  /// `true` after [initialize] succeeds.
  static bool get isInitialized => _initialized;

  /// `true` when Crashlytics handlers are registered (Firebase init OK).
  static bool get crashlyticsWired => _crashlyticsWired;

  /// Call once from `main()` before ads / Remote Config consumers.
  static Future<void> initialize() async {
    if (!firebaseEnabled) {
      _initialized = false;
      _crashlyticsWired = false;
      if (kDebugMode) {
        debugPrint('[Lumio] Firebase init skipped — FIREBASE_ENABLED=false');
      }
      return;
    }
    try {
      await Firebase.initializeApp();
      _initialized = true;
      await _wireCrashlytics();
      // ignore: avoid_print
      print('[Lumio] Firebase init OK');

      // Security integrity check
      if (!kDebugMode && SecurityConfig.hmacSecret.isEmpty) {
        // ignore: avoid_print
        print('[Lumio] SECURITY WARNING: hmacSecret is empty in release mode');
        if (kDebugMode) {
          debugPrint(
              '[Lumio] Set LUMIO_HMAC_SECRET via --dart-define for production');
        }
      }
    } catch (e) {
      _initialized = false;
      _crashlyticsWired = false;
      // ignore: avoid_print
      print(
        '[Lumio] Firebase init skipped — add android/app/google-services.json '
        '(local fallback active)',
      );
      if (kDebugMode) {
        debugPrint('[Lumio] Firebase init error: $e');
      }
    }
  }

  @visibleForTesting
  static Future<void> wireCrashlyticsForTest(
      {required bool firebaseAvailable}) async {
    _initialized = firebaseAvailable;
    _crashlyticsWired = false;
    if (!firebaseAvailable) return;
    await _wireCrashlytics();
  }

  static Future<void> _wireCrashlytics() async {
    if (!_initialized) return;
    try {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      _crashlyticsWired = true;
      if (kDebugMode) {
        debugPrint('[Lumio] Crashlytics wired');
      }
    } catch (e) {
      _crashlyticsWired = false;
      if (kDebugMode) {
        debugPrint('[Lumio] Crashlytics wiring skipped: $e');
      }
    }
  }
}
