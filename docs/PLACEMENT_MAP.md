# Ad placement map (implemented)

Status: **READY_FOR_DEVICE_TEST**

| Screen | LevelPlay / Unity | Adsterra | RC / config |
|--------|-------------------|----------|-------------|
| Splash | App-open substitute (interstitial) | Direct link `splash_post` (3/day) | After consent + `splashMinMsBeforeAds` |
| HOME | Banner `home_bottom` (dashboard 60s refresh) | Social bar overlay | `aggressive_mode` only |
| SPORTS | — | Banner `sports_top` + native list /8 or /4 | `AdPlacementConfig.channelListNativeInterval` |
| NEWS | Banner `news_top` + native `news_headlines` | Native every 5 articles `news_native_*` | `AdPlacementNews` |
| LIVE | IS on channel tap (funnel) | Native list every **8** (or **4** aggressive) `live_list_*`; popunder on shell open | `channelListNativeInterval` |
| NEWS | — | Native every **5** (or **4** aggressive) | `nativeListIntervalNews` |
| Player | Rewarded | Pre/mid/post WebView; mid-roll 20m or 12m | `playerMidRollPeriod` |
| Exit (back) | Interstitial `back_exit` | Direct link fallback `back_exit` | Once per session |

## `aggressive_mode` (Firebase Remote Config)

When `true`:

- Channel/favorites/category native interval: **4** (was 8)
- NEWS native interval: **4** (was 5)
- Player mid-roll: **12 min** (was 20)
- Global sticky social bar: **on** (`AdsterraOverlayWidget`)

When `false`: social bar hidden; standard intervals above.

## Code entry points

| Placement | File |
|-----------|------|
| Intervals | `lib/ads/ad_placement_config.dart` |
| NEWS inject | `lib/ads/ad_placement_news.dart` |
| Splash direct | `AdManager.showSplashDirectLinkIfAllowed()` |
| Exit stack | `AdManager.onExitIntent()` |
| Lists | `lib/widgets/ad_list_injector.dart` — `AdListInjector.buildSeparatedChannelList(interval: …)` |

## Device verification

On first `AdManager.init`, log once:

`[Placement] aggressive_mode=… news_native_every=… channel_native_every=…`

See `docs/DEVICE_TEST_TASK_10.md`.
