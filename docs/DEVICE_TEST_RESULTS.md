# Phase 7a/7b — physical device smoke results

Fill after running `scripts/device_smoke.sh` or a manual session with:

```bash
./scripts/flutter_run_with_ads.sh
```

Redact PII before commit:

```bash
sed -E 's/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/<INSTALL_ID>/g' \
  logs/device_smoke_*.log
```

## Build under test

| Field | Value |
|-------|-------|
| Run command | `./scripts/flutter_run_with_ads.sh` |
| Smoke script | `./scripts/device_smoke.sh` |
| Device model | |
| Android API | |
| Log file | `logs/device_smoke_YYYYMMDD_HHMMSS.log` |

## Latest log review (2026-05-26 — plain `flutter run`)

| Check | Result | Evidence |
|-------|--------|----------|
| P7-006 stored consent | **PASS** | `stored consent applied to LevelPlay (granted)` |
| P7-006 native GDPR | **PASS** | `LevelPlay=true` (not false) |
| dart-defines loaded | **FAIL** | All keys `<unset>` + ⚠️ WARNING |
| Debug ad gate | **FAIL** | `ads blocked in non-release build` |
| AdManager init | **FAIL** | `monetization config incomplete` |
| LevelPlay init | **FAIL** | Not reached (no keys) |

**Action:** Stop app → `./scripts/flutter_run_with_ads.sh` → re-verify.

## Smoke checklist (fill Pass/Fail)

| Check | Expected log line | Pass/Fail | Notes |
|-------|-------------------|-----------|-------|
| Config dump | `[AdConfig] LEVELPLAY_APP_KEY=<set>` | | |
| Stored consent | `[AdConsent] stored consent applied to LevelPlay (granted)` | | P7-006 fix |
| Native GDPR | `LevelPlaySDK` … `LevelPlay=true` (not false when granted) | | |
| setDynamicUserId | `[LevelPlay] setDynamicUserId before init` | | |
| LevelPlay init | `[LevelPlay] init success` | | |
| Interstitial load | `[LevelPlay] interstitial loaded` | | |
| Banner load | `[LevelPlay] banner loaded` | | |
| Waterfall LP fill | `[waterfall_step] … levelplay … fill` (after 3 channel taps) | | If only `adsterra … fallback` → dashboard/mediation |
| AdManager ready | No `monetization config incomplete` | | |

## Waterfall diagnosis

```bash
adb logcat -d | grep waterfall_step | tail -20
```

| Result | Meaning |
|--------|---------|
| `levelplay … fill` | LevelPlay showing — code OK |
| Only `adsterra … fallback` | LevelPlay no-fill — check IronSource dashboard (Live, test mode off, networks) |

## Capture command

```bash
./scripts/device_smoke.sh
```

Waits for `LEVELPLAY_APP_KEY=<set>` (poll 3s, max 180s), clears logcat, captures 60s. **Tap HOME + 3 channels** during the window. Empty log → `[smoke] FAIL` exit 1.
