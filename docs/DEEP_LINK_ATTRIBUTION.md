# Deep Link & Campaign Attribution

## Supported URIs

| Pattern | Example |
|---------|---------|
| Custom scheme | `lumio://open?source=facebook&campaign=wc2026&tab=live` |
| Channel open | `lumio://channel?channel_id=sky_sports_1&source=whatsapp` |
| HTTPS landing | `https://lumio.app/open?source=telegram&utm_campaign=worldcup` |

### Query parameters

| Param | Aliases | Purpose |
|-------|---------|---------|
| `source` | `utm_source`, `src` | Acquisition source |
| `medium` | `utm_medium` | Medium |
| `campaign` | `utm_campaign`, `c` | Campaign name |
| `channel` | `channel_id`, `ch` | Open player for channel id/name |
| `tab` | — | `home`, `sports`, `live`, `news`, `categories` |

## Facebook / WhatsApp / Telegram share links

Use on landing page or post caption:

```
lumio://open?source=facebook&campaign=wc2026&tab=sports
```

For a specific channel:

```
lumio://channel?channel_id=YOUR_CHANNEL_ID&source=whatsapp&campaign=wc2026
```

## Testing (adb)

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "lumio://open?source=facebook&campaign=wc2026&tab=sports"

adb logcat -d | grep -E '\[Attribution\]|\[DeepLink\]'
```

## Analytics

First resolved link logs Firebase event `lumio_install_attribution` with UTM fields (once per install).

Stored locally in `SharedPreferences` keys `attr_utm_*` for debugging.

## Implementation files

- `lib/services/deep_link_service.dart`
- `lib/services/attribution_service.dart`
- `android/app/src/main/kotlin/com/kakonzone/lumio/MainActivity.kt` (`com.kakonzone.lumio/deeplink`)
- `android/app/src/main/AndroidManifest.xml` intent filters
