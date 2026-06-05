# Play Integrity v2 migration plan

**Status:** v1.1 client Option B (no attestation token) ships for sideload / sub-25k DAU.  
**Trigger:** Operational alert at **20k DAU**; full v2 rollout target **25k DAU**.

## Current (v1.1 / Option B)

| Layer | Behavior |
|-------|----------|
| Client | No `X-Integrity-Token`; `PlayIntegrityService` returns null |
| Server cap/stream | HMAC + `installId` dedup only (`docs/PLAY_INTEGRITY_OPTION_B.md`) |
| Local | `SecurityManager`, blocked-app gate, optional APK signature |

## Verdict fields (v1 server decode — when enabled)

From Google Play Integrity API `tokenPayloadExternal`:

| Field | Use |
|-------|-----|
| `deviceIntegrity.deviceRecognitionVerdict` | Require `MEETS_DEVICE_INTEGRITY` or stronger |
| `appIntegrity.appRecognitionVerdict` | Require `PLAY_RECOGNIZED` for Play builds |
| `accountDetails` | Optional account licensing checks |
| Nonce | Bind to `installId` + timestamp; reject replay |

Reference sketch: `docs/PLAY_INTEGRITY_SERVER.md`.

## Planned v2 flow

1. **Client (Android):** Restore `PlayIntegrityBridge.kt` + `com.google.android.play:integrity`.
2. **Cold start:** `IntegrityAttestationService` requests token with nonce from `installId`.
3. **Headers:** First `GET {CAP_BASE_URL}/caps/{installId}` and protected `stream-token` calls send `X-Integrity-Token`.
4. **Server:** New endpoint `POST /v1/integrity/verify` (or inline on cap/stream handlers):
   - Call `playintegrity.googleapis.com` `decodeIntegrityToken`
   - Store nonce once (Redis / DB TTL 120s)
   - Return `{ allowCap, allowStream, verdict }`
5. **Fail-closed:** Missing/invalid token → no signed stream URL; cap sync may use local fallback only in sideload QA.

## Server endpoint changes

| Endpoint | v1.0 | v2 |
|----------|------|-----|
| `GET /caps/{installId}` | HMAC optional | + integrity on first cold start per 24h |
| `POST /v1/stream-token` | HMAC + channelId | + integrity JWT required in release |
| Appwrite catalog | Unchanged (Guests Read) | Unchanged |

**Do not** put integrity secrets or decode on Appwrite — use cap/stream API host (`STREAM_TOKEN_BASE_URL` / `CAP_BASE_URL`).

## Rollout plan

| Phase | DAU | Action |
|-------|-----|--------|
| Ship | &lt; 20k | v1.0/v1.1 as today; monitor fraud |
| Alert | **20k** | Page on-call; start v2 staging |
| Pilot | 20k–25k | 5% release with integrity required |
| GA | **≥ 25k** | 100% release; revoke sideload-only stream bypass |

## Client code markers

- `lib/security/play_integrity_service.dart` — TODO(integrity-v2)
- `lib/services/server_cap.dart` — re-add `X-Integrity-Token` per `docs/PLAY_INTEGRITY_SERVER.md`
- `docs/PLAY_INTEGRITY_OPTION_B.md` — archive when v2 GA

## Verification checklist (v2 GA)

- [ ] Play Console → App integrity → GCP project linked
- [ ] `PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER` in release CI
- [ ] Server decode deployed on same host as `STREAM_TOKEN_BASE_URL`
- [ ] Device test: physical phone, logcat shows non-empty integrity header once per cold start
- [ ] Pen test: patched APK without token cannot fetch signed stream URL
