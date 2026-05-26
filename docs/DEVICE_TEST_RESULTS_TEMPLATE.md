# Device test results — ads monetization

**Tester:** __________ **Date:** __________ **Build:** __________  
**Device:** __________ **APK:** debug / release **Defines:** __________

## Evidence required

Attach `device_test_<timestamp>.log` from `./scripts/capture_logcat.sh` and screenshots for each checked row.

| ID | Test | Pass | Log line / screenshot |
|----|------|------|------------------------|
| D1 | Cold start Firebase + RC | ☐ | `[Lumio] Firebase init OK` |
| D2 | Consent grant → ads eligible delay | ☐ | `[AdConsent] granted` |
| D3 | Home banner fill (LevelPlay) | ☐ | `[Cap] shown` or dashboard fill |
| D4 | Channel tap → interstitial or Adsterra | ☐ | `waterfall_step` / `channel_tap` |
| D5 | Interstitial timeout does not debit cap | ☐ | `timeout — cap not recorded` |
| D6 | Popunder once per session cap | ☐ | `popunder mounted` once |
| D7 | Rewarded (HD/VIP/coins) | ☐ | `placement=rewarded` |
| D8 | Exit ad | ☐ | `trigger=back_exit` |
| D9 | RC `ads_enabled=false` kills ads | ☐ | `ads disabled via Remote Config` |

**Ship-ready:** ☐ All PASS with evidence attached
