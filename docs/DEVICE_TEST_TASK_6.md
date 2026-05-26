# Device test — Task 6 (debug `ADS_TEST_MODE`)

**READY_FOR_DEVICE_TEST**

---

## Rule

| Build | `ADS_TEST_MODE` | Ads (LevelPlay / Adsterra) |
|-------|-----------------|----------------------------|
| Debug `flutter run` | not set | **Blocked** |
| Debug `flutter run` | `true` | **Enabled** (consent + caps still apply) |
| Release APK | `true` or unset | **Enabled** — define is **ignored** |

Gating uses `AdConfig.blockAdsInThisBuild` / `adsTestModeEffective` — not scattered `kDebugMode` checks.

---

## Scenarios

### A — Debug, ads off (default)

```bash
flutter run
```

**Expect in logcat:**

- `[AdSafety] ads blocked in non-release build — pass --dart-define=ADS_TEST_MODE=true to test ads`
- `[LevelPlay] init skipped (debug)`
- No HOME banner widget load

### B — Debug, ads on

```bash
flutter run --dart-define=ADS_TEST_MODE=true
```

**Expect:**

- `[AdSafety] ADS_TEST_MODE=true — ads enabled in debug build`
- `[LevelPlay] setDynamicUserId(...)` then `[LevelPlay] init success` (after consent)
- Banner may load on HOME

### C — Release ignores define

```bash
flutter build apk --release --dart-define=ADS_TEST_MODE=true
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

**Expect:**

- `[AdSafety] ADS_TEST_MODE define ignored in release build` (if define was passed)
- LevelPlay init proceeds when consent allows (same as release without define)
- No “init skipped (debug)” line

---

## Log grep

```bash
adb logcat -d | grep -E '\[AdSafety\] ADS_TEST_MODE|\[AdSafety\] ads blocked|\[LevelPlay\] init skipped'
```

---

## Pass / fail criteria

| # | Criterion | Pass |
|---|-----------|------|
| 1 | Scenario A: init skipped, no banner | ☐ |
| 2 | Scenario B: ADS_TEST_MODE log + init success | ☐ |
| 3 | Scenario C: release ignores define; ads not blocked by test flag | ☐ |
| 4 | `flutter test test/services/ad_safety_migration_test.dart` (Task 6 group) | ☐ |

**Automated:**

```bash
flutter test test/services/ad_safety_migration_test.dart
```

**Task 6 result:** ☐ PASS ☐ FAIL — Tester: __________ Date: __________
