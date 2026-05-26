# B5 — Cleartext traffic hardening

## Configuration

| File | Setting |
|------|---------|
| `AndroidManifest.xml` | `android:usesCleartextTraffic="false"` |
| `res/xml/network_security_config.xml` | Default **deny** cleartext; explicit allowlists |

### Monetization (HTTPS only)

Domains in the `cleartextTrafficPermitted="false"` block include Firebase, Google Analytics, IronSource / LevelPlay (`ironsource.mobi`, `supersonicads.com`, `isprog.com`), AppLovin (`applovin.com`, `applvn.com`), and Adsterra partner HTTPS hosts.

Ad SDK traffic should use HTTPS. Cleartext to these hosts is not required.

### IPTV streams (HTTP allowlist)

Many playlist URLs are `http://` IP or legacy CDN hosts. A separate `cleartextTrafficPermitted="true"` domain-config lists curated stream hosts extracted from `assets/data/user_playlist.m3u` and bundled channel sources.

**New HTTP stream host?** Add the hostname to `network_security_config.xml` (stream section) or regenerate via:

```bash
python3 tool/gen_network_security_config.py
```

(if script added later)

## Verify cleartext blocked (unknown host)

Install release/debug APK on device/emulator, then:

```bash
# Should fail or return non-200 (connection refused / cleartext not permitted)
adb shell am start -a android.intent.action.VIEW -d "http://never.ssl.example.test/"

# Confirm app manifest
adb shell dumpsys package com.kakonzone.lumio | grep -i cleartext
```

Expected: global cleartext off; `http://198.195.239.50:8095/...` works only if that IP/host is in the stream allowlist.

## Verify monetization still loads

```bash
adb logcat | grep -E '\[LevelPlay\] init success|\[AdAnalytics\]'
```

With `LEVELPLAY_APP_KEY` set, LevelPlay init should succeed over HTTPS.

## curl (host machine)

```bash
# HTTPS ad endpoint — should work
curl -sI "https://firebase.googleapis.com" | head -1

# Random HTTP — no Lumio allowlist
curl -sI "http://cleartext-block-test.invalid.example" | head -1
```
