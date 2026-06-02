# Release Signing (Fail-Closed)

Lumio release builds are **hard-fail** if signing is not configured.

If signing is missing, Gradle aborts with:

`RELEASE BUILD ABORTED: key.properties missing or storeFile null. See docs/RELEASE_SIGNING.md`

## 1) Generate a release keystore (local secure machine)

```bash
keytool -genkeypair \
  -v \
  -keystore /secure/path/lumio-release.jks \
  -alias lumio_release \
  -keyalg RSA \
  -keysize 2048 \
  -validity 3650
```

## 2) Create `android/key.properties` from template

Copy `android/key.properties.example` to `android/key.properties` and fill:

- `storeFile`
- `storePassword`
- `keyAlias`
- `keyPassword`

Example:

```properties
storeFile=/secure/path/lumio-release.jks
storePassword=...
keyAlias=lumio_release
keyPassword=...
```

## 3) Never commit signing material

Keep these out of git:

- `android/key.properties`
- `*.jks`
- `*.keystore`

## 4) CI/CD injection notes

- Do **not** commit keystore or key file into repo.
- Provide `key.properties` at build time from secret storage.
- Mount keystore on CI runner and set `storeFile` to that path.
- Build command example:

```bash
flutter build apk --release --dart-define-from-file=secrets.json
```

## 5) Verification

- `flutter build apk --release` with missing/invalid signing must fail fast.
- `flutter build apk --debug` must still work.
