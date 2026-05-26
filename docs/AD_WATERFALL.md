# Ad waterfall (LevelPlay → Adsterra)

Implementation: `lib/ads/strategies/waterfall_logic.dart`

## Interstitial

| Step | Network | Format | On failure |
|------|---------|--------|------------|
| 1 | LevelPlay | `interstitial` | no-fill, display fail, or **5s** timeout (`AdConfig.waterfallTimeoutMs`) |
| 2 | Adsterra | `direct_link` | `AdsterraEngine.openDirectLink` placement `waterfall_interstitial_fallback` |

Structured log tag: `[waterfall_step]` with `step`, `network`, `format`, `result`.

## Rewarded

| Step | Network | Notes |
|------|---------|--------|
| 1 | LevelPlay | `rewarded` only — **no Adsterra equivalent** |

On LevelPlay no-fill/timeout, waterfall ends with `logNoFill(placement: rewarded)`.

## Remote Config

- `adsterra_enabled` — gates step 2
- `levelplay_enabled` — gates LevelPlay init (see `ironsource_service.dart`)
