# Firebase setup — Lumio (`com.kakonzone.lumio`)

## Local status

`android/app/google-services.json` is **gitignored**. If present locally, cold start should log:

```text
[Lumio] Firebase init OK
```

If missing:

```text
[Lumio] Firebase init skipped — add android/app/google-services.json
```

## Console setup (new machine / CI)

1. [Firebase Console](https://console.firebase.google.com/) → Create project (or use existing).
2. Add Android app → package name **`com.kakonzone.lumio`**.
3. Download **`google-services.json`** → `android/app/google-services.json` (never commit).
4. Release signing: add **SHA-1** and **SHA-256** from upload keystore:

```bash
keytool -list -v -keystore android/upload-keystore.jks -alias upload
```

5. Enable **Analytics** and **Remote Config** in Firebase console.

## Remote Config keys (publish defaults)

| Key | Suggested default | Purpose |
|-----|-------------------|---------|
| `ads_enabled` | `true` | Master ad kill switch |
| `levelplay_enabled` | `true` | LevelPlay init gate |
| `adsterra_enabled` | `true` | Adsterra WebView / direct gate |
| `aggressive_mode` | `false` | Denser native intervals |
| `vpn_locale_strictness` | `loose` | VPN fraud routing |
| `popunder_session_cap` | `2` | Session popunder max |

Dart constants: `lib/config/remote_config_keys.dart`.

## Device verification

After install with valid `google-services.json`:

- `[Lumio] Firebase init OK`
- Remote Config consumed before ads (`AdSafetyService.prefetchRemoteConfig` in `main.dart`)

Optional log improvement tracked as **P7-003** in `docs/PHASE7_BUGS.md` (`[RC] fetched keys=[...]` not emitted today).
