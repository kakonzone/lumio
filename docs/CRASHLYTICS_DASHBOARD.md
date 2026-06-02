# Crashlytics Dashboard Watchlist (World Cup)

## Enable switch

- `FIREBASE_ENABLED=true` must be present in release dart-defines.
- If disabled, Firebase/Crashlytics bootstrap is skipped.

## Key crash surfaces

1. Player boot/open failures
2. Failover loops and source switches
3. Stream token fetch failures
4. Ad SDK interaction failures during playback

## Custom keys used

- `channel_id`
- `stream_url_host`
- `player_state`

## Alert thresholds (during peak matches)

- Crash-free users below 98.5% (critical)
- Player-related fatal count > 20/hour (critical)
- Stream token errors > 100/hour (high)

## Daily ops checklist

1. Filter by `reason` containing `player_init_failed`
2. Filter by `reason` containing `failover_from_`
3. Group by `stream_url_host`
4. Correlate with backend token error rate
