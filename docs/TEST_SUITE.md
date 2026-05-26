# Test suite — runbook (Task 3.2)

## Sandbox / permission blocker

Running `flutter test` inside Cursor’s default sandbox (or as root) can fail before tests execute:

```
/home/kakonzone/flutter/bin/internal/update_engine_version.sh: line 64: .../engine.stamp: Permission denied
```

**Fix:** run tests outside the sandbox with a normal user shell:

```bash
cd /path/to/lumio
flutter test
```

Do **not** use `sudo flutter test`.

## CI / fresh shell (recommended)

```bash
flutter pub get
flutter test --reporter expanded
```

Optional focused suites:

```bash
flutter test test/widget/shell_app_bar_overflow_test.dart
flutter test test/widget/main_shell_bottom_nav_overflow_test.dart
flutter test test/security/vpn_signal_service_test.dart
```

## SharedPreferences in unit tests

`ServerCap.allowsPlacement()` reads hourly counters via `shared_preferences`. Tests that hit configured caps must call:

```dart
TestWidgetsFlutterBinding.ensureInitialized();
SharedPreferences.setMockInitialValues({});
```

See `test/services/server_cap_fail_closed_test.dart`.

## Latest run (2026-05-25)

| Metric | Value |
|--------|-------|
| Command | `flutter test` (non-sandbox, user `kakonzone`) |
| Result | **82 passed, 0 failed** |
| Sprint ads | `popunder_cap_test.dart`, `aggressive_mode_test.dart`, `ad_config_secrets_test.dart`, `build_hygiene_test.dart`, `ad_debug_log_test.dart` |
| Widget overflow | `shell_app_bar_overflow_test.dart` (3), `main_shell_bottom_nav_overflow_test.dart` (2) |

## Fixes applied in P3

| Test file | Issue | Fix |
|-----------|-------|-----|
| `vpn_signal_service_test.dart` | Wrong package `package:lumio/...` | `package:lumio_tv/...` |
| `ad_safety_migration_test.dart` | Expected 48-char installId | UUID format is 36 chars |
| `server_cap_fail_closed_test.dart` | Binding / SharedPreferences | `ensureInitialized` + mock prefs |
| `vpn_detector_test.dart` | ASN count 50 vs 51; legacy 2-signal routing | Expect 51; single-signal suspected case |
