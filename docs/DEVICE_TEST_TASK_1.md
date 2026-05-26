# Device test — Task 1 (Firebase initialization)

**READY_FOR_DEVICE_TEST**

---

## Build / run

### A — Without `google-services.json` (fallback)

```bash
# Ensure android/app/google-services.json is absent or renamed
flutter run --dart-define=ADS_TEST_MODE=true
```

### B — With Firebase configured

```bash
# Place google-services.json under android/app/ first
flutter run
```

Release check:

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## Steps (physical Android)

### Scenario A — No JSON

1. Confirm `android/app/google-services.json` does **not** exist.
2. Cold start the app.
3. App reaches splash / home without crash.

### Scenario B — With JSON

1. Add valid `google-services.json` for `com.kakonzone.lumio`.
2. `flutter clean && flutter run` (or install release APK).
3. Cold start the app.

---

## Logcat

```bash
adb logcat -c
# launch app, wait for splash
adb logcat -d | grep '\[Lumio\] Firebase'
```

| Grep pattern | Scenario | Pass? |
|--------------|----------|-------|
| `[Lumio] Firebase init OK` | B — JSON present | ☐ |
| `[Lumio] Firebase init skipped` | A — JSON absent | ☐ |
| No `FirebaseException` crash | Both | ☐ |

Gradle (optional, on build):

```bash
cd android && ./gradlew :app:assembleDebug 2>&1 | grep google-services
```

Expect warning when JSON missing; no warning when present.

---

## Pass / fail criteria

| # | Criterion | Pass |
|---|-----------|------|
| 1 | With JSON: exactly one `Firebase init OK` per cold start | ☐ |
| 2 | Without JSON: `init skipped` + app usable (home loads) | ☐ |
| 3 | Remote Config / Analytics failure does not block playback | ☐ |
| 4 | No uncaught exception in `main()` Firebase path | ☐ |

**Task 1 result:** ☐ PASS ☐ FAIL — Tester: __________ Date: __________

---

## Related code

| File | Role |
|------|------|
| `lib/services/firebase_bootstrap.dart` | Init + log lines |
| `lib/main.dart` | Calls `FirebaseBootstrap.initialize()` |
| `android/app/build.gradle.kts` | Conditional `google-services` plugin |
| `docs/FIREBASE_SETUP.md` | Operator setup |
