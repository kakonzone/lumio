# Adsterra private telemetry API

Aggressive-layer impressions are **not** sent to Firebase. Client: `lib/ads/adsterra_telemetry_client.dart`, entry: `logAdsterraTelemetry()` in `lib/utils/ad_debug_log.dart`.

## Configuration

```bash
flutter build apk --release \
  --dart-define=ADSTERRA_TELEMETRY_URL=https://api.example.com/v1/adsterra/event \
  --dart-define=ADSTERRA_TELEMETRY_HMAC_KEY=your_shared_secret
```

| Define | Required | Effect |
|--------|----------|--------|
| `ADSTERRA_TELEMETRY_URL` | Yes (for POST) | Full POST URL |
| `ADSTERRA_TELEMETRY_HMAC_KEY` | Yes (for POST) | HMAC-SHA256 body signature |

If URL or key is empty: `[AdsterraTelemetry] disabled reason=…` once per process; debug `debugPrint` still runs.

## Request

`POST` `ADSTERRA_TELEMETRY_URL`  
`Content-Type: application/json`  
`X-Telemetry-Signature: <hex HMAC-SHA256 of raw body>`

```json
{
  "installId": "uuid",
  "fingerprint": "32-char-sha256",
  "placement": "popunder",
  "format": "popunder",
  "timestampMs": 1716566400123,
  "extra": { "optional": "map" }
}
```

| Field | Description |
|-------|-------------|
| `placement` | Logical zone, e.g. `channel_tap_first`, `player_video`, `sports_top` |
| `format` | `popunder`, `direct_link`, `video_overlay`, `banner_webview`, `native_webview` |

## Client behavior

| Condition | Behavior |
|-----------|----------|
| URL/key unset | No network; debug print only |
| `adsterra_enabled` false (RC) | No POST |
| POST fails | One `[AdsterraTelemetry] post_failed` per process; never blocks UI |
| Success | HTTP 2xx; first success logs `[AdsterraTelemetry] post_ok placement=… format=…` once per process |
| Startup | `AdManager.init` calls `logConfigurationOnce()` so disabled reason appears without an ad event |

## Wired call sites

| Event | `format` |
|-------|----------|
| Popunder cap recorded | `popunder` |
| Channel tap Adsterra slot | `direct_link` |
| Player video overlay | `video_overlay` |
| `AdsterraEngine.openDirectLink` | `direct_link` |
| WebView `onPageFinished` | `banner_webview` / `native_webview` |

**READY_FOR_DEVICE_TEST:** confirm server receives events on release APK with defines set.
