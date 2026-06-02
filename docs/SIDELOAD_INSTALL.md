# Sideload install (no Play Store)

## Build APK

```bash
./tool/build_size_apk.sh
```

Output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~35–40MB on arm64 phones).

For older 32-bit devices, also build:

```bash
flutter build apk --release --split-per-abi --target-platform=android-arm \
  --tree-shake-icons --obfuscate --split-debug-info=build/debug-info \
  --android-project-arg=LUMIO_LOCAL_SIZE_CHECK=true
```

## Install on phone

1. Copy `app-arm64-v8a-release.apk` to the device (USB, Telegram, Drive, etc.).
2. Settings → Security → allow install from unknown sources (or per-app for Files/Telegram).
3. Open the APK and install.

## Signing (recommended before wide rollout)

`build_size_apk.sh` without `android/key.properties` uses a **debug-signed** release (fine for your own tests).

Before sharing with many users:

1. Create a release keystore (`docs/RELEASE_SIGNING.md`).
2. Add `android/key.properties`.
3. Re-run `./tool/build_size_apk.sh` — same size, proper signing; future updates install over the old app.

## Install size on device

Expect ~**55–75MB** app storage after install (native video + ads SDKs), plus small image cache.
