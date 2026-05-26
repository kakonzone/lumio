# Device test — Task 7 (LevelPlay banner refresh — dashboard 60s)

**READY_FOR_DEVICE_TEST**

---

## Important

Banner **auto-refresh interval is not set from Dart**. Flutter 9.2.0 only exposes `pauseAutoRefresh()` / `resumeAutoRefresh()`.

| What | Where |
|------|--------|
| Operator target | LevelPlay dashboard → banner unit `YOUR_BANNER_UNIT_ID` → **60s** auto-refresh |
| Code reference | `AdConfig.levelPlayBannerDashboardRefreshSeconds` (= 60) |
| Widget | `AdBannerWidget` on HOME (`placementName: home_bottom`) |

Adsterra sticky refresh (`adsterraStickyRefreshSeconds` = 20s) is separate and app-controlled.

---

## Dashboard setup (before device test)

1. [LevelPlay Monetize](https://platform.ironsrc.com/) → **Ad units**.
2. Open banner **`YOUR_BANNER_UNIT_ID`**.
3. Set **auto-refresh** = **60 seconds** (must match `levelPlayBannerDashboardRefreshSeconds`).
4. Save / publish.

---

## Build / run

```bash
flutter run --dart-define=ADS_TEST_MODE=true
# or release APK after consent on device
flutter build apk --release
```

Stay on **HOME** tab with banner visible for **≥65 seconds** (foreground).

---

## Log patterns

```bash
adb logcat -d | grep '\[Banner\]'
```

| Pattern | When |
|---------|------|
| `[Banner] dashboard auto-refresh target=60s unit=YOUR_BANNER_UNIT_ID` | First banner display (once per process) |
| `[Banner] impression placement=home_bottom` | Each SDK refresh / show |

**Pass:** At least **two** `impression placement=home_bottom` lines **≥55s apart** (allow network/dashboard jitter).

**Fail:** Only one impression after 65s — check dashboard refresh ≠ 60s or fill rate.

---

## Lifecycle (optional)

Background the app → SDK should pause refresh (`pauseAutoRefresh` in `AdBannerWidget`). Resume → `resumeAutoRefresh`. No extra log line required.

---

## Pass / fail criteria

| # | Criterion | Pass |
|---|-----------|------|
| 1 | Dashboard unit `YOUR_BANNER_UNIT_ID` set to 60s refresh | ☐ |
| 2 | First log shows `target=60s` | ☐ |
| 3 | Second `[Banner] impression` ~60s after first on HOME | ☐ |
| 4 | No Dart code calls a non-existent `setRefreshRate` / `bannerRefreshSeconds` | ☐ |
| 5 | `flutter test test/config/ad_config_banner_refresh_test.dart` | ☐ |

**Automated:**

```bash
flutter test test/config/ad_config_banner_refresh_test.dart
```

**Task 7 result:** ☐ PASS ☐ FAIL — Tester: __________ Date: __________
