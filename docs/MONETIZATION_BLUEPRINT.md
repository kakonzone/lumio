# Lumio Tri-Network Monetization Blueprint

**Placement map (Task 10) implemented** — see `docs/PLACEMENT_MAP.md`. Deferred: headless background WebView (`docs/DEFERRED_vNEXT.md`).

## 1. Network architecture

| Layer | Network | Integration |
|-------|---------|-------------|
| Clean SDK | IronSource LevelPlay | `lib/services/ironsource_service.dart` |
| Mediated | Unity Ads | LevelPlay dashboard only |
| Aggressive | Adsterra | WebView + `AdsterraEngine` / `AdsterraWebViewService` |

**Isolation:** 30 seconds after any Adsterra surface event, `AdTriggerManager` blocks LevelPlay interstitials.

## 2. Frequency caps (per device)

| Format | Cap |
|--------|-----|
| Interstitial (IS) | 8/hour, 60s min gap, 200–800ms jitter |
| Rewarded | 5/hour, user-initiated |
| App open substitute | 3/day, 4h gap |
| Adsterra direct link | 3/day |
| Adsterra popunder | 2/session (Remote Config cap), 90s cooldown |

## 3. Placement map (target state)

| Screen | IronSource / Unity | Adsterra |
|--------|-------------------|----------|
| Splash | App open substitute | Direct link post-splash (Week 2) |
| HOME | Banner 60s refresh | Social bar 20s refresh |
| SPORTS | — | Banner top + native list |
| LIVE | IS every 3rd channel tap | Popunder + direct link |
| NEWS | Native /8 | Native /5 (Week 3) |
| Player | Rewarded gates | Pre/mid/post WebView overlay |

## 4. Revenue projection (illustrative)

| DAU | Baseline/mo | Optimized/mo |
|-----|-------------|--------------|
| 500 | $700 | $4,500 |
| 1,000 | $1,400 | $9,000 |
| 5,000 | $7,000 | $45,000 |
| 10,000 | $14,000 | $90,000 |

Assumes 2.2 sessions/DAU, aggressive stack + caps, BD/IN/PK mix.

## 5. Four-week roadmap

| Week | Deliverable | Key files |
|------|-------------|-----------|
| 1 | Fingerprint, IS init, banner, app-open substitute, Remote Config | Done — see `docs/ADS_README.md` |
| 2 | Headless background WebView (deferred — see `docs/DEFERRED_vNEXT.md`) | `adsterra_engine.dart` |
| 3 | Full screen map, exit stack, phantom buffer label → real Adsterra overlay | `ad_trigger_manager.dart`, screens |
| 4 | A/B `aggressive_mode`, private telemetry dashboard | Firebase RC, Supabase |

## 6. Non-ad revenue (document only)

Betting CPA, VPN CPA, bKash donate, $1.99 ad-free — see product backlog.
