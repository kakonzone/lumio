# Release notes — Phase 7a (Ad config bring-up)

**App:** Lumio Sports TV (`com.kakonzone.lumio`)  
**SDK:** Flutter 3.x, compileSdk 34, `unity_levelplay_mediation` 9.2.0  
**Sprint goal:** Pass monetization keys at build time; prove stack on device.

## Task outcomes

| Task | Status | Deliverable |
|------|--------|-------------|
| 1 Secrets bootstrap | **Done** | `secrets.json.template`, `.gitignore` (`secrets.json`, `secrets.*.json`), `docs/BUILD.md` |
| 2 AdConfig wiring | **Done** | `AdConfig.dumpRedacted()`, `main.dart` first-launch dump; getter verified (see P7-004) |
| 3 Device logs (user) | **Pending** | User runs `flutter run --dart-define-from-file=secrets.json` and pastes logcat |
| 4 Release APK | **Blocked (network)** | Gradle could not reach `services.gradle.org` in CI/agent; run locally |
| 5 Physical smoke | **Pending** | `docs/DEVICE_TEST_RESULTS.md` matrix |
| 6 Firebase | **Done (local file present)** | `docs/FIREBASE_SETUP.md`; `google-services.json` gitignored |
| 7 This document | **Done** | — |

## Build command (keys redacted)

```bash
cp secrets.json.template secrets.json
# fill secrets.json locally — never commit

flutter build apk --release --target-platform=android-arm64 \
  --dart-define-from-file=secrets.json
```

## APK artifact (fill after local Task 4 build)

Agent build failed: `UnknownHostException: services.gradle.org` (offline sandbox).

After a successful local build, record:

```bash
APK=build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
ls -lh "$APK"
sha256sum "$APK"
aapt dump badging "$APK" | egrep 'package:|versionCode|versionName|uses-permission'
```

| Field | Value |
|-------|-------|
| Path | `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` |
| Size | _run locally_ |
| SHA-256 | _run locally_ |
| `aapt dump badging` | _run locally_ |

## `hasMonetizationConfig` (actual logic)

```text
hasLevelPlayAppKey
&& hasLevelPlayAdUnits   // interstitial + rewarded + banner
&& (hasAdsterraDirectLink || hasAdsterraWebViewZones)
```

WebView zone = any complete script+base pair (popunder, native, or 728).

## Device test summary

| Model | Android | Step 1–8 | Notes |
|-------|---------|----------|-------|
| _TBD_ | _TBD_ | _TBD_ | User fills `docs/DEVICE_TEST_RESULTS.md` |

## Expected logcat (Task 3 checklist)

| Line | Status |
|------|--------|
| `[AdConfig] dump` … all required keys `<set>` | Implemented |
| `[Lumio] Firebase init OK` | If `google-services.json` present |
| `[LevelPlay] init success` | After consent + defines + RC |
| `[LevelPlay] interstitial loaded` | **Missing today** — P7-001 |
| `[Adsterra] popunder loaded` | **Missing today** — use `adsterra_native_loaded` or P7-002 |

## Deferred (post–7a)

- Play Integrity Option A (`PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER`)
- Headless Adsterra automation
- Production `CAP_BASE_URL` + HMAC endpoint
- `ADSTERRA_TELEMETRY_URL` + HMAC backend
- LevelPlay dashboard Unity mediation network ID audit
- Log gaps P7-001 … P7-003 (`docs/PHASE7_BUGS.md`)

## Commits (Phase 7a)

1. `phase7a: secrets template and BUILD.md`
2. `phase7a: AdConfig.dumpRedacted bring-up`
3. `phase7a: device test and firebase docs`
4. `phase7a: release notes`
