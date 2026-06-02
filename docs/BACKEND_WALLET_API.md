# Wallet API (optional backend)

Client: `lib/services/wallet_api_client.dart`

Requires `LUMIO_BACKEND_BASE_URL` and `LUMIO_BACKEND_APP_KEY`.

## GET /v1/wallet/balance

Query: `installId`

Response: `{ "balance": 120 }`

## POST /v1/wallet/spend

Body: `{ "installId", "amount", "reason" }`

Response: `200` on success, `402` if insufficient balance.

Local fallback: `CoinEconomy` (SharedPreferences) when backend unset.
