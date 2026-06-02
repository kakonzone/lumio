# Phase 10 — Task 5 verification (zone validator)

## Build

```bash
flutter run --dart-define=DIAGNOSTICS_ENABLED=true --dart-define-from-file=secrets.json
```

## UI

1. Open drawer → tap version label **7 times** (diagnostics unlock)
2. Tap **Validate All Zones**
3. Table shows `configured` or `missing_config` per row

## Logcat

```bash
adb logcat | grep -E 'lumio_zone_validation|ZoneValidator'
```

One line per zone, e.g.:

```
[Lumio] lumio_zone_validation {network: monetag, zone_id: 11***42, result: configured, ...}
```

## Analyze

```bash
flutter analyze lib/ads/diagnostics/zone_validator.dart lib/screens/dev_diagnostics_screen.dart
```

## Failures

Document `no_fill` / `missing_config` rows in `docs/AD_ZONE_INVENTORY.md` with provider dashboard action.
