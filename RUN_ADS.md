# Run Lumio with ads (required for debug)

**Do not use plain `flutter run`.** Keys are compile-time; without defines every ad key is `<unset>`.

## Correct command

```bash
./scripts/flutter_run_with_ads.sh
```

Same as:

```bash
flutter run --dart-define-from-file=secrets.json
```

## VS Code / Cursor

Choose launch config: **「Lumio (debug + ads)」** — not 「Lumio (debug, no ads)」.

## First-time setup

```bash
cp secrets.json.template secrets.json
# fill keys (never commit secrets.json)
```

## Success log (first 30s)

```text
[AdConfig] … LEVELPLAY_APP_KEY=<set> … hasMonetizationConfig=<set>
(no ⚠️ WARNING: no dart-defines detected)
[AdConsent] stored consent applied to LevelPlay (granted)
LevelPlaySDK … LevelPlay=true
[LevelPlay] setDynamicUserId before init
[LevelPlay] init success
```

## Hot reload does NOT apply secrets

After changing `secrets.json`, stop the app (`q`) and run the script again.
