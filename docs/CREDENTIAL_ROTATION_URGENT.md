# CREDENTIAL ROTATION URGENT

Legacy stream credentials were exposed in historical source and must be considered compromised.

## Immediate actions

1. Rotate all upstream provider credentials previously embedded in stream URLs.
2. Revoke old usernames/passwords/tokens at provider panel.
3. Enforce IP/domain restrictions at provider side where possible.
4. Move all protected stream access behind `/v1/stream/token` signed URL backend.
5. Set short token TTL (recommended 3-5 minutes).
6. Add monitoring for abnormal token issuance volume and geo anomalies.

## Incident posture

- Assume old credentials are already scraped from prior APKs and git history.
- Do not reintroduce any credentialed URL in app source, assets, or remote JSON.
