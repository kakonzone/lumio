# Device test — Task 10 (placement map + `aggressive_mode`)

**READY_FOR_DEVICE_TEST**

Full map: `docs/PLACEMENT_MAP.md`

---

## Build

```bash
flutter run --dart-define=ADS_TEST_MODE=true
```

After ads init, logcat should include:

```text
[Placement] aggressive_mode=false news_native_every=5 channel_native_every=8 player_midroll_min=20 social_bar=false
```

Toggle Firebase Remote Config `aggressive_mode` to **true** (or use RC debug override), restart app:

```text
[Placement] aggressive_mode=true news_native_every=4 channel_native_every=4 player_midroll_min=12 social_bar=true
```

```bash
adb logcat -d | grep '\[Placement\]'
```

---

## Checklist

### NEWS natives

| `aggressive_mode` | Expected |
|-------------------|----------|
| `false` | Native ad after articles **5, 10, 15…** |
| `true` | Native ad after **4, 8, 12…** |

Open **News** tab → scroll list → count native WebView slots.

### Channel / favorites / category lists

| `aggressive_mode` | Native interval |
|-------------------|-----------------|
| `false` | Every **8** channels |
| `true` | Every **4** |

### HOME social bar

| `aggressive_mode` | Sticky social WebView above bottom nav |
|-------------------|--------------------------------------|
| `false` | **Hidden** |
| `true` | **Visible** (if `adsterra_enabled`) |

### Splash direct link

1. Cold start with consent + ads test mode.
2. After app-open substitute interstitial, external browser **may** open (`splash_post`).
3. Cap: **≤3 per device per day** (`adsterraDirectLinkMaxPerDay`).

### Exit stack (HOME back)

1. On **HOME** tab, press system back once.
2. **Expect:** LevelPlay interstitial **or** Adsterra direct link (`back_exit`) — not immediate app exit.
3. Press back again → app exits.

---

## Code entry points (audit)

| Placement | File |
|-----------|------|
| Intervals | `lib/ads/ad_placement_config.dart` |
| NEWS | `lib/ads/ad_placement_news.dart` |
| Lists | `AdListInjector` + `channelListNativeInterval` |
| Social bar | `lib/widgets/adsterra_overlay_widget.dart` |
| Splash direct | `AdManager.showSplashDirectLinkIfAllowed()` |
| Exit | `AdManager.onExitIntent()` in `lib/main.dart` |

---

## Pass / fail criteria

| # | Criterion | Pass |
|---|-----------|------|
| 1 | `[Placement]` log matches RC `aggressive_mode` | ☐ |
| 2 | NEWS natives at /5 (standard) or /4 (aggressive) | ☐ |
| 3 | Social bar only when aggressive | ☐ |
| 4 | Splash direct ≤3/day | ☐ |
| 5 | HOME back → ad then second back exits | ☐ |
| 6 | `flutter test test/ads/ad_placement_config_test.dart test/ads/ad_placement_news_test.dart` | ☐ |

**Automated:**

```bash
flutter test test/ads/ad_placement_config_test.dart test/ads/ad_placement_news_test.dart
```

**Task 10 result:** ☐ PASS ☐ FAIL — Tester: __________ Date: __________
