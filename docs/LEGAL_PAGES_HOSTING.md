# Legal Pages Hosting

Release builds must provide:

- `PRIVACY_POLICY_URL`
- `TERMS_OF_SERVICE_URL`
- `CONTACT_EMAIL`

## Minimal HTML templates

### Privacy policy

```html
<!doctype html>
<html><head><meta charset="utf-8"><title>Lumio Privacy Policy</title></head>
<body>
  <h1>Privacy Policy</h1>
  <p>Last updated: YYYY-MM-DD</p>
  <p>Describe data collection, ads, analytics, consent controls, and contact.</p>
  <p>Contact: legal@example.com</p>
</body></html>
```

### Terms of service

```html
<!doctype html>
<html><head><meta charset="utf-8"><title>Lumio Terms of Service</title></head>
<body>
  <h1>Terms of Service</h1>
  <p>Last updated: YYYY-MM-DD</p>
  <p>Describe content usage, disclaimers, prohibited conduct, and termination.</p>
  <p>Contact: legal@example.com</p>
</body></html>
```

## Hosting options

### GitHub Pages
1. Create repository for legal pages.
2. Add `privacy.html` and `terms.html`.
3. Enable Pages from branch.
4. Use generated HTTPS URLs in release defines.

### Cloudflare Pages
1. Create Pages project from git repo.
2. Deploy static HTML files.
3. Use project HTTPS domain for dart-defines.

## Build-time validation

`tool/build_release_apk.sh` now fails if legal URLs/contact email are missing.
