# TASK 5 — Channel-tap enum labels — verification

## Change

- Removed misleading `ironSource` / implicit Unity SDK naming.
- Enum: `levelPlayMediatedA`, `levelPlayMediatedB` (same `LevelPlayInterstitialAd`).

## Grep

```bash
grep -rn 'ChannelTapAdNetwork\.ironSource\|levelplayInterstitialB\|channel_tap_unity' lib/
# expect no matches
```

## Analytics

Channel tap on device — Firebase/debug should show `levelplay_interstitial_a` or `_b`, never `unity`.
