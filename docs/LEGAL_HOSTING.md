# Legal page hosting

Templates live in `assets/legal/`. Publish rendered HTML at the URLs in `LegalConfig` (defaults: `https://lumio.app/privacy`, `/terms`, `/data-deletion`).

## Option A — Cloudflare Pages

1. Create a `legal-site` repo with `privacy/index.html`, `terms/index.html`, `data-deletion/index.html`.
2. Convert markdown templates to HTML (or use a static generator).
3. Connect custom domain `lumio.app` in Cloudflare DNS.
4. Deploy on push to `main`.

## Option B — GitHub Pages

1. Enable Pages on `gh-pages` branch.
2. CNAME `lumio.app` → GitHub Pages.
3. Upload HTML at `/privacy`, `/terms`, `/data-deletion`.

## Option C — S3 + CloudFront

1. Upload HTML objects to bucket `lumio-legal`.
2. CloudFront distribution with ACM cert for `lumio.app`.
3. Path behaviors: `/privacy`, `/terms`, `/data-deletion`.

## App defines

Override defaults in release CI if URLs differ:

```bash
--dart-define=PRIVACY_POLICY_URL=https://lumio.app/privacy
--dart-define=TERMS_OF_SERVICE_URL=https://lumio.app/terms
--dart-define=CONTACT_EMAIL=support@lumio.app
--dart-define=DATA_DELETION_URL=https://lumio.app/data-deletion
```

## Play Console

- Data safety form must match `privacy_policy_template.md`.
- Data deletion URL must match `DATA_DELETION_URL`.
