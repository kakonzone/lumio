# Play Integrity — Option B (v1.0 ship decision)

**Status:** **IMPLEMENTED** (TASK 0.4)  
**Decision:** **Option B — no client attestation** for v1.0. Server relies on **HMAC + install-ID dedup** only.  
**v1.1:** Re-enable **Option A** (real tokens + server decode) when prerequisites below are met.

---

## Why Option B

- Stub tokens (`stub:<timestamp>`) look like real attestations and invite false server trust.
- Real Play Integrity needs GCP project number, Play Console API, native bridge, Dart facade, and a server decode endpoint — not owned end-to-end for v1.0.
- Until then, **do not send** `X-Integrity-Token` on cap sync.

---

## What shipped (v1.0)

| Area | Action |
|------|--------|
| `lib/services/integrity_attestation_service.dart` | **Deleted** |
| `lib/services/fraud/integrity_check.dart` | **Deleted** (restore in v1.1 Option A) |
| `lib/services/ad_safety_service.dart` | No cold-start attestation; omission comment at `ensureReady` |
| `lib/services/server_cap.dart` | No `X-Integrity-Token`; omission comment on GET headers |
| `android/.../PlayIntegrityBridge.kt` | **Deleted**; integrity `MethodChannel` removed from `MainActivity` |
| `com.google.android.play:integrity` | Removed from `android/app/build.gradle.kts` |
| Docs | `SECRETS.md`, `SERVER_CAP_API.md`, `TELEMETRY_SPLIT.md`, `PRODUCTION_READINESS.md` |

Client markers at removal sites:

```dart
// INTENTIONALLY OMITTED: Play Integrity disabled, server must rely on HMAC + install-ID dedup
```

---

## Server contract (v1.0)

- Cap **GET** `/{CAP_BASE_URL}/caps/{installId}` — `Accept: application/json` only (no integrity header).
- **POST + HMAC** (legacy / server-side): `X-Cap-Signature: hex(hmac_sha256(CAP_HMAC_KEY, body))` with stable `installId` from `AdSafetyService`.
- Rate limits + fail-closed when `CAP_BASE_URL` is set but sync fails (`ServerCap`).

---

## Verification

```bash
grep -rn 'IntegrityAttestation\|stub:' lib/
# Expect zero matches (comments only if any)
```

```bash
flutter test test/services/integrity_attestation_service_test.dart test/services/integrity_check_test.dart 2>&1 || true
# Expect: file not found (tests removed with Option B)
flutter analyze --no-fatal-infos lib/services/ lib/ads/ lib/network/
```

---

## v1.1 Option A checklist (do not start until all true)

| # | Prerequisite | Owner |
|---|--------------|--------|
| 1 | GCP **project number** for Play Integrity API (Play Console → App integrity) | Mobile + backend |
| 2 | `PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER` in release build (`docs/SECRETS.md`) | Release |
| 3 | Restore `PlayIntegrityBridge.kt` + `com.google.android.play:integrity` + `com.kakonzone.lumio/integrity` channel | Android |
| 4 | Restore `lib/services/fraud/integrity_check.dart` + `IntegrityAttestationService` (no `stub:` ever) | Flutter |
| 5 | Server **decode** endpoint calling `playintegrity.googleapis.com` (verify nonce + package + cert) | Backend |
| 6 | Update `docs/SERVER_CAP_API.md` — `X-Integrity-Token` required on first cap GET per cold start | Docs |
| 7 | Device test: physical Play Store build, log first GET has non-empty JWT header | QA |

Reference implementation guide (future): `docs/PLAY_INTEGRITY_SERVER.md`.
