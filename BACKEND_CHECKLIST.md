# Backend checklist (ops)

## Stream token API

- [ ] Deploy `POST /v1/stream-token` per `docs/BACKEND_STREAM_TOKEN_CONTRACT.md`
- [ ] Set `STREAM_TOKEN_BASE_URL` + TLS pins in release CI
- [ ] Rate-limit by `installId` + `fingerprint`

## Cloudflare Worker (channels)

- [ ] Host catalog JSON at `REMOTE_CHANNELS_URL`
- [ ] Return `ETag` header for 304 support
- [ ] Optional: pin Worker host via `SSL_PIN_REMOTE_CHANNELS_*`

## Ads / caps

- [ ] Cap API (`CAP_BASE_URL`, `CAP_HMAC_KEY`) or `CAP_LOCAL_ONLY_MODE=true` for QA
- [ ] Adsterra telemetry HMAC if using private endpoint

## Legal

- [ ] Upload `legal/*.html` to `lumio.app`
- [ ] Publish `legal/app-ads.txt` at site root

## Wallet / referral (optional)

- [ ] `GET /v1/wallet/balance`, `POST /v1/wallet/spend` — see `docs/BACKEND_WALLET_API.md`
- [ ] Referral redeem endpoint when ready
