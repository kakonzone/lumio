# LUMIO Ads Setup

## Networks

| Network | Role | Config file |
|---------|------|-------------|
| LevelPlay (IronSource) | Primary interstitial / rewarded | `lib/config/ad_config.dart` |
| Unity Ads | Mediation in LevelPlay dashboard only (no Unity SDK) | Configure in IronSource → Mediation |
| Adsterra | WebView banners / native / popunder | `lib/config/ad_config.dart` |

## Android

1. **Package ID:** `com.kakonzone.lumio` (must match LevelPlay + Unity dashboards).
2. Add `google-services.json` under `android/app/` for Firebase Analytics (same package).
3. LevelPlay requires Play Services deps (already in `android/app/build.gradle.kts`).
4. Set your **Adsterra direct link** in `AdConfig.adsterraDirectLink` (optional smartlink).

## Dashboards

- [LevelPlay](https://platform.ironsrc.com/)
- [Unity Ads](https://operate.dashboard.unity3d.com/)
- [Adsterra](https://publishers.adsterra.com/)

## Behaviour

- **First channel tap** → rotated in-app ad (Adsterra → LevelPlay interstitial slots A/B); second tap plays direct.
- **3rd+ channel tap** → interstitial (90s cooldown, max 8/session).
- **Player** → optional pre-roll interstitial; no ads overlay on video; banner below player.
- **Sports tab** → interstitial on first switch per session path.

## Regenerate Adsterra-only URLs

```bash
python3 tool/gen_user_paste_m3u.py
```
