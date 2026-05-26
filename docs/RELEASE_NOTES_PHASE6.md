# Release notes — Phase 6 (ads gap closure)

**App:** Lumio Sports TV (`com.kakonzone.lumio`)  
**Package:** `unity_levelplay_mediation` 9.2.0 · `webview_flutter` 4.13.1  
**Status:** Code + automation complete — **READY_FOR_DEVICE_TEST** until Task 13 sign-off on release APK

---

## Summary

Phase 6 closes the monetization audit gaps: manifest/init hardening, honest caps, server contracts, device identity, VPN-aware routing, consent gating, full placement map, private Adsterra telemetry, and automated tests. Nothing is marked **COMPLETE** for production until `docs/DEVICE_TEST_CHECKLIST.md` sign-off on a real device.

---

## What shipped (Tasks 1–13)

| Task | Topic | Status |
|------|--------|--------|
| 1 | LevelPlay manifest key + init timeout/retry | READY_FOR_DEVICE_TEST |
| 2 | Channel-tap analytics labels (`levelplay_interstitial_a/b`) | READY_FOR_DEVICE_TEST |
| 3 | Server cap API client (`CAP_BASE_URL`, HMAC) | READY_FOR_DEVICE_TEST |
| 4 | Caps recorded only on `onAdDisplayed` / reward | READY_FOR_DEVICE_TEST |
| 5 | Install ID migration, encrypted prefs, VPN signals, integrity stub | READY_FOR_DEVICE_TEST |
| 6 | `ADS_TEST_MODE` for debug ad testing | READY_FOR_DEVICE_TEST |
| 7 | Banner refresh constant renamed (dashboard-only) | READY_FOR_DEVICE_TEST |
| 8 | Adsterra telemetry POST (not Firebase) | READY_FOR_DEVICE_TEST |
| 9 | Consent before splash timer + drawer privacy screen | READY_FOR_DEVICE_TEST |
| 10 | Placement map (NEWS, exit stack, splash direct, `aggressive_mode`) | READY_FOR_DEVICE_TEST |
| 11 | Removed unused `flutter_inappwebview` | COMPLETE (build) |
| 12 | Unit + `integration_test/ad_smoke_test.dart` | COMPLETE (CI) |
| 13 | Final release sign-off runbook | `docs/DEVICE_TEST_TASK_13.md` — human COMPLETE on device |

---

## Release build (recommended defines)

```bash
flutter build apk --release \
  --dart-define=LEVELPLAY_APP_KEY=YOUR_LEVELPLAY_KEY \
  --dart-define=FINGERPRINT_MIGRATION_SALT=your_stable_salt \
  --dart-define=CAP_BASE_URL=https://your.api.example.com/v1/ \
  --dart-define=ADSTERRA_TELEMETRY_URL=https://your.api/v1/adsterra/event \
  --dart-define=ADSTERRA_TELEMETRY_HMAC_KEY=your_telemetry_secret
```

Optional defines are no-ops when unset (local caps + no telemetry POST). See per-API docs:

- `docs/SERVER_CAP_API.md`
- `docs/ADSTERRA_TELEMETRY_API.md`
- `docs/LEVELPLAY_SDK_VERIFICATION.md`
- `docs/PHASE5_SECURITY.md`
- `docs/PLACEMENT_MAP.md`

---

## Operator actions (before store/sideload)

1. LevelPlay dashboard: set your banner unit (`LEVELPLAY_BANNER_AD_UNIT`) auto-refresh **60s**; Unity mediated in dashboard only.
2. Firebase Remote Config: confirm defaults for `adsterra_enabled`, `popunder_session_cap`, `aggressive_mode`.
3. Run final sign-off: `docs/DEVICE_TEST_TASK_13.md` (Tasks 1–10 on release APK).
4. Run automated tests: `flutter test test/` (41 tests) + integration smoke.

---

## Not in this release (deferred)

See `docs/DEFERRED_vNEXT.md`:

- Background headless Adsterra (`flutter_inappwebview` removed until implemented)
- Real Play Integrity (stub token only)
- LevelPlay native widget (use Adsterra list natives)

---

## Breaking / migration notes

- **Legacy users:** `lumio_device_fingerprint` without `lumio_install_id` → derived install ID on first launch after upgrade (`FINGERPRINT_MIGRATION_SALT` must stay stable per release channel).
- **Debug:** Ads off unless `ADS_TEST_MODE=true` (replaces blanket silent failure without opt-in).
- **Analytics:** Events named `unity` / `channel_tap_unity` must not appear; use `levelplay_interstitial_a` / `_b`.

---

## Key logcat tags

```text
[AdSafety] [LevelPlay] [Cap] [CapClient] [AdsterraTelemetry] [AdConsent] [Integrity]
```

---

## Sign-off

| Role | Name | Date | Release APK build # |
|------|------|------|---------------------|
| Dev device test | | | |
| Ads / monetization | | | |

When all rows are filled and checklist items checked, this release may be labeled **COMPLETE** for distribution.
