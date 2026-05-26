# Device test — Task 12 (automated tests)

**COMPLETE (CI / local)** — run before release sign-off (Task 13).

---

## Unit + widget suite

```bash
cd /path/to/lumio
flutter pub get
flutter test test/
```

**Current coverage (41 tests):**

| Area | File(s) |
|------|---------|
| Task 1 Firebase bootstrap | `test/services/firebase_bootstrap_test.dart` |
| Task 2 Server cap GET | `test/services/server_cap_test.dart`, `test/ads/server_cap_client_test.dart` |
| Task 3–4 Shell overflow | `test/widget/shell_app_bar_overflow_test.dart` |
| Task 5 Identity / VPN | `test/services/ad_safety_migration_test.dart`, `integrity_attestation_service_test.dart` |
| Task 6 ADS_TEST_MODE | `ad_safety_migration_test.dart` (gating group) |
| Task 7 Banner constant | `test/config/ad_config_banner_refresh_test.dart` |
| Task 8 Telemetry | `test/ads/adsterra_telemetry_client_test.dart` |
| Task 9 Consent | `test/ads/ad_consent_service_test.dart`, `test/widget/ads_privacy_screen_test.dart` |
| Task 10 Placement | `test/ads/ad_placement_config_test.dart`, `ad_placement_news_test.dart` |
| Task 11 Build hygiene | `test/build_hygiene_test.dart` |
| Caps / funnel | `test/ads/ad_trigger_manager_test.dart` |
| App smoke | `test/widget_test.dart` |

**Pass criteria:** exit code `0`, line ends with `All tests passed!`

---

## Integration smoke

```bash
# Device or emulator (recommended)
flutter devices
flutter test integration_test/ad_smoke_test.dart -d <deviceId>

# Linux desktop (widget binding only — no real ads)
flutter test integration_test/ad_smoke_test.dart
```

Covers:

1. First-launch consent dialog (Accept / Limited)
2. **Ads & privacy** settings screen widgets

---

## Task 11 verification (included in suite)

`test/build_hygiene_test.dart` asserts:

- `pubspec.yaml` has **no** `flutter_inappwebview:` dependency
- `webview_flutter` is present
- `pubspec.lock` does not list `flutter_inappwebview`

---

## Optional CI snippet

```yaml
- run: flutter pub get
- run: flutter test test/
- run: flutter test integration_test/ad_smoke_test.dart
```

---

## Pass / fail

| # | Command | Pass |
|---|---------|------|
| 1 | `flutter test test/` → 41 tests green | ☐ |
| 2 | `flutter test integration_test/ad_smoke_test.dart` | ☐ |
| 3 | `build_hygiene_test` (no inappwebview) | ☐ |

**Task 12 result:** ☐ PASS ☐ FAIL — Date: __________

**Next:** Task 13 release APK sign-off — `docs/DEVICE_TEST_CHECKLIST.md` § Final sign-off.
