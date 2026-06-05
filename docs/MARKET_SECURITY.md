# Market launch security checklist

## Before Play Store upload

1. **Appwrite** — Delete any leaked API keys in Console; use **Guests Read** only (see `docs/SECRETS.md`).
2. **Release keystore** — Set `expectedApkSignatureSha256` in `lib/security/security_config.dart` from:
   `keytool -list -v -keystore your-release.jks -alias your_alias`
3. **TLS pins** — Set `SSL_PIN_*` dart-defines in `secrets.json` for stream-token API and ad hosts.
4. **Play installer** — For production: build with  
   `--dart-define=SECURITY_REQUIRE_PLAY_INSTALLER=true`  
   (blocks sideload / unknown installers; do **not** use with `LUMIO_SIDELOAD_DEV=true`).
5. **Never ship** `LUMIO_SIDELOAD_DEV=true` or debug `ADS_ENABLED` in release.
6. **Conflicting-app gate** — Release builds enforce `SecurityConfig.blockConflictingApps` (HttpCanary, Magisk, etc.). Do **not** ship with `bypassChecksInDebug` expectations in release.

## What the app already checks

- Root / emulator / debugger / Frida / Xposed heuristics (`SecurityManager`)
- Native JNI anti-tamper — ptrace + Frida in `/proc/self/maps` (`liblumio_security.so`)
- **Blocked conflicting apps** — 17-package scan at startup + on resume (`BlockedAppDetector.kt`, `BlockedAppsGuard`)
- Optional APK signature match
- Optional known installer (Play)
- TLS pinning on gated APIs (`SecureDio`)
- No Appwrite API key in the client

## Play Integrity (v1.1 — not in v1.0)

- **Client:** Option B — attestation disabled; see `docs/PLAY_INTEGRITY_OPTION_B.md`
- **Server:** Decode on **cap/stream backend** (`CAP_BASE_URL`), not Appwrite catalog — see `docs/PLAY_INTEGRITY_SERVER.md`
- **Appwrite:** Catalog only; do not store Google service-account secrets in Guests-read paths

## Known limits (document for reviewers)

- IPTV streams use many HTTP/cleartext hosts (`network_security_config.xml`) — industry norm for M3U; MITM risk on stream URLs.
- Appwrite catalog is public-read by design (project ID in app).
- GITUN playlists load from third-party GitHub URLs.
- Blocked-app gate is client-side — bypassable by skilled attackers; server attestation required for strong stream protection.
