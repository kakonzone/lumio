import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Core + Crashlytics on cold start.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _initialized = false;
  static bool _crashlyticsWired = false;

  /// `true` after [initialize] succeeds.
  static bool get isInitialized => _initialized;

  /// `true` when Crashlytics handlers are registered (Firebase init OK).
  static bool get crashlyticsWired => _crashlyticsWired;

  /// Call once from `main()` before ads / Remote Config consumers.
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _initialized = true;
      await _wireCrashlytics();
      // ignore: avoid_print
      print('[Lumio] Firebase init OK');
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
  static Future<void> wireCrashlyticsForTest({required bool firebaseAvailable}) async {
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
