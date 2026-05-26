# Release signing (Lumio Android)

Production release builds must be signed with a dedicated upload keystore — not the debug keystore.

## 1. Generate a keystore (one-time)

From the repository root:

```bash
keytool -genkey -v \
  -keystore android/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload \
  -storetype JKS
```

You will be prompted for store password, key password (can match store), and certificate fields.

**Keep `android/upload-keystore.jks` and passwords offline.** Both `*.jks` and `key.properties` are gitignored.

## 2. Configure credentials (pick one)

### Option A — `android/key.properties` (local dev)

```bash
cp android/key.properties.template android/key.properties
# Edit android/key.properties with real passwords and storeFile path.
```

Example `android/key.properties`:

```properties
storeFile=upload-keystore.jks
storePassword=<redacted>
keyAlias=upload
keyPassword=<redacted>
```

### Option B — Environment variables (CI)

| Variable | Maps to |
|----------|---------|
| `RELEASE_STORE_FILE` | Path to `.jks` (relative to `android/` or absolute) |
| `RELEASE_STORE_PASSWORD` | Keystore password |
| `RELEASE_KEY_ALIAS` | Key alias (default: `upload`) |
| `RELEASE_KEY_PASSWORD` | Key password |

### Option C — `--dart-define` (Flutter → Gradle)

Same names as env vars, passed on the build command:

```bash
flutter build apk --release \
  --dart-define=RELEASE_STORE_FILE=upload-keystore.jks \
  --dart-define=RELEASE_STORE_PASSWORD='***' \
  --dart-define=RELEASE_KEY_ALIAS=upload \
  --dart-define=RELEASE_KEY_PASSWORD='***'
```

Resolution order per field: `android/key.properties` → environment variable → `--dart-define`.

## 3. Verify Gradle wiring

After `android/app/build.gradle.kts` B1 patch is applied:

```bash
cd android && ./gradlew :app:signingReport
```

Release variant should list your upload certificate, not `Android Debug`.

## 4. Build signed release APK

```bash
flutter build apk --release --split-per-abi
```

Inspect:

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
sha256sum build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## 5. Play App Signing

For Google Play, use **Play App Signing** and upload the **upload key** certificate. Retain the keystore backup; loss blocks future updates.
