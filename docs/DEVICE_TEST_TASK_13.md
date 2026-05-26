# Task 13 — Final release sign-off (production)

**Status:** Fill this after Tasks **1–10** on a **release APK** on a physical Android device.  
Tasks **11–12** are satisfied by CI/local automation (see `docs/DEVICE_TEST_TASK_12.md`).

**Phase 3 M4 expanded plan:** `docs/M4_PHYSICAL_DEVICE_TEST_PLAN.md` (90‑min session script + sign-off sheet).

---

## Pre-flight (before installing on phone)

### 1. Automated gate (must pass)

```bash
flutter pub get
flutter test test/                    # 41 tests
flutter test integration_test/ad_smoke_test.dart -d linux
```

### 2. Operator / dashboard

| Item | Action |
|------|--------|
| LevelPlay | Banner unit (`LEVELPLAY_BANNER_AD_UNIT`) → auto-refresh **60s**; Unity Ads mediated in dashboard only |
| Firebase | `google-services.json` in `android/app/` if using Analytics / RC |
| Remote Config | Defaults: `adsterra_enabled`, `popunder_session_cap`, `aggressive_mode` |
| Migration salt | Pin `FINGERPRINT_MIGRATION_SALT` per release channel (do not change mid-rollout) |

### 3. Build release APK

**Minimal (local caps, no server telemetry):**

```bash
export LEVELPLAY_APP_KEY=your_levelplay_app_key
./tool/build_release_apk.sh
```

**Full backend (optional):**

```bash
export LEVELPLAY_APP_KEY=your_key
export CAP_BASE_URL=https://your.api.example.com/v1/
export ADSTERRA_TELEMETRY_URL=https://your.api.example.com/v1/adsterra/event
export ADSTERRA_TELEMETRY_HMAC_KEY=your_telemetry_secret

flutter build apk --release \
  --dart-define=LEVELPLAY_APP_KEY="$LEVELPLAY_APP_KEY" \
  --dart-define=FINGERPRINT_MIGRATION_SALT=lumio_fp_migration_v1 \
  --dart-define=CAP_BASE_URL="$CAP_BASE_URL" \
  --dart-define=ADSTERRA_TELEMETRY_URL="$ADSTERRA_TELEMETRY_URL" \
  --dart-define=ADSTERRA_TELEMETRY_HMAC_KEY="$ADSTERRA_TELEMETRY_HMAC_KEY"
```

> **Note:** Server caps use **GET** `{CAP_BASE_URL}/caps/{installId}` (`lib/services/server_cap.dart`).  
> `CAP_HMAC_KEY` is legacy (Phase 6 POST) and is **not** sent by the current client.

Install:

```bash
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# or: app-release.apk if not using split-per-abi
```

---

## Device session (one cold start + flows)

```bash
adb logcat -c
# Use app 10–15 minutes: splash, HOME 65s, channel tap, NEWS, back exit, drawer privacy
adb logcat -d | grep -E '\[Lumio\]|\[AdSafety\]|\[AdConsent\]|\[LevelPlay\]|\[Cap\]|\[Banner\]|\[Placement\]|\[ServerCap\]|\[AdsterraTelemetry\]|\[Integrity\]'
```

**Release builds ignore `ADS_TEST_MODE`** — do not use debug-only flags for this sign-off.

---

## Per-task checklists (detail)

Run each doc on the **same release APK**; check **Pass** when done.

| Task | Doc | Focus |
|------|-----|--------|
| 1 | [DEVICE_TEST_TASK_1.md](DEVICE_TEST_TASK_1.md) | Firebase init / fallback |
| 2 | [DEVICE_TEST_TASK_2.md](DEVICE_TEST_TASK_2.md) | ServerCap GET or `CAP_BASE_URL not set` |
| 3 | [DEVICE_TEST_TASK_3.md](DEVICE_TEST_TASK_3.md) | Shell app bar overflow |
| 4 | [DEVICE_TEST_TASK_4.md](DEVICE_TEST_TASK_4.md) | No vertical overflow |
| 5 | [DEVICE_TEST_TASK_5.md](DEVICE_TEST_TASK_5.md) | installId, VPN, integrity stub |
| 6 | [DEVICE_TEST_TASK_6.md](DEVICE_TEST_TASK_6.md) | *(Optional)* debug ADS_TEST_MODE only |
| 7 | [DEVICE_TEST_TASK_7.md](DEVICE_TEST_TASK_7.md) | Banner dashboard 60s refresh |
| 8 | [DEVICE_TEST_TASK_8.md](DEVICE_TEST_TASK_8.md) | Telemetry POST or disabled |
| 9 | [DEVICE_TEST_TASK_9.md](DEVICE_TEST_TASK_9.md) | Consent before ads; privacy screen |
| 10 | [DEVICE_TEST_TASK_10.md](DEVICE_TEST_TASK_10.md) | Placement map + `aggressive_mode` |

---

## Sign-off table (copy to release record)

| # | Area | Pass | Tester | Date | Notes |
|---|------|------|--------|------|-------|
| 1 | LevelPlay init + banner | ☐ | | | `[LevelPlay] init success`, HOME banner |
| 2 | Channel-tap analytics labels | ☐ | | | `levelplay_interstitial_a/b`, not `unity` |
| 3 | Server cap (or disabled log) | ☐ | | | `[ServerCap] synced` or local-only |
| 4 | Cap `shown` honesty | ☐ | | | One `[Cap] shown` per real display |
| 5 | Fingerprint / VPN routing | ☐ | | | Stable installId; VPN routing |
| 6 | Debug `ADS_TEST_MODE` (optional) | ☐ | | | N/A on release |
| 7 | Banner dashboard 60s | ☐ | | | Two `[Banner] impression` ~60s apart |
| 8 | Telemetry POST (or disabled) | ☐ | | | `post_ok` or URL unset |
| 9 | Consent + privacy screen | ☐ | | | Dialog before init; drawer persists |
| 10 | Placement map + aggressive RC | ☐ | | | `[Placement]` matches RC |

**Prerequisites (automated):**

| # | Area | Pass | Date |
|---|------|------|------|
| 11 | No `flutter_inappwebview` | ☐ | `flutter test test/build_hygiene_test.dart` |
| 12 | Unit + integration tests | ☐ | 41 + 2 smoke tests green |

---

## Release decision

| State | Meaning |
|-------|---------|
| **READY_FOR_DEVICE_TEST** | Code merged; Tasks 11–12 green; Tasks 1–10 not yet signed on device |
| **COMPLETE** | All rows **Pass** on **release APK**; tester name + date recorded |

**Overall release status:** ☐ READY_FOR_DEVICE_TEST → ☐ **COMPLETE**

**Signed off by:** ______________________ **Date:** __________

---

## Blockers (do not mark COMPLETE)

- `[LevelPlay] init_failed` on release without network/dashboard fix
- `[Cap] shown` without user-visible ad (false cap)
- Consent dialog after first interstitial
- `flutter_inappwebview` in dependency tree
- `flutter test test/` failing

---

## Reference

| Doc | Purpose |
|-----|---------|
| [DEVICE_TEST_CHECKLIST.md](DEVICE_TEST_CHECKLIST.md) | Master checklist |
| [RELEASE_NOTES_PHASE6.md](RELEASE_NOTES_PHASE6.md) | What shipped |
| [PLACEMENT_MAP.md](PLACEMENT_MAP.md) | Placements |
| [ADS_README.md](ADS_README.md) | Tri-network setup |
