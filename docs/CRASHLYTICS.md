# Firebase Crashlytics (R05)

## Dart wiring

`lib/services/firebase_bootstrap.dart` registers handlers only after `Firebase.initializeApp()` succeeds:

- `FlutterError.onError` → `recordFlutterFatalError`
- `PlatformDispatcher.instance.onError` → `recordError(..., fatal: true)`

If `google-services.json` is missing, Firebase init fails and Crashlytics stays a no-op.

## Android release builds

1. Add `google-services.json` locally (never commit).
2. Release build with obfuscation (`isMinifyEnabled true` in `android/app/build.gradle.kts`).
3. Upload mapping via Firebase Crashlytics Gradle plugin (`com.google.firebase.crashlytics`).

```bash
flutter build apk --release --dart-define-from-file=secrets.json
```

Mapping files: `build/app/outputs/mapping/release/mapping.txt`

## iOS (future)

- Enable Crashlytics in Firebase Console for iOS app.
- Upload dSYM: Xcode Organizer → Distribute → or `upload-symbols` script from Firebase.

## ProGuard

Keep rules in `android/app/proguard-rules.pro` for Firebase / Flutter plugins when minify is on.

## Verify

```bash
flutter test test/services/crashlytics_bootstrap_test.dart
```

Force a test crash in debug only: `FirebaseCrashlytics.instance.crash()` (remove before ship).
