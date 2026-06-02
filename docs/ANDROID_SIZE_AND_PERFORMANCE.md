# Android APK size & performance

## Default ship mode (2026-06-02)

| Item | Value |
|------|--------|
| Script | `./tool/build_release_apk.sh` |
| Mode | **`BUILD_APK_MODE=split`** (default) |
| Output | **Two APKs** — install only one per phone |

| APK | CPU | Typical download |
|-----|-----|------------------|
| `app-arm64-v8a-release.apk` | 64-bit (most phones) | **~22–40 MB** |
| `app-armeabi-v7a-release.apk` | 32-bit (older phones) | **~22–40 MB** |

```bash
./tool/build_release_apk.sh
# 64-bit:
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# 32-bit:
adb install -r build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
```

Same `secrets.json` as dev (`--dart-define-from-file`). Build fails if ad keys are still template/`example.com`.

## Optional modes

| Mode | Command | Use case |
|------|---------|----------|
| **split** (default) | `./tool/build_release_apk.sh` | Smallest per-device download (recommended sideload) |
| **fat** | `BUILD_APK_MODE=fat ./tool/build_release_apk.sh` | One APK, both ABIs — **~45–55 MB** |
| **arm64 only** | `BUILD_APK_MODE=arm64 ./tool/build_release_apk.sh` | Smallest single file for 64-bit-only audience |
| **universal 32** | `BUILD_APK_MODE=universal ./tool/build_release_apk.sh` | 32-bit compat single APK |

## Installed storage target

| Part | Size |
|------|------|
| Installed APK (one ABI) | ~22–40 MB download → similar code size |
| App **data** (cache, WebView, images) | **≤ ~22 MB** ([AppStorageGuard]) |
| **Total in Settings** | **~60–80 MB** typical |

`PerformanceTuning` + `AppStorageGuard` trim cache on startup, resume, and every 6 hours.

## Android version

- **minSdk 21** — Android 5.0 Lollipop+
- ARM only (no x86 APK)

## Size tips

- `FIREBASE_ENABLED=false` in `secrets.json` — saves ~3–5 MB
- Prefer **split** over **fat** for WhatsApp/Drive shares
- Do not install the wrong ABI APK (arm64 on 32-only device fails)

## Verify on device

```bash
adb shell dumpsys package com.kakonzone.lumio | grep -E 'codeSize|dataSize'
```

See also: [`AUDIT_REPORT.md`](../AUDIT_REPORT.md) **Section 24–25**, [`BUILD.md`](BUILD.md), [`SIDELOAD_INSTALL.md`](SIDELOAD_INSTALL.md).
