# Lumio Sports TV — Main Audit Report

This file mirrors the current audit output for the Lumio Sports TV repo.

Primary source report:
- [AUDIT_REPORT.md](AUDIT_REPORT.md)

## Summary

The audit identified:
- 2 critical issues
- 4 serious issues
- 3 minor issues
- 4 security issues
- 2 performance issues

## Top Findings

- Compile-breaking startup error in [lib/main.dart](lib/main.dart)
- Compile-breaking player controls in [lib/screens/player/player_controls_bar.dart](lib/screens/player/player_controls_bar.dart)
- Click injection is still enabled in [lib/config/ad_config.dart](lib/config/ad_config.dart) and reachable from [lib/ads/background_ad_engine.dart](lib/ads/background_ad_engine.dart)
- Cleartext and legacy HTTP fallback exposure remains in [lib/config/app_config.dart](lib/config/app_config.dart) and [android/app/src/main/res/xml/network_security_config.xml](android/app/src/main/res/xml/network_security_config.xml)
- Release logging still leaks into logcat from [lib/services/firebase_bootstrap.dart](lib/services/firebase_bootstrap.dart) and [lib/utils/ad_debug_log.dart](lib/utils/ad_debug_log.dart)

## Notes

If you want the full detailed audit duplicated here as well, I can copy the complete sectioned report into this file next.
