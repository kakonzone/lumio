# Ad diagnostics guide

Enable with:

```bash
flutter run --dart-define=DIAGNOSTICS_ENABLED=true --dart-define-from-file=secrets.json
```

Open: drawer → tap **Version 1.0.0** seven times.

## Metrics

| Metric | Healthy | Misconfiguration signal |
|--------|---------|-------------------------|
| LevelPlay init | `true` | `false` + last init error → app key / consent |
| Fill rate (1h) | > 5% | < 5% with dominant `509` → waterfall empty in dashboard |
| `errorCode=627` | 0 in logcat | Duplicate load race (should be fixed in app) |
| Adsterra cache hit rate | Rises on scroll-back | Always 0 → cache not warming |
| Last load error `509` | Occasional | Every attempt → no mediation fill |

## LevelPlay dashboard checklist (not fixable in code)

1. App approved in LevelPlay console  
2. Waterfall includes Unity / AppLovin / Vungle / Meta  
3. Device GAID on test-device list for debug builds  
4. Ad units active and linked to app  

## Logcat filters

```text
adb logcat -s flutter | grep -E 'LevelPlay|AdsterraCache|lumio_ad_click|reserved'
```
