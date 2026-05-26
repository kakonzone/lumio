# Merged manifest audit (Task 1.5)

**Source:** `android/app/src/main/AndroidManifest.xml`  
**Verify locally:** `cd android && ./gradlew app:processReleaseManifest`  
**Merged output:** `android/app/build/intermediates/merged_manifest/release/processReleaseManifest/AndroidManifest.xml`

## `<uses-permission>` (app-declared)

```xml
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="com.google.android.gms.permission.AD_ID" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

**Not declared (good):** `READ_PHONE_STATE`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`.

| Permission | Justification |
|------------|----------------|
| `INTERNET` / `ACCESS_NETWORK_STATE` / `ACCESS_WIFI_STATE` | Streaming + mediation network class |
| `AD_ID` | Mediation / Play services (user can limit in system settings) |
| `POST_NOTIFICATIONS` | FCM / local notifications |
| `FOREGROUND_SERVICE*` / `WAKE_LOCK` | `audio_service` background playback |

## `<application>` (opening)

```xml
<application
    android:label="Lumio"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    android:allowBackup="false"
    android:fullBackupContent="false"
    android:usesCleartextTraffic="false"
    android:networkSecurityConfig="@xml/network_security_config">
```

- **Global cleartext:** OFF (`usesCleartextTraffic="false"`).
- **HTTP streams:** allowlisted per-domain in `res/xml/network_security_config.xml` (IPTV hosts only), not global.

## IronSource / LevelPlay AAR

After `processReleaseManifest`, confirm merged file does **not** add:

- `android:usesCleartextTraffic="true"` on `<application>`
- `READ_PHONE_STATE` or location permissions

If the AAR adds them, add `tools:node="remove"` entries in `AndroidManifest.xml`.

## Status

**PASS (source review)** — Re-run merged manifest diff after each mediation SDK bump.
