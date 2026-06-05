# World Cup 2026 cards — Appwrite daily update

Home → **World Cup 2026** section reads one row from Appwrite (not the channel catalog).

## Console setup

1. Database: `iptv_main` (or your `APPWRITE_DATABASE_ID`)
2. Collection: `app_config` (or `APPWRITE_APP_CONFIG_COLLECTION_ID`)
3. **Permissions → Read → Guests (any)** — same as `channels`
4. Create or edit a document:

| Field | Value |
|--------|--------|
| `key` | `featured_live_events` |
| `json_payload` | JSON below (string or object attribute) |
| `updated_at` | optional; Appwrite updates on save — app uses this to detect daily edits |

You can also set document **ID** = `featured_live_events` if you do not use a `key` field.

## JSON shape (`json_payload`)

```json
{
  "sectionTitle": "World Cup 2026",
  "sectionSubtitle": "Tap a match — pick your channel link",
  "maxCards": 3,
  "events": [
    {
      "id": "wc26-match-1",
      "sport": "football",
      "tournament": "FIFA World Cup 2026 — Final",
      "teamA": "Brazil",
      "teamB": "Argentina",
      "status": "live",
      "scoreA": "1",
      "scoreB": "0",
      "time": "21:00 BDT",
      "matchDate": "2026-07-19T18:00:00.000Z",
      "channels": [
        {
          "name": "T Sports HD",
          "url": "https://your-cdn.example/live.m3u8"
        },
        {
          "name": "Backup",
          "url": "https://backup.example/stream.m3u8",
          "alternateStreams": [
            { "url": "https://hd.example/stream.m3u8", "label": "HD" }
          ]
        }
      ]
    }
  ]
}
```

### Channel URL fields (any one works)

- `url` (preferred)
- `streamUrl` / `stream_url`
- `link` / `m3u8`

Each channel must have a non-empty URL or it is skipped.

## How the app refreshes

1. On open / home load: fetches `app_config` once and compares `updated_at` to local cache.
2. If you changed the row in Console, the app reloads links automatically (no reinstall).
3. **Pull to refresh** on Home clears cache and forces Appwrite fetch.

## Verify on device

After `flutter run`, open Home and check logcat:

```text
[FeaturedLiveEvents] source=appwrite events=3 channelLinks=6 updated_at=...
```

Under the section title you should see:

`Appwrite · N channel links · updated …`

If you see orange error text: add **Guests Read** on `app_config` or fix `json_payload`.

Release/sideload builds do **not** use bundled `assets/data/featured_live_events.json` when Appwrite is configured — only Appwrite + cache.
