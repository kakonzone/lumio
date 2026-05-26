# Device test — Task 2 (ServerCap GET + cache)

**READY_FOR_DEVICE_TEST**

---

## Build

### Local caps only (default)

```bash
flutter run --dart-define=ADS_TEST_MODE=true --dart-define=LEVELPLAY_APP_KEY=YOUR_KEY
```

### With server caps API

```bash
flutter run \
  --dart-define=ADS_TEST_MODE=true \
  --dart-define=LEVELPLAY_APP_KEY=YOUR_KEY \
  --dart-define=CAP_BASE_URL=https://your.api/v1
```

`CAP_BASE_URL` is the API root (no trailing path). Client calls:

```http
GET {CAP_BASE_URL}/caps/{installId}
```

Example response:

```json
{
  "interstitial": 8,
  "rewarded": 5
}
```

Cache TTL: **5 minutes** (`lib/services/server_cap.dart`).

---

## Mock server (optional)

Expose `GET /caps/:installId` returning JSON above. Use [ngrok](https://ngrok.com/) or local Shelf if testing against desktop.

---

## Steps (physical Android)

1. Cold start without `CAP_BASE_URL` → confirm local caps only log once.
2. Cold start with `CAP_BASE_URL` pointing at mock → confirm sync log.
3. Trigger 8+ interstitials in one hour (if server limit 8) → 9th blocked when server limit applies.
4. Airplane mode after sync → cached limits used for 5min; then local fallback on sync failure.

---

## Logcat

```bash
adb logcat -c
# cold start
adb logcat -d | grep '\[ServerCap\]'
```

| Pattern | When | Pass? |
|---------|------|-------|
| `[ServerCap] CAP_BASE_URL not set — local only` | No define | ☐ |
| `[ServerCap] synced N placements from server` | GET 200, N>0 | ☐ |
| `[ServerCap] sync failed` | Network/4xx | ☐ |
| `[ServerCap] fallback` | Rare exception path | ☐ |

---

## Pass / fail criteria

| # | Criterion | Pass |
|---|-----------|------|
| 1 | No URL → single `local only` log; ads still work on local caps | ☐ |
| 2 | With URL + mock → `synced N placements` once per 5min window | ☐ |
| 3 | Server limit lower than local → server limit wins (deny earlier) | ☐ |
| 4 | GET failure does not crash app; local caps continue | ☐ |

**Task 2 result:** ☐ PASS ☐ FAIL — Tester: __________ Date: __________

---

## Code

| File | Role |
|------|------|
| `lib/services/server_cap.dart` | GET, parse, 5min cache |
| `lib/ads/server_cap_client.dart` | `ServerCapService` facade |
| `lib/services/ad_trigger_manager.dart` | `syncIfStale` on session start |

**Note:** Phase 6 POST+HMAC contract (`docs/SERVER_CAP_API.md`) is superseded by this GET model for the remediation queue.
