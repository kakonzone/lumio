# Production readiness — audit follow-up

**Date:** 2026-05-25 (updated after bug-fix sprint Tasks 1–9)  
**Honest estimate:** **~88%** — code + unit tests complete; device evidence still required for 90%+

---

## Priority 0 — ship blockers

| Task | Status | Evidence |
|------|--------|----------|
| 0.1 AdManager `isReady` | **PASS** | `lib/ads/ad_manager.dart` — `isReady` after LevelPlay + config |
| 0.2 Firebase + RC | **PASS** (code) | `FirebaseBootstrap` before ads; **Console:** SHA-1 + RC publish — `docs/FIREBASE_PRECHECK.md` |
| 0.3 dart-define secrets | **PASS** | `tool/build_release_apk.sh`, `.env.example`, `docs/SECRETS_MIGRATION.md` |
| 0.4 Play Integrity | **PASS (Option B)** | Stub removed; v1.1 Option A — `docs/PLAY_INTEGRITY_OPTION_B.md` |
| 0.5 VPN detection | **PASS** (code) | Native bridge + `VpnSignalService`; device VPN on/off — `DEVICE_TEST_TASK_5.md` |

---

## Priority 1 — high

| Task | Status | Evidence |
|------|--------|----------|
| 1.1 Click hygiene | **PASS** | `logClick` / `logFirstClickBrowser` wired |
| 1.2 Adsterra waterfall | **PASS** | `waterfall_logic.dart`, `docs/AD_WATERFALL.md` |
| 1.3 Server cap HMAC | **PASS** | `docs/SERVER_CAP_API.md` aligned with client |
| 1.4 Locale VPN heuristic | **PASS** | `test/security/vpn_signal_service_test.dart` |
| 1.5 Merged manifest | **PASS** | `docs/MERGED_MANIFEST_AUDIT.md` |

---

## Priority 2 — medium

| Task | Status | Evidence |
|------|--------|----------|
| 2.1 DRIFT 18 rows | **PASS** | `docs/DRIFT_RESOLUTION.md` |
| 2.2 Native load fallback | **PASS** | Kotlin `nativeAvailable` flag |
| 2.3 Fingerprint entropy | **PASS** | Full SHA-256 in `ad_safety_service.dart` |
| 2.4 Dead code | **PASS** | Analyze clean on ad paths |

---

## Priority 3 — polish

| Task | Status | Evidence |
|------|--------|----------|
| 3.1 RenderFlex overflow | **PASS** | `test/widget/shell_app_bar_overflow_test.dart`, `main_shell_bottom_nav_overflow_test.dart` |
| 3.2 Test suite | **PASS** | `docs/TEST_SUITE.md` — run outside sandbox |

---

## Bug-fix sprint (Tasks 1–9)

| Task | Status | Evidence |
|------|--------|----------|
| 1 Popunder cap bypass | **PASS** | `AdsterraPopunderHost.canMount()`, `test/ads/popunder_cap_test.dart` — `docs/TASK_1_VERIFICATION.md` |
| 2 `ADS_ENABLED` dart-define | **PASS** | `AdConfig.adsEnabledDefine`, `scripts/run_debug_with_ads.sh` — `docs/TASK_2_VERIFICATION.md`, `docs/AD_TESTING.md` |
| 3 Secrets out of source | **PASS** | `grep` clean on `lib/`; `.env.example` — `docs/TASK_3_VERIFICATION.md` |
| 4 Interstitial cap on display | **PASS** | `recordInterstitialShown` only on `onAdDisplayed` — `docs/TASK_4_VERIFICATION.md` |
| 5 Channel tap labels | **PASS** | `levelPlayMediatedA/B`; no `unity` SDK enum — `docs/TASK_5_VERIFICATION.md` |
| 6 Remove inappwebview | **PASS** | Removed from `pubspec.yaml`; `test/build_hygiene_test.dart` |
| 7 Portable debug paths | **PASS** | `path_provider`; no `/home/kakonzone` in `lib/` — `test/utils/ad_debug_log_test.dart` |
| 8 `aggressive_mode` RC | **PASS** | `scaledCooldownSeconds`, placement config — `test/ads/aggressive_mode_test.dart` |
| 9 Device verification docs | **PASS** | `docs/DEVICE_VERIFICATION_RUNBOOK.md`, `DEVICE_TEST_RESULTS_TEMPLATE.md`, `scripts/capture_logcat.sh` |

---

## Automated verification (2026-05-25)

```bash
flutter test
# Expected: All tests passed (82+)

grep -rE 'YOUR_APP_KEY|adsterra\.com/zones|/home/kakonzone|stub:' lib/
# Expected: no matches (except comments)

grep -rn 'kDebugMode' lib/services/ironsource_service.dart lib/services/ad_safety_service.dart lib/services/ad_consent_service.dart lib/ads/
# Expected: no matches (ad_log.dart comment only)
```

---

## Remaining blockers (honest)

| Blocker | Owner | Doc |
|---------|-------|-----|
| Firebase Console SHA-1 + RC **Publish** | You | `docs/FIREBASE_PRECHECK.md` |
| Release APK with real `--dart-define` keys | You | `docs/SECRETS.md`, `scripts/build_release_apk.sh` |
| Device test evidence attached | You | `docs/DEVICE_TEST_RESULTS_TEMPLATE.md` |
| v1.1 Play Integrity (optional) | Later | `docs/PLAY_INTEGRITY_OPTION_B.md` |

---

## Readiness %

| Milestone | % |
|-----------|---|
| Code + unit tests (P0–P3 + sprint 1–9) | **~88%** |
| + Firebase Console + one release APK build | ~90% |
| + Device checklist signed + short soak | **90%+** |

---

## Recommended next 3 actions

1. **Firebase** — Add debug SHA-1, publish RC (`vpn_locale_strictness` = `loose`), confirm `[Lumio] Firebase init OK` on device.
2. **Release build** — `source .env` from `.env.example`, run `./scripts/build_release_apk.sh`, install on phone.
3. **Device pass** — `./scripts/capture_logcat.sh`, complete `docs/DEVICE_TEST_RESULTS_TEMPLATE.md`.

---

## Verification doc index

| Doc |
|-----|
| `docs/TASK_1_VERIFICATION.md` … `TASK_5_VERIFICATION.md` |
| `docs/TASK_3_VERIFICATION.md` (secrets) |
| `docs/FIREBASE_PRECHECK.md` |
| `docs/AD_TESTING.md` |
| `docs/DEVICE_VERIFICATION_RUNBOOK.md` |
