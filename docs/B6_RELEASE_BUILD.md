# B6 — Release APK build checklist

Run on a machine with write access to the project tree (not read-only mounts).

## Prerequisites

```bash
cp android/key.properties.template android/key.properties
# Fill storeFile, storePassword, keyAlias, keyPassword

keytool -genkey -v -keystore android/upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000

export LEVELPLAY_APP_KEY='your_key'
export LEVELPLAY_INTERSTITIAL_AD_UNIT='your_unit'
export LEVELPLAY_REWARDED_AD_UNIT='your_unit'
export LEVELPLAY_BANNER_AD_UNIT='your_unit'
```

## Build

```bash
cd /path/to/lumio
flutter pub get
./tool/build_release_apk.sh
# or:
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info
```

## Verify signing (production, not debug)

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# Must NOT show "Android Debug" OU

sha256sum build/app/outputs/flutter-apk/app-*-release.apk
```

## Verify cleartext + secrets

```bash
# Source — no hardcoded LevelPlay key
rg '2675bcc95|gnf3o8|d98ffaab' android/app/src lib/config

# strings.xml placeholder empty
cat android/app/src/main/res/values/strings.xml

# Merged manifest (after build)
aapt dump xmltree app-arm64-v8a-release.apk AndroidManifest.xml | grep cleartext
# Expect usesCleartextTraffic=false at application level
```

## Gradle dry-run

```bash
cd android && ./gradlew :app:assembleRelease --dry-run
```
