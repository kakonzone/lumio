# Server cap API — Lumio client contract

**Active client:** `lib/services/server_cap.dart` (facade: `lib/ads/server_cap_client.dart` → `ServerCapService`).

## Configuration (build-time)

```bash
flutter build apk --release \
  --dart-define=CAP_BASE_URL=https://api.example.com \
  --dart-define=CAP_HMAC_KEY=your_shared_secret
```

| Variable | Required | Usage |
|----------|----------|--------|
| `CAP_BASE_URL` | **Yes in release** | Base URL for GET sync (no trailing path required) |
| `CAP_HMAC_KEY` | Build script | Reserved for legacy POST; **not sent on active GET** |

### Release behavior

- If `CAP_BASE_URL` is empty in a **release** build: log  
  `[ServerCap] ERROR CAP_BASE_URL unset in release — ads disabled`  
  and `AdManager.adsEnabled` is **false** (`ServerCap.blocksAdsInRelease`).
- Debug/profile without URL: local `AdTriggerManager` caps only.

### Fail-closed (M2)

When `CAP_BASE_URL` is set and GET sync fails (timeout, non-200, invalid JSON, missing `installId`), `ServerCap` sets **fail-closed** and `allowsPlacement` returns **`false`** until the next successful sync.

---

## Active request — GET caps

**Endpoint:** `GET {CAP_BASE_URL}/caps/{installId}`  
**Headers:**

| Header | Value |
|--------|--------|
| `Accept` | `application/json` |

**v1.0 (Option B):** `X-Integrity-Token` is **not sent**. Server must use **install-ID dedup** and **HMAC** on POST paths (see legacy section). Play Integrity returns in v1.1 — `docs/PLAY_INTEGRITY_OPTION_B.md`.

**No HMAC** on the active GET path.

### Response (200)

```json
{
  "interstitial": 8,
  "rewarded": 5
}
```

Or wrapped:

```json
{
  "caps": {
    "interstitial": 8,
    "rewarded": 5
  }
}
```

Client caches 5 minutes (`ServerCap._cacheTtl`). Hourly usage is compared locally per placement.

---

## Legacy POST + HMAC (Phase 6 — not wired in app)

`POST` `{CAP_BASE_URL}` (full URL as single dart-define in old docs)  
`Content-Type: application/json`  
**`X-Cap-Signature`:** lowercase hex `HMAC-SHA256(UTF8(CAP_HMAC_KEY), raw JSON body bytes)`

```json
{
  "installId": "uuid",
  "fingerprint": "64-char-sha256-hex",
  "placement": "interstitial",
  "timestampMs": 1716566400123,
  "integrityToken": "optional"
}
```

### Legacy response (200)

```json
{
  "allow": true,
  "remaining": 3,
  "resetAtMs": 1716569999999,
  "reason": "ok"
}
```

---

## Status

**READY_FOR_DEVICE_TEST** — live GET endpoint required for release caps.
