# Lumio Ads — Tri-Network Setup (LevelPlay + Unity + Adsterra)

## Networks

| Layer | Network | SDK / delivery |
|-------|---------|----------------|
| Clean | IronSource LevelPlay | `unity_levelplay_mediation` |
| Clean | Unity Ads | **Mediation-only** in [LevelPlay dashboard](https://platform.ironsrc.com/) — no Unity SDK in app; channel rotation uses `levelplay_interstitial_a` / `_b` analytics labels only |
| Aggressive | Adsterra | WebView + external direct link (`webview_flutter` only — no `flutter_inappwebview` in tree) |

**No AdMob.** Non-release builds block ad loads by default; opt in with:

```bash
flutter run --dart-define=ADS_ENABLED=true
# legacy: --dart-define=ADS_TEST_MODE=true
```

See `docs/AD_TESTING.md`.

**Release APK ignores `ADS_TEST_MODE`** — ads follow consent and caps only.

See `AdConfig.blockAdsInThisBuild` / `AdConfig.adsTestModeEffective` / `AdSafetyService.adsBlockedInDebug`.

---

## Shared-WiFi mitigation (why it exists)

On one IP (hostel, café, home), many devices look like one user to ad networks. Without device IDs, caps hit everyone at once and networks flag “invalid traffic.”

| Measure | File | What it does |
|---------|------|----------------|
| Device fingerprint | `lib/services/ad_safety_service.dart` | UUID install ID (first launch) + device signals → SHA-256 → SharedPreferences |
| Ads consent | `lib/services/ad_consent_service.dart` | First-launch dialog on splash; drives GDPR/CCPA before LevelPlay init |
| Server caps (GET) | `lib/ads/server_cap_client.dart` → `ServerCap` | Optional API overlay on hourly limits — see `docs/SERVER_CAP_API.md` |
| VPN routing | `ad_safety_service.dart` | Locale/TZ heuristic → prefer LevelPlay, disable Adsterra |
| `setDynamicUserId` + `withUserId` | `lib/services/ironsource_service.dart` | Called **before** `LevelPlay.init()` |
| Per-device hourly caps | `lib/services/ad_trigger_manager.dart` | Interstitial 8/hr, 60s gap; rewarded 5/hr; direct link 3/day |
| 30s network isolation | `ad_trigger_manager.dart` | After Adsterra popunder/background, LevelPlay cannot show for 30s |
| Natural delay | `ad_trigger_manager.dart` | Random 200–800ms before SDK interstitial |
| Session analytics | `lib/ads/analytics/ad_analytics.dart` | LevelPlay + funnel events via Firebase |

---

## IronSource / LevelPlay dashboard

1. App → Android → Package `com.kakonzone.lumio`.
2. Copy **App Key** → env / `--dart-define=LEVELPLAY_APP_KEY=...` (see `docs/SECRETS.md`, `docs/SECRETS_ENV.md`). Gradle syncs manifest `ApplicationKey`.
3. Create ad units → `LEVELPLAY_INTERSTITIAL_AD_UNIT`, `LEVELPLAY_REWARDED_AD_UNIT`, `LEVELPLAY_BANNER_AD_UNIT` dart-defines.
4. **Mediation → Unity Ads** → add Unity game ID (no Unity SDK in Flutter).
5. Enable test mode for your device ID while developing.

**Verify in logcat (release build):**

```text
[LevelPlay] setDynamicUserId(<32-char hash>) before init
```

---

## Adsterra dashboard

1. Register app/site as **APK landing URL** (not Play Store).
2. Create: Direct Link, Popunder script, Native, Social bar, 728×90 banner.
3. Set Adsterra URLs via `--dart-define=ADSTERRA_*` (see `docs/SECRETS.md`) — never commit literals in `ad_config.dart`.
4. Aggressive telemetry → `logAdsterraTelemetry()` (debug print + release POST). See `docs/ADSTERRA_TELEMETRY_API.md`.

---

## Firebase Remote Config kill switches

| Key | Default | Effect |
|-----|---------|--------|
| `adsterra_enabled` | `true` | All Adsterra WebView / direct link |
| `popunder_session_cap` | `2` | Max popunders per session |
| `aggressive_mode` | `false` | Natives /4, NEWS /4, mid-roll 12m, social bar overlay — see `docs/PLACEMENT_MAP.md` |

---

## App-open on cold start (not native App Open)

LevelPlay Flutter **9.2.0 has no App Open ad API**. Lumio uses a **capped interstitial** after splash (`showAppOpenSubstitute` in `ironsource_service.dart`). Do not expect App Open format in the LevelPlay dashboard for this placement.

See `docs/LEVELPLAY_SDK_VERIFICATION.md` for SDK signatures.

### Banner auto-refresh

| What | Value |
|------|--------|
| Dart constant | `AdConfig.levelPlayBannerDashboardRefreshSeconds` (= 60) |
| Ad unit | `AdConfig.bannerAdUnitId` |
| Where to set | LevelPlay dashboard only — **not** from Flutter |

Do not rename back to `bannerRefreshSeconds`; that name implied an SDK call that does not exist.

---

## Test checklist (Week 1)

- [ ] Release APK: LevelPlay init succeeds with `LEVELPLAY_APP_KEY` synced to manifest `com.ironsource.sdk.ApplicationKey` (`@string/levelplay_app_key` from Gradle).
- [ ] Log shows `setDynamicUserId` before init.
- [ ] Splash → optional **interstitial** substitute (max 3/day) — not native App Open.
- [ ] HOME → IronSource banner visible above social bar; dashboard refresh = **60s** (`levelPlayBannerDashboardRefreshSeconds`).
- [ ] First channel tap → Adsterra direct link (max 3/device/day).
- [ ] Second tap → player opens.
- [ ] Remote Config: set `adsterra_enabled=false` → WebViews hidden.
- [ ] Debug build → no ads unless `--dart-define=ADS_TEST_MODE=true`.

---

## Ban-risk monitoring

- Watch LevelPlay **IVT** and Adsterra **suspicious activity** weekly.
- If eCPM spikes with **retention collapse**, reduce `popunder_session_cap`.
- Never overlap SDK interstitial within 30s of Adsterra popunder (enforced in code).

---

## Folder map

| Doc | Purpose |
|-----|---------|
| `docs/MONETIZATION_BLUEPRINT.md` | Architecture + roadmap |
| `docs/PLACEMENT_MAP.md` | Screen placements (Task 10) |
| `docs/TELEMETRY_SPLIT.md` | Firebase vs Adsterra vs cap API (L4) |
| `docs/L3_AD_REFRESH_POLICY.md` | Auto vs user-triggered refresh (L3) |
| `docs/DEVICE_TEST_CHECKLIST.md` | Release device sign-off |
| `docs/RELEASE_NOTES_PHASE6.md` | Phase 6 gap-closure summary |

See `docs/MONETIZATION_BLUEPRINT.md` for placement tables and 4-week roadmap.

---

## Channel-tap rotation (no separate Unity SDK)

```text
tap #1 → Adsterra direct link (browser)
tap #2 → LevelPlay interstitial slot A  (enum: levelPlayMediatedA → analytics: levelplay_interstitial_a)
tap #3 → LevelPlay interstitial slot B  (enum: levelPlayMediatedB → analytics: levelplay_interstitial_b)
         └─ same LevelPlayInterstitialAd unit; Unity may win inside mediation dashboard only
```

**Must NOT appear in analytics:** `unity`, `channel_tap_unity`, `ironSource` as network name.

Implementation: `lib/ads/strategies/channel_tap_ad_rotator.dart`, `lib/ads/ad_manager.dart`.
