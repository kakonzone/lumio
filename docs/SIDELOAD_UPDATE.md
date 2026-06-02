# Sideload force-update (GitHub Releases + lumio.me)

## Flow

```
push main (pubspec version bumped)
  → GitHub Actions: build APK + GitHub Release
  → Actions commit web/version.json
  → Cloudflare Pages deploys lumio.me
  → App reads https://lumio.me/version.json
  → Newer semver → force dialog → opens lumio.me → user taps Download → APK install
```

## Manifest (`web/version.json`)

Served at **`https://lumio.me/version.json`** (Cloudflare Pages, `web/` publish root).

```json
{
  "version": "1.0.1",
  "apk_url": "https://github.com/kakonzone/lumio/releases/download/v1.0.1/app-release.apk"
}
```

`apk_url` is used **only by the website** (`web/index.html` download button). The app opens `https://lumio.me/` instead of linking to GitHub directly.

## First install vs update

| Step | First install | App update |
|------|---------------|------------|
| Entry | User opens **lumio.me** | User opens **Lumio app** |
| Action | Tap **ডাউনলোড করুন** | Tap **আপডেট করুন** → browser opens lumio.me |
| Result | APK from `version.json` → install | Same download page → install new APK |

## App

- `lib/services/update_service.dart` — default URL `https://lumio.me/version.json`
- Override at build time: `--dart-define=FORCE_UPDATE_VERSION_URL=https://...`
- Checks on splash (blocks home) and `MainShell` post-frame
- Dialog cannot be dismissed; system back exits the app

## Cloudflare Pages

1. Project publish directory: **`web/`**
2. Custom domain: **`lumio.me`**
3. Connect repo `main` branch (auto-deploy on push)
4. `web/_headers` sets `Cache-Control: no-cache` for `/version.json`

## Release checklist

1. Bump `pubspec.yaml` version (e.g. `1.0.1+2`)
2. Push to `main`
3. Wait for Actions + Pages deploy
4. Verify: `curl -s https://lumio.me/version.json`

## Legacy optional manifest

`AppUpdateService` + `APP_UPDATE_MANIFEST_URL` still exist for soft updates but are not wired in `main.dart`.
