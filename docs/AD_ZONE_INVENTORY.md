# Ad zone inventory (Phase 10)

| Network | Zone ID | Placement | Format | Status | Last Validated |
|---------|---------|-----------|--------|--------|----------------|
| LevelPlay | interstitial unit | interstitial | interstitial | CI define | Diagnostics |
| LevelPlay | rewarded unit | rewarded | rewarded | CI define | Diagnostics |
| LevelPlay | banner unit | banner | banner | CI define | Diagnostics |
| Adsterra | direct_link | channel_tap | direct | CI define | Diagnostics |
| Adsterra | popunder | webview | popunder | script+base pair | Diagnostics |
| Adsterra | native | webview | native | invoke+base pair | Diagnostics |
| Adsterra | banner728 | webview | banner | invoke+base pair | Diagnostics |
| Monetag | 11***42 | onclick | onclick | default / define | Diagnostics |
| Monetag | 11***67 | vignette | vignette | default / define | Diagnostics |
| Monetag | 11***85 | inpage_push | inpage_push | default / define | Diagnostics |
| Monetag | 11***86 | direct | direct | default / define | Diagnostics |

Run on device with `--dart-define=DIAGNOSTICS_ENABLED=true` → drawer (7× version tap) → **Validate All Zones**.

Logcat: `adb logcat | grep lumio_zone_validation`
