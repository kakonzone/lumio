# LevelPlay version skew report — Phase 2 H3

**Generated:** 2026-05-25  
**Status:** PASS (no bump recommended) — awaiting your approval before any version change.

Per audit H3: compare Flutter plugin pin, pub.dev latest, and native Android SDK actually resolved by Gradle.

---

## 1. Flutter plugin (`unity_levelplay_mediation`)

| Source | Version | Notes |
|--------|---------|--------|
| `pubspec.yaml` | **9.2.0** (exact pin, no `^`) | Project policy: exact versions |
| `pubspec.lock` | **9.2.0** | Resolved `sha256:686432b7…` |
| [pub.dev](https://pub.dev/packages/unity_levelplay_mediation) | **9.2.0** (latest) | Published ~35 days before report date |
| Skew vs pub.dev | **None** | Already on latest stable |

**Recommendation:** Keep **`unity_levelplay_mediation: 9.2.0`**. Re-check pub.dev before next release train; bump only when a newer stable is published and changelog is reviewed.

---

## 2. Native Android SDK (bundled by plugin)

| Source | Version | How it is pulled |
|--------|---------|------------------|
| Plugin `CHANGELOG.md` | Wraps Android SDK **9.4.0** | Authoritative for this Flutter release |
| Plugin `android/build.gradle` | `api 'com.unity3d.ads-mediation:mediation-sdk:9.4.0'` | Transitive via Flutter plugin |
| Plugin `lib/src/utils/levelplay_constants.dart` | `ANDROID_SDK_VERSION = '9.4.0'` | Runtime `LevelPlay.getSdkVersion()` on Android |
| Lumio `android/build.gradle.kts` (root) | **No manual IronSource/LevelPlay version** | Correct — do not duplicate pin |
| Lumio `android/app/build.gradle.kts` | GMS deps only (`play-services-appset`, `ads-identifier`, `basement`) | Matches [pub.dev Android setup](https://pub.dev/packages/unity_levelplay_mediation) |

**Skew Flutter ↔ native:** **Expected** — Flutter **9.2.0** packages native **9.4.0** (documented in `LEVELPLAY_SDK_VERIFICATION.md`).

**Recommendation:** Do **not** add a separate `mediation-sdk` line in app `build.gradle.kts` unless Unity docs require a hotfix adapter override; that risks fighting the plugin’s tested matrix.

---

## 3. Native iOS SDK (reference)

| Source | Version |
|--------|---------|
| Plugin `ios/unity_levelplay_mediation.podspec` | `IronSourceSDK` **9.4.0.0** |

Lumio primary target is Android; iOS pin follows plugin when you ship iOS.

---

## 4. Related dependencies (not LevelPlay, but ad-adjacent)

| Package | `pubspec.yaml` | Role |
|---------|----------------|------|
| `webview_flutter` | 4.13.1 (pinned) | Adsterra WebView |
| `firebase_remote_config` | (see `pubspec.yaml`) | `adsterra_enabled`, caps |
| `http` | cap + telemetry GET/POST | |

No skew action required for H3 scope.

---

## 5. Verification performed

```bash
# Flutter pin
grep unity_levelplay_mediation pubspec.yaml pubspec.lock

# Plugin native pin (local pub-cache)
grep mediation-sdk ~/.pub-cache/hosted/pub.dev/unity_levelplay_mediation-9.2.0/android/build.gradle

# App must NOT override mediation-sdk (should be empty)
grep -i 'mediation-sdk\|ironsource' android/app/build.gradle.kts android/build.gradle.kts || true
```

**Gradle assembleRelease dry-run:** Not re-run here (project mount permissions in agent env). Run locally after any future bump:

```bash
cd android && ./gradlew :app:assembleRelease --dry-run
```

---

## 6. If you approve a bump later

Checklist (do not execute until you say so):

1. Read [unity_levelplay_mediation changelog](https://pub.dev/packages/unity_levelplay_mediation/changelog) for breaking API changes.
2. Update **exact** pin in `pubspec.yaml` → `flutter pub get` → commit `pubspec.lock`.
3. Re-run `docs/LEVELPLAY_SDK_VERIFICATION.md` table against new `.pub-cache` sources.
4. `flutter test test/ads/` + device smoke: init, interstitial, rewarded, banner, consent.
5. Confirm native SDK version via log: `LevelPlay.getSdkVersion()` or plugin constant.

---

## 7. Task H3 verdict

| Check | Result |
|-------|--------|
| Identify Flutter plugin version | **9.2.0** |
| Compare pub.dev latest | **Aligned** |
| Compare Android native pin | **9.4.0 via plugin** (not in app Gradle) |
| Recommended pins | **No change** |
| Bump applied? | **No** — per audit: wait for approval |

**Next task in audit order:** H4 (VPN detection hardening) unless you direct otherwise.
