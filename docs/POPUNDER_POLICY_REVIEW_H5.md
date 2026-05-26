# Popunder policy review — Phase 2 H5

**Generated:** 2026-05-25  
**Scope:** Adsterra popunder delivery in Lumio (not Google AdMob inventory — review uses **AdMob / AppLovin / MRC** style principles: no forced clicks, no system UI obstruction, user-dismissible where applicable).

**Action taken:** Flags only — **no code removed** per audit. You decide remediation.

---

## Implementation map

| Piece | File | Behavior |
|-------|------|----------|
| Shell trigger | `lib/main.dart` L172–174 | `maybeShowPopunder()` once post-frame on `MainShell` init |
| Cap / cooldown | `lib/services/ad_trigger_manager.dart` | RC `popunder_session_cap` (default 2), 90s cooldown |
| Cap record | `lib/ads/ad_manager.dart` L107–112 | Records popunder **without** opening a new Activity |
| Hidden host | `lib/main.dart` L208–215 | `AdsterraPopunderHost` 1×1 px bottom-left in `Stack` |
| WebView load | `lib/ads/adsterra/adsterra_popunder.dart` | Loads `AdsterraHtml.popunder()` script in 1×1 clipped WebView |
| Script HTML | `lib/ads/adsterra/adsterra_html.dart` | Third-party `ADSTERRA_POPUNDER_SCRIPT_URL` |
| Network isolation | `ad_trigger_manager.dart` | 30s block on LevelPlay after Adsterra surface |

---

## Policy checklist

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| 1 | No forced click / auto-click overlay on app UI | **PASS** | No `GestureDetector` forcing taps; popunder is off-screen 1×1 WebView |
| 2 | No full-screen blocking overlay on system UI | **PASS** | `ClipRect` + 1×1 `SizedBox`; does not cover `BottomNavigationBar` or player |
| 3 | User-dismissible ad surface | **FLAG — MEDIUM** | Host is non-interactive 1×1 pixel; user cannot dismiss script-driven popunder from Lumio UI. Dismissal depends on **browser/Adsterra** layer after script fires |
| 4 | Popunder only after user/session context | **FLAG — LOW** | WebView mounts when `adsEnabled` on shell open — **before** `maybeShowPopunder()` cap check. Script may load even when session cap already consumed |
| 5 | Frequency capped | **PASS** | `canShowAdsterraPopunder()` + RC cap + 90s cooldown |
| 6 | Separated from SDK interstitial timing | **PASS** | `networkIsolationSeconds` = 30 |
| 7 | Disabled when VPN/geo fraud tier routes clean | **PASS** | `adsterraEnabled` false when `preferCleanSdkRouting` |
| 8 | AdMob “pop-up” policy (if ever using AdMob) | **N/A** | Lumio uses Adsterra + LevelPlay, not AdMob units |
| 9 | AppLovin “disruptive ads” guidance | **FLAG — LOW** | Hidden WebView popunder may count as **non-standard placement**; document for store review if questioned |
| 10 | Child-directed / COPPA | **PASS** | `setCOPPA(false)` with adult sports positioning; no child mode |

---

## Findings (for your decision)

### F1 — WebView loads regardless of cap (LOW)

`AdsterraPopunderHost` is in the widget tree whenever `AdManager.instance.adsEnabled` is true. `maybeShowPopunder()` only increments session counters / telemetry — it does **not** gate WebView creation.

**Risk:** Script network activity on every shell open even when cap exhausted.  
**Suggested fix (if approved):** Wrap host in `FutureBuilder` on `canShowAdsterraPopunder()` or lazy-mount after cap passes.

### F2 — No in-app dismiss for script popunder (MEDIUM)

If Adsterra script opens external browser/tab, Lumio provides no close affordance. Acceptable for many publisher networks if disclosure exists in privacy policy; **may fail** strict interpretations of “dismissible.”

**Suggested fix (if approved):** Switch to user-initiated direct link only, or show interstitial with close button instead of script popunder.

### F3 — `JavaScriptMode.unrestricted` (LOW)

`adsterra_webview.dart` enables unrestricted JS for all Adsterra surfaces including popunder.

**Risk:** Script can navigate or invoke intents. Mitigated by off-screen size but not sandboxed.  
**Suggested fix (if approved):** `NavigationDelegate` block non-allowlisted domains for `placement == 'popunder'`.

### F4 — Compliance documentation (INFO)

Privacy policy / store listing should mention:

- Third-party advertising and redirect ads (Adsterra)
- Possible background WebView ad loading
- Opt-out via device ad settings + in-app consent (Limited ads)

---

## Verdict

| Overall | Detail |
|---------|--------|
| **Ship with flags** | No automatic deletion; caps and isolation are sound |
| **Blockers** | None identified for sideload APK monetization |
| **Your call** | F1 + F2 if targeting Play Store or stricter ad policy audit |

---

## Device verification (optional)

```bash
adb logcat | grep -E 'popunder|AdsterraTelemetry|ServerCap'
```

1. Cold start → open shell → confirm at most RC cap popunder telemetry events per session.  
2. Confirm no full-screen WebView overlay on HOME / player.  
3. With VPN fraud routing (`vpn_confidence` high), confirm Adsterra surfaces disabled.

**REQUIRES DEVICE TEST** for script actually opening browser — cannot verify Adsterra script behavior from static review alone.
