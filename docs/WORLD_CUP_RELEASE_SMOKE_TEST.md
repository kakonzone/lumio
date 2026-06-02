# World Cup Release — Device Smoke Test

Use this checklist after `./tool/build_release_apk.sh` on a physical Android phone (arm64).

## Build & install

```bash
# Required env — see docs/SECRETS.md
./tool/build_release_apk.sh

adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Verify signing is **not** debug:

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Cold start (P0)

| Step | Expected |
|------|----------|
| Launch app | Splash → consent (first run) → HOME within ~8s |
| No crash | Logcat: no `FATAL EXCEPTION` |
| Legal | Drawer → Ads & privacy → Privacy + Terms open in browser |

## Main tabs — pull to refresh + skeleton (Task 8)

| Tab | Pull down | First load skeleton |
|-----|-----------|---------------------|
| HOME | Refreshes channels | Shimmer rows if empty loading |
| SPORTS | Refreshes | Grid/list shimmer |
| LIVE | Refreshes | Channel shimmer (not spinner) |
| NEWS | Refreshes scores + news | Score + article shimmer |
| CATEGORIES | Refreshes | Grid shimmer when empty |

## Playback (World Cup critical)

| Step | Expected |
|------|----------|
| Tap sports channel | First-tap ad or immediate play |
| Player starts | Video within 15s on good network |
| Buffering | Auto failover snackbar, max 3 attempts |
| Back | Returns to list without crash |

## Ads (release keys)

| Surface | Check |
|---------|--------|
| HOME native / banner | Visible or empty (no black box) |
| Player below banner | Shows or shrinks on failure |
| Channel tap | Interstitial or direct link once |
| Exit HOME back | Exit ad then second back exits |

## Deep link attribution (Task 9)

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "lumio://open?source=facebook&campaign=wc2026&tab=sports"

adb shell am start -a android.intent.action.VIEW \
  -d "lumio://channel?channel_id=CHANNEL_ID&source=whatsapp"
```

| Check | Expected |
|-------|----------|
| Logcat | `[Attribution] source=facebook campaign=wc2026` |
| Tab routing | Sports tab selected (first example) |
| Channel routing | Player opens when channel exists |
| Firebase | Event `lumio_install_attribution` (once per install) |

## Security (Phase 9)

| Check | Command / note |
|-------|----------------|
| No creds in APK strings | `strings app-arm64-v8a-release.apk \| grep -i 'starshare.net@'` → empty |
| Release signing | Gradle fails without `key.properties` |
| Cleartext | Only audited hosts in `network_security_config.xml` |

## Crashlytics

| Step | Expected |
|------|----------|
| Force player error (airplane mode mid-play) | Non-fatal may appear in Firebase Crashlytics |
| Custom keys | `channel_id`, `stream_url_host` on player errors |

## Sign-off

- Device model: _______________
- Android version: _______________
- APK: `app-arm64-v8a-release.apk` SHA256: _______________
- Tester: _______________  Date: _______________
- Result: PASS / FAIL — notes: _______________
