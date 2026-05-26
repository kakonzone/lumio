# TASK 1 — Popunder cap bypass fix — device verification

## Preconditions

- `flutter run --dart-define=ADS_TEST_MODE=true` (or release with monetization defines)
- Adsterra popunder zone configured (`ADSTERRA_POPUNDER_SCRIPT_URL` + `ADSTERRA_POPUNDER_BASE_URL`)
- Consent **granted** on splash
- Remote Config: `adsterra_enabled=true`, `popunder_session_cap=1` (for cap test)

## Commands

```bash
adb logcat -c
flutter run --dart-define=ADS_TEST_MODE=true
adb logcat -d | grep -E 'AdDebug|AdManager|popunder|Adsterra'
```

## Expected logcat (cap allowed — first session)

```
[AdDebug] AdManager.maybeShowPopunder: popunder eligible — host may mount WebView
[AdDebug] AdManager: popunder mounted — session cap recorded
```

## Expected logcat (cap blocked — second popunder same session)

With `popunder_session_cap=1` after first mount:

```
[AdDebug] AdManager.maybeShowPopunder: popunder blocked — host will not mount
```

No new `popunder mounted` line. No duplicate Adsterra WebView load in UI (1×1 host stays `SizedBox.shrink()`).

## Manual steps

1. Cold start → grant consent → wait splash delay (~5s).
2. Land on HOME — confirm first log block shows **eligible** then **mounted** (once).
3. Force second cold start within same session is N/A; instead set RC cap to `1`, restart app twice:
   - Run 1: one mount log.
   - Run 2 (new process): if session resets, repeat with in-app navigation only — trigger `maybeShowPopunder` via MainShell `initState` once per process.
4. Deny consent → restart → expect **blocked** only (no mount log).
5. Set RC `adsterra_enabled=false` → publish → restart → expect **blocked**.

## Pass criteria

| # | Check |
|---|--------|
| 1 | No popunder WebView load when cap exceeded |
| 2 | `recordAdsterraPopunder` only after mount log |
| 3 | `flutter test test/ads/popunder_cap_test.dart` passes |
