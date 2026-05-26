# TASK 4 — Interstitial cap on display only — verification

## Code paths

- Cap debit: `AdTriggerManager.recordInterstitialShown()` only (from `onAdDisplayed` → `_recordCapOnDisplay`).
- Attempt only: `recordInterstitialAttempted()` at `showAd()` — no cap debit.
- Timeout: `onTimeout: () => false` + log `[Interstitial] timeout — cap not recorded`.

## Automated

```bash
flutter test test/ads/ad_trigger_manager_test.dart
grep -n 'onTimeout' lib/services/ironsource_service.dart
```

## Device logcat

```bash
adb logcat -d | grep -E 'Interstitial|Cap\]'
```

Force slow/no-fill interstitial (airplane mode after tap) — expect timeout line **without** a following `[Cap] shown` for that attempt.
