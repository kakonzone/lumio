# Lumio ad telemetry schema

## Reserved-name policy

Firebase Analytics rejects [reserved event names](https://firebase.google.com/docs/reference/cpp/group/event-names). All custom ad events use the `lumio_` prefix when the base name is reserved (`ad_click`, `ad_impression`, etc.).

| Event | Reserved? | Policy |
|-------|-----------|--------|
| `lumio_ad_click` | No (was `ad_click`) | `lumio_` prefix |
| `lumio_ad_impression` | No (was `ad_impression`) | `lumio_` prefix |
| `lumio_app_open` | No (was `app_open`) | `lumio_` prefix |
| `lumio_levelplay_fill_attempt` | No | New |
| `interstitial_shown` | No | Unchanged |
| `ad_fill_rate` | No | Unchanged |

## Events

### `lumio_ad_click`

| Param | Type | Notes |
|-------|------|-------|
| `network` | string | `levelplay`, `adsterra`, … |
| `ad_format` | string | `interstitial`, `native_webview`, … |
| `placement` | string | Trigger / placement id |

### `lumio_ad_impression`

| Param | Type | Notes |
|-------|------|-------|
| `ad_platform` | string | |
| `ad_source` | string | |
| `ad_format` | string | |
| `value` | double? | Revenue when available |
| `currency` | string | `USD` |
| `placement` / `placement_name` | string | |

### `lumio_levelplay_fill_attempt`

| Param | Type | Notes |
|-------|------|-------|
| `format` | string | `interstitial`, `rewarded` |
| `result` | string | `loading`, `filled`, `no_fill`, `error` |
| `error_code` | int? | e.g. `509`, `627` |
| `attempt_n` | int? | No-fill streak |
| `ms_since_init` | int | Ms since LevelPlay init success |
