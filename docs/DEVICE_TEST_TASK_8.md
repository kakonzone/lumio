# Device test — Task 8 (Adsterra telemetry POST)

**READY_FOR_DEVICE_TEST**

---

## What this is

Private **POST** for Adsterra / aggressive-layer events — **not** Firebase Analytics.

| File | Role |
|------|------|
| `lib/ads/adsterra_telemetry_client.dart` | HMAC-signed HTTP client |
| `lib/utils/ad_debug_log.dart` | `logAdsterraTelemetry()` entry |
| `docs/ADSTERRA_TELEMETRY_API.md` | Full contract |

---

## Build variants

### A — Disabled (default)

```bash
flutter run --dart-define=ADS_TEST_MODE=true
```

**Expect once per cold start (after ads init):**

`[AdsterraTelemetry] disabled reason=ADSTERRA_TELEMETRY_URL unset`

No network POST. Debug builds may still `debugPrint` telemetry lines from `logAdsterraTelemetry`.

### B — Enabled

```bash
flutter run \
  --dart-define=ADS_TEST_MODE=true \
  --dart-define=ADSTERRA_TELEMETRY_URL=https://your-api.example.com/v1/adsterra/event \
  --dart-define=ADSTERRA_TELEMETRY_HMAC_KEY=your_shared_secret
```

Release:

```bash
flutter build apk --release \
  --dart-define=ADSTERRA_TELEMETRY_URL=... \
  --dart-define=ADSTERRA_TELEMETRY_HMAC_KEY=...
```

---

## Trigger events on device

| Action | `placement` | `format` |
|--------|-------------|----------|
| Popunder shown (cap recorded) | `popunder` | `popunder` |
| Channel tap → Adsterra slot | `channel_tap_first` | `direct_link` |
| Player video overlay | `player_video` | `video_overlay` |
| Adsterra WebView load | e.g. `sports_top` | `banner_webview` / `native_webview` |
| Back exit direct link | `back_exit` | `direct_link` |

Requires `adsterra_enabled` (Remote Config) and VPN routing **not** forcing LevelPlay-only.

---

## Log patterns

```bash
adb logcat -d | grep '\[AdsterraTelemetry\]'
```

| Pattern | Meaning |
|---------|---------|
| `disabled reason=ADSTERRA_TELEMETRY_URL unset` | No POST (OK for variant A) |
| `disabled reason=ADSTERRA_TELEMETRY_HMAC_KEY unset` | URL set but key missing |
| `post_ok placement=... format=...` | First HTTP 2xx this process |
| `post_failed reason=...` | First failure this process (signature/URL/server) |

POST body fields: `installId`, `fingerprint`, `placement`, `format`, `timestampMs`, optional `extra`.  
Header: `X-Telemetry-Signature` = HMAC-SHA256(body, key).

---

## Pass / fail criteria

| # | Criterion | Pass |
|---|-----------|------|
| 1 | Variant A: disabled log once, no crash | ☐ |
| 2 | Variant B: server receives JSON with installId + fingerprint | ☐ |
| 3 | At least one `post_ok` after popunder or WebView load | ☐ |
| 4 | UI never blocks on POST failure (at most one `post_failed`) | ☐ |
| 5 | `flutter test test/ads/adsterra_telemetry_client_test.dart` | ☐ |

**Automated:**

```bash
flutter test test/ads/adsterra_telemetry_client_test.dart
```

**Task 8 result:** ☐ PASS ☐ FAIL — Tester: __________ Date: __________
