# L3 — Ad refresh policy (user-visible vs SDK-auto)

**Phase 4 L3** — Documents what is user-triggered vs network-auto; code changes keep policy-compliant behavior.

---

## LevelPlay banner (HOME)

| Aspect | Behavior |
|--------|----------|
| Auto-refresh | **LevelPlay dashboard** (target 60s per `AdConfig.levelPlayBannerDashboardRefreshSeconds`) |
| Dart control | `pauseAutoRefresh()` when app **paused/hidden**; `resumeAutoRefresh()` on **resumed** |
| User trigger | Banner loads when user is on **HOME** tab (`MainShell` `_navIdx == 0` only) |
| Policy note | No forced refresh while app backgrounded — aligns with “not disruptive while away” |

**File:** `lib/widgets/ad_banner_widget.dart`, `lib/main.dart` (banner child only on HOME).

---

## Adsterra WebView surfaces

| Surface | Load trigger |
|---------|----------------|
| Native in lists | List built / scroll — **content navigation** |
| Sports banner | Tab switch to SPORTS |
| Social bar | `aggressive_mode` RC — visible on main shell; not timed auto-refresh in Dart |
| Popunder | Shell open + caps — see `POPUNDER_POLICY_REVIEW_H5.md` |
| Player overlays | User opens player / mid-roll timer (user session) |

No Dart timer re-loads Adsterra HTML on an interval except player mid-roll (`AdPlacementConfig.playerMidRollPeriod`).

---

## Interstitials / rewarded

| Format | Trigger |
|--------|---------|
| Interstitial | User channel taps, exit back, app-open substitute (capped) |
| Rewarded | User taps reward CTA in player |

All **user-initiated** or **session funnel** — not periodic auto-show.

---

## Changes in L3 (code)

- Banner lifecycle pause/resume already implemented — documented here.
- Removed session debug NDJSON from ads WebView path (L1).
- Dashboard refresh **cannot** be converted to tap-to-refresh without SDK support — documented as N/A.

---

## Store / policy disclosure

Privacy policy should state that ads may refresh while the app is open on supported screens; users can limit ads via in-app **Limited** consent and system ad privacy settings.
