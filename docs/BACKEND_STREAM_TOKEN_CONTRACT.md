# Stream token API contract

Lumio clients call this endpoint for protected catalog URLs (e.g. `starshare.net`).

## Endpoint

`POST {STREAM_TOKEN_BASE_URL}`

If `STREAM_TOKEN_BASE_URL` is the API root (recommended):

`https://api.lumio.app` → client posts to `https://api.lumio.app/v1/stream-token`

If the define already includes the path, that URL is used as-is.

## Request

```json
{
  "channelId": "geo_sport_ptv",
  "channel_id": "geo_sport_ptv",
  "source_url": "http://starshare.net/live/...",
  "installId": "uuid-v4-install-id",
  "fingerprint": "sha256-device-fingerprint"
}
```

## Response `200`

```json
{
  "token": "short-lived-jwt-or-nonce",
  "expiresIn": 3600,
  "streamUrl": "https://cdn.example.com/stream/index.m3u8?token=..."
}
```

Legacy field `url` is also accepted as `streamUrl`.

## Errors

| Status | Client behavior |
|--------|-----------------|
| 401 / 403 | No signed URL; protected channel shows “Channel temporarily unavailable” |
| 5xx / timeout | Same; Crashlytics optional event |

## Caching

Client caches per `channelId` for `expiresIn - 30` seconds.

## Security

- HTTPS only
- TLS pins: `SSL_PIN_STREAM_TOKEN_*` or `SSL_PIN_PRIMARY` / `SSL_PIN_BACKUP`
- Rate-limit by `installId` + `fingerprint`
