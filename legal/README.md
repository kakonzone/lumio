# Legal pages (host on lumio.app)

Upload these static files to your production site:

| File | Public URL |
|------|------------|
| `privacy.html` | `https://lumio.app/privacy` |
| `terms.html` | `https://lumio.app/terms` |
| `data-deletion.html` | `https://lumio.app/data-deletion` |
| `app-ads.txt` | `https://lumio.app/app-ads.txt` |

Match `--dart-define` values in CI:

- `PRIVACY_POLICY_URL=https://lumio.app/privacy`
- `TERMS_OF_SERVICE_URL=https://lumio.app/terms`
- `DATA_DELETION_URL=https://lumio.app/data-deletion`

Markdown templates for editing live in `assets/legal/`.
