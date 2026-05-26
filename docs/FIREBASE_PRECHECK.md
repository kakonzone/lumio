# Firebase precheck — before TASK 0.2 device verify

**Package:** `com.kakonzone.lumio`  
**Date:** 2026-05-26 (Phase 8)

**Automated script:** `./scripts/firebase_precheck.sh` (also run from `./scripts/preflight_release.sh`).

---

## Quick checklist

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | `android/app/google-services.json` exists | ✅ | On disk, **untracked** |
| 2 | `package_name` = `com.kakonzone.lumio` | ✅ | JSON line 13 |
| 3 | Debug SHA-1 in Firebase Console | ⚠️ | **You** must paste — see below |
| 4 | `google-services.json` in `.gitignore` | ✅ | Added — do not `git add` this file |
| 5 | Remote Config params in Console | ⚠️ | **You** must create + **Publish** — table below |

---

## Debug SHA-1 (paste in Firebase Console)

**Path:** Firebase Console → Project Settings → Your apps → Android (`com.kakonzone.lumio`) → Add fingerprint

```
F3:71:6C:D4:A1:93:86:94:4E:0E:89:31:A5:FB:38:FB:19:53:21:7F
```

**Terminal (same value):**

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1
# or: cd android && ./gradlew signingReport  → Variant: debug
```

Also add **release** SHA-1/SHA-256 from your upload keystore before Play Store builds.

---

## Remote Config — must match **code** (`remote_config_keys.dart`)

> ⚠️ Checklist said default `"soft"` — **code uses `loose`**, not `soft`.  
> Valid values for `vpn_locale_strictness`: `off` | `loose` | `strict`

| Parameter | Type | Default (in-app if RC missing) | Console action |
|-----------|------|--------------------------------|----------------|
| `ads_enabled` | Boolean | `true` | Create + Publish |
| `levelplay_enabled` | Boolean | `true` | Create + Publish |
| `adsterra_enabled` | Boolean | `true` | Create + Publish |
| `vpn_locale_strictness` | String | **`loose`** | Create + Publish |

**Optional (already in code defaults, not in your 4-item list):**

| Parameter | Type | Default |
|-----------|------|---------|
| `popunder_session_cap` | Number | `2` |
| `aggressive_mode` | Boolean | `false` |

---

## Code wiring (TASK 0.2 — static verify)

| Requirement | Location |
|-------------|----------|
| Google Services plugin | `android/app/build.gradle.kts` — applied if `google-services.json` exists |
| `Firebase.initializeApp()` before ads | `main.dart` → `FirebaseBootstrap.initialize()` then `prefetchRemoteConfig()` before `runApp`; `AdManager.init()` from splash only |
| RC `fetchAndActivate` | `ad_safety_service.dart` — 12h release / 0 debug |
| Kill switches | `AdManager` reads `ads_enabled`; `ironsource_service` → `levelplay_enabled`; Adsterra paths → `adsterra_enabled` |

---

## After Console setup

1. Confirm SHA-1 saved in Firebase (no screenshot needed — tick mentally).
2. Remote Config → **Publish** (not just Save draft).
3. Run device test: `docs/DEVICE_TEST_TASK_1.md` or `flutter run` and grep `[Lumio]`, `[RemoteConfig]`.

**Gated:** Do not start TASK 0.3 (dart-define release build) until you confirm rows 3 and 5 above.
