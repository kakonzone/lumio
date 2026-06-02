# rc1 baseline — `release/v1.0.0-rc1` branch

Recorded: Phase 0 setup.

## `flutter analyze`

Exit code: 1 (105 issues — mostly `info`/`warning`, no blocking errors in `lib/`).

## `flutter test` (before fixes)

**Result:** 141 passed, 1 skipped, **4 failed**.

| Test | First error line |
|------|------------------|
| `test/ads/ad_consent_service_test.dart` — `setConsent persists and starts splashMinMsBeforeAds window` | `Expected: <2500>` / `Actual: <400>` |
| `test/services/server_cap_fail_closed_test.dart` — `allowsPlacement false when configured and fail-closed` | `Expected: true` / `Actual: <false>` (`isFailClosed`) |
| `test/services/server_cap_fail_closed_test.dart` — `at server limit still allows when not fail-closed` | `Expected: false` / `Actual: <true>` (`allowsPlacement`) |
| `test/widget_test.dart` — `ad config constants are pinned` | `Expected: <2500>` / `Actual: <400>` |
