# Lumio Kill Switch Configuration

This directory (or GitHub repository) contains the kill switch configuration file for the Lumio app.

## Setup

1. Create a new GitHub repository named `lumio-config`
2. Add a file named `status.json` in the `main` branch
3. Configure the app to use this repository by setting the `KILL_SWITCH_OWNER` environment variable:
   ```bash
   --dart-define=KILL_SWITCH_OWNER=<your-github-username>
   ```

## status.json Schema

```json
{
  "app_enabled": true,
  "ads_enabled": true,
  "levelplay_enabled": true,
  "adsterra_enabled": true,
  "monetag_enabled": true,
  "force_update_version": "1.0.0",
  "maintenance_message_bn": "অ্যাপ মেইনটেনেন্সে আছে"
}
```

## Fields

- `app_enabled`: If false, the app shows a maintenance screen and blocks all navigation
- `ads_enabled`: If false, all ad surfaces are disabled (revenue emergency off switch)
- `levelplay_enabled`: If false, IronSource LevelPlay ads are skipped in the waterfall
- `adsterra_enabled`: If false, Adsterra WebView ads are skipped
- `monetag_enabled`: If false, Monetag/PropellerEngine ads are skipped
- `force_update_version`: If set, shows an update prompt for versions below this value
- `maintenance_message_bn`: Bengali message shown when app_enabled is false

## Cache Behavior

The app caches the status.json response for 15 minutes in SharedPreferences. Changes to the GitHub file will take up to 15 minutes to reflect on user devices.

## Fail-Open

If the GitHub repository is inaccessible or the fetch fails, the app defaults to all flags being `true` (ads and app enabled). This ensures network issues don't accidentally block users.

## Example Emergency Scenarios

### Disable All Ads
```json
{
  "app_enabled": true,
  "ads_enabled": false,
  "levelplay_enabled": true,
  "adsterra_enabled": true,
  "monetag_enabled": true
}
```

### Disable Specific High-Risk Network
```json
{
  "app_enabled": true,
  "ads_enabled": true,
  "levelplay_enabled": true,
  "adsterra_enabled": false,
  "monetag_enabled": true
}
```

### Maintenance Mode
```json
{
  "app_enabled": false,
  "ads_enabled": false,
  "maintenance_message_bn": "আমাদের সার্ভারে রক্ষণাবেক্ষণ চলছে, কিছুক্ষণ পর আবার চেষ্টা করুন"
}
```
