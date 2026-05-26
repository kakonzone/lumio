# Play Integrity — Phase 2 H1 (client + server contract)

> **v1.0 ships Option B:** client attestation is **disabled**. See `docs/PLAY_INTEGRITY_OPTION_B.md`. This doc applies when re-adding Option A.

Planned client (v1.1): `integrity_check.dart`, `PlayIntegrityBridge.kt`, channel `com.kakonzone.lumio/integrity`.

## Android setup

1. Play Console → **App integrity** → link a Google Cloud project.
2. Note the **numeric** Cloud project number (not project ID string).
3. Release build:

```bash
flutter build apk --release \
  --dart-define=CAP_BASE_URL=https://your-api.example.com/v1 \
  --dart-define=PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER=123456789012
```

4. Dependency: `com.google.android.play:integrity:1.4.0` in `android/app/build.gradle.kts`.

**v1.0:** No integrity header is sent (Option B). **v1.1:** Without `PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER`, do not send stub tokens — omit header until Play API is configured.

## Client flow

1. `AdSafetyService.ensureReady()` → `IntegrityAttestationService.refreshOnColdStart(installId: …)`.
2. Nonce: `IntegrityCheck.buildCapNonce(installId)` (URL-safe base64, bound to install + timestamp).
3. Native `requestIntegrityToken` → JWT returned to Dart.
4. First `ServerCap` GET includes header **`X-Integrity-Token`** (one-shot via `consumeTokenForCapCheck()`).

## Server verification (stub — implement on your backend)

Use the [Play Integrity server API](https://developer.android.com/google/play/integrity/verdict): decode the token and evaluate `deviceIntegrity`, `appIntegrity`, and `accountDetails`.

### Example: Cloud Function (Node.js sketch)

```javascript
// POST /v1/integrity/decode  { "integrityToken": "<from X-Integrity-Token>" }
const { google } = require('googleapis');

exports.decodeIntegrityToken = async (req, res) => {
  const token = req.body?.integrityToken;
  if (!token || token.startsWith('stub:')) {
    return res.status(200).json({ verdict: 'stub', allowCap: true });
  }
  const playintegrity = google.playintegrity('v1');
  const packageName = 'com.kakonzone.lumio';
  const response = await playintegrity.v1.decodeIntegrityToken({
    packageName,
    requestBody: { integrityToken: token },
  });
  const payload = response.data.tokenPayloadExternal;
  const meetsDevice =
    payload?.deviceIntegrity?.deviceRecognitionVerdict?.includes(
      'MEETS_DEVICE_INTEGRITY',
    );
  const meetsApp =
    payload?.appIntegrity?.appRecognitionVerdict === 'PLAY_RECOGNIZED';
  return res.status(200).json({
    verdict: 'play',
    meetsDevice,
    meetsApp,
    allowCap: Boolean(meetsDevice && meetsApp),
  });
};
```

Enable **Play Integrity API** on the same GCP project and grant the service account **Play Integrity API** access in Play Console.

### Cap API integration

On first `GET /caps/{installId}` with `X-Integrity-Token`:

| Token prefix | Suggested policy |
|--------------|------------------|
| `stub:` | Dev / missing Play config — log and allow or rate-limit |
| (JWT from Play) | Decode; deny cap sync if `allowCap` is false |

Store the nonce server-side if you need replay protection (compare to nonce embedded in decoded payload).

## Troubleshooting

| Symptom | Likely cause |
|---------|----------------|
| Always `stub:` in logs | Project number unset, emulator without Play Store, or API failure |
| `INTEGRITY_REQUEST_FAILED` | App not from Play, wrong package name, or project not linked |
| Empty `X-Integrity-Token` | `CAP_BASE_URL` unset or token already consumed |

## Tests

```bash
flutter test test/services/integrity_check_test.dart
flutter test test/services/integrity_attestation_service_test.dart
```
