# Deploy legal pages + app-ads.txt (Cloudflare Pages)

## Files

| Source | Deploy path |
|--------|-------------|
| `web/legal/privacy.html` | `https://lumio.app/privacy` |
| `web/legal/terms.html` | `https://lumio.app/terms` |
| `web/legal/data-deletion.html` | `https://lumio.app/data-deletion` |
| `web/app-ads.txt` | `https://lumio.app/app-ads.txt` |

Copy content from `legal/` at repo root if `web/legal/` is not yet synced.

## Cloudflare Pages

1. Create Pages project `lumio-legal` connected to this repo (or upload `web/` folder).
2. Build command: none (static).
3. Output directory: `web`
4. Custom domain: `lumio.app`
5. Add `_redirects` if needed for trailing slashes.

## Verify

```bash
curl -I https://lumio.app/privacy
curl https://lumio.app/app-ads.txt
```

Match dart-defines: `PRIVACY_POLICY_URL`, `TERMS_OF_SERVICE_URL`, `DATA_DELETION_URL`.
