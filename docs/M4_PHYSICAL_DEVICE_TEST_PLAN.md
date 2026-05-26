# M4 — Physical device test plan (Task 13 sign-off)

**Phase 3 M4** — Document only; do not execute in CI.  
**Prerequisite:** Phase 2 green, release APK built with production defines (`docs/B6_RELEASE_BUILD.md`).

**Parent checklist:** `docs/DEVICE_TEST_TASK_13.md`

---

## 1. Device matrix (minimum)

| # | Device profile | Android | Network | Purpose |
|---|----------------|---------|---------|---------|
| D1 | Mid-range phone | 12–14 | Home Wi‑Fi | Primary sign-off |
| D2 | Low-RAM phone | 10–11 | 4G mobile data | Memory + cap sync |
| D3 | Tablet or large phone | 13+ | Home Wi‑Fi | Layout + banner refresh |

Optional D4: Same as D1 on **guest Wi‑Fi** (see M5 soak plan).

---

## 2. Build under test

```bash
export LEVELPLAY_APP_KEY='***'
export LEVELPLAY_INTERSTITIAL_AD_UNIT='***'
export LEVELPLAY_REWARDED_AD_UNIT='***'
export LEVELPLAY_BANNER_AD_UNIT='***'
export CAP_BASE_URL='https://your.api.example.com/v1/'
export PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER='***'  # optional

./tool/build_release_apk.sh
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Record: APK filename, `sha256sum` of APK, build date, git commit hash.

---

## 3. Session script (90 minutes)

### 3.1 Cold start (10 min)

| Step | Action | Pass criteria |
|------|--------|---------------|
| 1 | `adb logcat -c`; force-stop app; launch | No crash |
| 2 | First launch | Consent dialog **before** any full-screen ad |
| 3 | Tap **Personalized** | Wait ≥5s; then `[LevelPlay] init success` in logcat |
| 4 | Splash | App-open **substitute** (interstitial) ≤3/day behavior |
| 5 | Note `[AdSafety]` line | `installId`, `vpn_confidence`, `vpn_tier` present |

### 3.2 HOME + banner (15 min)

| Step | Action | Pass criteria |
|------|--------|---------------|
| 6 | Stay on HOME 65+ seconds | Banner loads; optional second impression ~60s |
| 7 | Log grep `[Banner]` or `home_bottom` | No WebView overlay on video |
| 8 | `[Placement] aggressive_mode=...` | Logged once per process |

### 3.3 Channel funnel + caps (20 min)

| Step | Action | Pass criteria |
|------|--------|---------------|
| 9 | Tap channel 1 | Rotator / direct link per funnel |
| 10 | Tap channel 2 | Player opens |
| 11 | 3rd+ taps in session | Interstitial respects 90s cooldown |
| 12 | With `CAP_BASE_URL` set | `[ServerCap] synced` or `fail_closed` — never silent unlimited server bypass |

### 3.4 NEWS / SPORTS / LIVE (15 min)

| Step | Action | Pass criteria |
|------|--------|---------------|
| 13 | NEWS tab | Native interval 5 (or 4 aggressive) |
| 14 | SPORTS tab | Banner top; no overflow |
| 15 | LIVE shell | Popunder cap ≤ RC `popunder_session_cap` |

### 3.5 Privacy + exit (10 min)

| Step | Action | Pass criteria |
|------|--------|---------------|
| 16 | Drawer → Ads & privacy | Toggle Limited ↔ Personalized |
| 17 | Log after toggle | `[AdConsent] LevelPlay privacy flags applied` |
| 18 | Back from HOME | Exit interstitial or direct link once per session |

### 3.6 Server cap fail-closed (10 min) — M2

| Step | Action | Pass criteria |
|------|--------|---------------|
| 19 | Point `CAP_BASE_URL` to dead host OR airplane mode after cache expiry | `[ServerCap] fail_closed` in logcat |
| 20 | Attempt interstitial | **Blocked** (no show) |
| 21 | Restore API / network; cold start | Sync succeeds; ads allowed again |

### 3.7 Integrity (optional, 10 min)

| Step | Action | Pass criteria |
|------|--------|---------------|
| 22 | Play-installed build with GCP project linked | `[Integrity] play token ready` or `stub token` |
| 23 | First cap GET | `X-Integrity-Token` header (proxy via server logs) |

---

## 4. Log harvest

```bash
adb logcat -d > lumio-task13-$(date +%Y%m%d).log
grep -E '\[AdSafety\]|\[AdConsent\]|\[LevelPlay\]|\[ServerCap\]|\[Integrity\]|\[Placement\]|\[Cap\]' lumio-task13-*.log | tail -200
```

Attach log file to release sign-off ticket.

---

## 5. Per-task doc cross-reference

| Task | Doc | Device step |
|------|-----|-------------|
| 1 Firebase | `DEVICE_TEST_TASK_1.md` | §3.1 |
| 2 Server cap | `DEVICE_TEST_TASK_2.md` | §3.6 |
| 5 Identity/VPN | `DEVICE_TEST_TASK_5.md` | §3.1 |
| 7 Banner 60s | `DEVICE_TEST_TASK_7.md` | §3.2 |
| 9 Consent/CCPA | `DEVICE_TEST_TASK_9.md` | §3.1, §3.5 |
| 10 Placements | `DEVICE_TEST_TASK_10.md` | §3.4 |
| 12 Automation | `DEVICE_TEST_TASK_12.md` | CI before device |
| H5 Popunder | `POPUNDER_POLICY_REVIEW_H5.md` | §3.4 LIVE |

---

## 6. Sign-off sheet

| Field | Value |
|-------|--------|
| Tester name | |
| Date | |
| APK SHA-256 | |
| D1 / D2 / D3 passed | ☐ |
| Blocking defects | |
| Approved for distribution | ☐ |

**REQUIRES DEVICE TEST** — this document is the plan only; execution is manual.
