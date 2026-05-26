# Emulator / root detection enforcement audit — Phase 3 M3

**Generated:** 2026-05-25  
**Scope:** `lib/security/*`, `lib/main.dart`, network gates. **Audit only** — no behavior change unless you approve follow-ups.

---

## Enforcement matrix

| Check | Detection | Release strict? | On failure | Wired to ads? | Wired to stream/API? |
|-------|-----------|-----------------|------------|---------------|----------------------|
| Root | `su` paths, Magisk (`security_manager.dart`) | Yes (`strictModeInRelease`) | `exit(1)` | **No** | **Yes** — `assertSecureOrThrow()` |
| Emulator | Native `isEmulator` + env (`MainActivity`, Dart fallback) | Yes | `exit(1)` | **No** | **Yes** |
| Debugger | `/proc/self/status` TracerPid | Yes (release only) | `exit(1)` | **No** | **Yes** |
| Frida | maps + port 27042 | Yes | `exit(1)` | **No** | **Yes** |
| Xposed | paths + maps | Yes | `exit(1)` | **No** | **Yes** |
| VPN (security) | Stub returns true (`_checkVpn`) | N/A (`blockVpn=false`) | Pass | **No** | N/A |
| APK signature | SHA-256 vs `SecurityConfig` | If `expectedApkSignatureSha256` set | `exit(1)` | **No** | **Yes** |
| Installer | Play / package installer allowlist | If `requireKnownInstaller=true` | `exit(1)` | **No** | **Yes** |
| Proxy env | `http_proxy` / `HTTP_PROXY` | Yes | `exit(1)` | **No** | **Yes** |
| Native integrity | `lumio_security` JNI | Yes | `exit(1)` | **No** | **Yes** |
| ADB debugging | Settings.Global `ADB_ENABLED` | Release strict | `exit(1)` | **No** | **Yes** |
| Watchdog | 60s re-check | Yes | `exit(1)` | **No** | **Yes** |

---

## Startup path

```text
main() → SecurityManager.initialize()
  → performSecurityChecks() (all must pass)
  → if fail && strictModeInRelease → exit(1)
  → else watchdog Timer.periodic(60s)
```

| Build | `bypassChecksInDebug` | Effect |
|-------|----------------------|--------|
| Debug | `true` (default) | All checks skipped at startup |
| Release | N/A | Full checks; failure exits process |

**File:** `lib/main.dart` L30, `lib/security/security_config.dart` L13–16.

---

## Stream / API gate (partial enforcement)

| Entry | Call |
|-------|------|
| `lib/network/stream_resolver.dart` | `await SecurityManager.instance.assertSecureOrThrow()` |
| `lib/network/secure_dio.dart` interceptor | Same before requests |

**Not gated:** LevelPlay init, Adsterra WebView, channel list load from bundled M3U, general UI navigation.

---

## Ads / fraud layer (separate from SecurityManager)

| Signal | File | Effect |
|--------|------|--------|
| VPN confidence (H4) | `lib/services/fraud/vpn_detector.dart` | Disables Adsterra, prefers LevelPlay |
| Play Integrity | `integrity_check.dart` | Cap API header only |
| Server cap fail-closed (M2) | `server_cap.dart` | Blocks interstitial/rewarded when API down |

Emulator/root **do not** currently disable ads directly — only full app exit on startup failure.

---

## Gaps & recommendations (for your approval)

| ID | Gap | Risk | Suggested follow-up |
|----|-----|------|---------------------|
| G1 | Debug builds bypass all security | Dev fraud testing blind | Use `flutter run --release` or add `SECURITY_FORCE_CHECKS=true` define for QA |
| G2 | `expectedApkSignatureSha256` empty | Clone APK not detected | Set SHA-256 in `SecurityConfig` for production channel |
| G3 | `requireKnownInstaller=false` | Sideload allowed (intended for Lumio) | Document in store listing; optional tighten for Play |
| G4 | Security `_checkVpn` always passes | VPN only affects ads via H4 | Wire `VpnDetectionBridge` or remove dead check |
| G5 | Failed security after startup only blocks stream | Ads still load on compromised device | Optional: `AdManager.init` → `if (!SecurityManager.isSecure) return` |
| G6 | `exit(1)` on failure | Hard UX; no user message | Product choice — keep for tamper resistance |

---

## Verification commands

```bash
# Release APK on physical device (not emulator) for true enforcement
adb logcat | grep -E 'SecurityManager|Network Error'

# Emulator — expect exit in release if strict checks run
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

**REQUIRES DEVICE TEST** — emulator detection and root paths cannot be fully validated from CI alone.

---

## Verdict

| Area | Status |
|------|--------|
| Root / emulator **detection** | **Implemented** |
| Release **enforcement** at startup | **Implemented** (exit) |
| Ongoing **stream/API** enforcement | **Implemented** |
| **Ads** tied to root/emulator | **Not implemented** (by design today) |
| Audit complete | **PASS** — gaps documented as G1–G6 |
