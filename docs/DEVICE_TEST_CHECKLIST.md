# Device test checklist — Lumio ads (Phase 6)

Use **READY_FOR_DEVICE_TEST** until a human confirms each section on a **release** APK.  
Automated coverage: `flutter test test/` (see Task 12).  
Release summary: `docs/RELEASE_NOTES_PHASE6.md`.

---

## Quick start

### Full release build

```bash
flutter build apk --release \
  --dart-define=LEVELPLAY_APP_KEY=YOUR_KEY \
  --dart-define=FINGERPRINT_MIGRATION_SALT=lumio_fp_migration_v1 \
  --dart-define=CAP_BASE_URL=https://your.api/v1/cap/check \
  --dart-define=CAP_HMAC_KEY=your_cap_secret \
  --dart-define=ADSTERRA_TELEMETRY_URL=https://your.api/v1/adsterra/event \
  --dart-define=ADSTERRA_TELEMETRY_HMAC_KEY=your_telemetry_secret

adb install -r build/app/outputs/flutter-apk/app-release.apk
adb logcat -c
# cold start, exercise flows, then:
adb logcat -d | grep -E '\[AdSafety\]|\[LevelPlay\]|\[Cap\]|\[ServerCap\]|\[AdsterraTelemetry\]|\[AdConsent\]|\[Placement\]|\[Banner\]'
```

### Debug ad testing

```bash
flutter run --dart-define=ADS_TEST_MODE=true --dart-define=LEVELPLAY_APP_KEY=YOUR_KEY
```

---

## Task 1 — Manifest + LevelPlay init

**READY_FOR_DEVICE_TEST**

| Pattern | Expected |
|---------|----------|
| `[AdSafety] installId=` | UUID + fingerprint once per process |
| `[LevelPlay] setDynamicUserId` | 32-char hash before init |
| `[LevelPlay] init success` | After consent + splash preload |
| `[LevelPlay] init_failed reason=` | Only on failure; may retry once |

**Manual**

1. Install release APK with correct `LEVELPLAY_APP_KEY`.
2. Cold start → consent → splash → HOME.
3. Banner area loads without crash.

---

## Task 2 — Channel-tap labels (no fake “Unity SDK”)

**READY_FOR_DEVICE_TEST**

| Slot | `channel_tap_slot` | `interstitial_shown` trigger |
|------|-------------------|------------------------------|
| A | `levelplay_interstitial_a` | `channel_tap_levelplay_a` |
| B | `levelplay_interstitial_b` | `channel_tap_levelplay_b` |

**Must NOT appear:** `unity`, `channel_tap_unity`.

**Manual:** First channel tap per day → verify Firebase/debug event params for slots A and B.

---

## Task 3 — Server cap client

**READY_FOR_DEVICE_TEST**

| Log pattern | Meaning |
|-------------|---------|
| `[CapClient] disabled reason=CAP_BASE_URL unset` | Expected without defines |
| `[CapClient] fallback reason=` | Server down → local caps |
| (no fallback) | Server 200 with `allow` |

**Manual**

1. Without defines: disabled log once on cold start.
2. Mock `allow:false` → interstitial blocked.
3. Mock `allow:true` → interstitial allowed if local caps allow.

---

## Task 4 — Cap recorded only on display

**READY_FOR_DEVICE_TEST**

| Pattern | When |
|---------|------|
| `[Cap] shown placement=interstitial` | `onAdDisplayed` only |
| `[Cap] shown placement=app_open_substitute` | Cold-start substitute shown |
| `[Cap] timeout_no_show` | No following `shown` |
| `[Cap] display_failed` | No `shown` |

**Manual:** One `shown` per actual display; no false cap on timeout/close.

---

## Task 5 — Fingerprint + VPN + integrity stub

**READY_FOR_DEVICE_TEST**

| Pattern | Expected |
|---------|----------|
| `[AdSafety] vpn_signals interfaces=` | `true` with VPN (tun/ppp) active |
| `locale_mismatch` / `tz_mismatch` | Independent; `preferCleanSdk` when ≥2 true |
| `[Integrity] stub token` | Debug only when cap URL set |

**Manual**

1. Upgrade from legacy fingerprint-only build → stable `installId`.
2. VPN + premium locale + South Asia TZ → Adsterra off, LevelPlay routing on.

---

## Task 6 — Debug `ADS_TEST_MODE`

**READY_FOR_DEVICE_TEST**

| Build | Expected |
|-------|----------|
| `flutter run` (no define) | `[LevelPlay] init skipped (debug)`, no banner |
| `ADS_TEST_MODE=true` | `[AdSafety] ADS_TEST_MODE=true`, init success |

Release APK ignores `ADS_TEST_MODE`.

---

## Task 7 — Banner refresh (dashboard)

**READY_FOR_DEVICE_TEST**

1. LevelPlay dashboard → your banner unit (`LEVELPLAY_BANNER_AD_UNIT`) → auto-refresh **60s**.
2. HOME ≥65s → second banner impression (network permitting).

Code: `AdConfig.levelPlayBannerDashboardRefreshSeconds` (not an SDK call).

---

## Task 8 — Adsterra telemetry POST

**READY_FOR_DEVICE_TEST**

| Pattern | Meaning |
|---------|---------|
| `disabled reason=ADSTERRA_TELEMETRY_URL unset` | No POST (OK) |
| `post_failed` | Server/signature issue (once per process) |

**Manual:** With defines, server receives `installId`, `fingerprint`, `format` on popunder/channel tap/WebView load.

---

## Task 9 — Consent + privacy settings

**READY_FOR_DEVICE_TEST**

**First install**

1. Consent dialog **before** any interstitial.
2. ≥5s after choice before ad SDK preload (`splashMinMsBeforeAds`).
3. No `[LevelPlay] init` before consent.

**Returning user**

1. Drawer → **Ads & privacy** → toggle choice → SnackBar → persists after restart.

---

## Task 10 — Placement map + `aggressive_mode`

**READY_FOR_DEVICE_TEST**

| Check | How |
|-------|-----|
| NEWS natives | Every ~5 articles (/4 if `aggressive_mode=true`) |
| Splash direct | Browser may open after splash interstitial (≤3/day) |
| Exit stack | Back on HOME → IS or Adsterra; second back exits |
| Social bar | Off unless `aggressive_mode=true` |

See `docs/PLACEMENT_MAP.md`.

---

## Task 11 — `flutter_inappwebview` removed

**COMPLETE (build hygiene)**

- Not in `pubspec.yaml`; all Adsterra uses `webview_flutter`.

---

## Task 12 — Automated tests

**COMPLETE (CI / local)** — see `docs/DEVICE_TEST_TASK_12.md`

```bash
flutter test test/
flutter test integration_test/ad_smoke_test.dart -d linux    # or Android device id
```

**41** unit/widget tests (incl. Task 11 `build_hygiene_test`); integration smoke covers consent + privacy UI.

---

## Task 13 — Final sign-off

**Human gate** — full runbook: **`docs/DEVICE_TEST_TASK_13.md`**

**COMPLETE** when Tasks **1–10** pass on a **release APK** and the sign-off table in that doc is filled (Tasks **11–12** via automation).

| # | Area | Pass | Tester | Date | Notes |
|---|------|------|--------|------|-------|
| 1 | LevelPlay init + banner | ☐ | | | |
| 2 | Channel-tap analytics labels | ☐ | | | |
| 3 | Server cap (or disabled log) | ☐ | | | |
| 4 | Cap `shown` honesty | ☐ | | | |
| 5 | Fingerprint / VPN routing | ☐ | | | |
| 6 | Debug `ADS_TEST_MODE` (optional) | ☐ | | | |
| 7 | Banner dashboard 60s | ☐ | | | |
| 8 | Telemetry POST (or disabled) | ☐ | | | |
| 9 | Consent + privacy screen | ☐ | | | |
| 10 | Placement map + aggressive RC | ☐ | | | |
| 11 | Build hygiene (automated) | ☐ | | | |
| 12 | `flutter test test/` + integration smoke | ☐ | | | |

**Overall release status:** ☐ READY_FOR_DEVICE_TEST → ☐ **COMPLETE**

---

## Reference docs

| Doc | Purpose |
|-----|---------|
| `RELEASE_NOTES_PHASE6.md` | What shipped, build flags, deferred |
| `PLACEMENT_MAP.md` | Screen-by-screen placements |
| `PHASE5_SECURITY.md` | Identity, VPN, consent |
| `SERVER_CAP_API.md` | Cap POST contract |
| `ADSTERRA_TELEMETRY_API.md` | Private telemetry POST |
| `LEVELPLAY_SDK_VERIFICATION.md` | SDK 9.2.0 signatures |
| `DEFERRED_vNEXT.md` | Not in this release |
