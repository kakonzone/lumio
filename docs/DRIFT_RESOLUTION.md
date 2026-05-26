# Drift resolution — Task 2.1

**Source audit:** `docs/DRIFT_REPORT.md` (2026-05-25)  
**Resolved:** 2026-05-25 (P2)  
**Rule:** 18 **DRIFT** rows — doc updated to match code unless noted.

| Row | Doc / section | Decision | File(s) touched | Evidence |
|-----|---------------|----------|-----------------|----------|
| 1 | `ADS_README` #10 — paste App Key into `ad_config.dart` | **(a) doc** | `docs/ADS_README.md` | Points to `SECRETS.md` / dart-define |
| 2 | `ADS_README` #11 — paste Adsterra URLs into `ad_config.dart` | **(a) doc** | `docs/ADS_README.md` | `ADSTERRA_*` env only |
| 3 | `ADS_README` #12 — server caps “stub” | **(a) doc** | `docs/ADS_README.md` | GET `ServerCap` + `SERVER_CAP_API.md` |
| 4 | `ADS_README` #15 — release without manifest `ApplicationKey` | **(a) doc** | `docs/ADS_README.md` | Gradle `resValue` + manifest meta-data |
| 5 | `ADS_SETUP` #2 — Unity as separate waterfall SDK | **(a) doc** | `docs/ADS_SETUP.md` | Mediation-only row |
| 6 | `PLACEMENT_MAP` #7 — `AdListInjector` under `lib/ads/` | **(a) doc** | `docs/PLACEMENT_MAP.md` | `lib/widgets/ad_list_injector.dart` |
| 7 | `PHASE5_SECURITY` #6 — `serverCapBaseUrl` field name | **(a) doc** | `docs/PHASE5_SECURITY.md` | `AdConfig.capBaseUrl` |
| 8 | `SERVER_CAP_API` #6 — HMAC required for active client | **(a) doc** | `docs/SERVER_CAP_API.md` (P1) | GET has no HMAC; POST legacy |
| 9 | `LEVELPLAY_SDK_VERIFICATION` #3 — hardcoded banner unit | **(a) doc** | `docs/LEVELPLAY_SDK_VERIFICATION.md` | Generic dashboard unit ID |
| 10 | `LEVELPLAY_SDK_VERIFICATION` #4 — “Phase 5 will add consent” | **(a) doc** | `docs/LEVELPLAY_SDK_VERIFICATION.md` | `AdConsentService` shipped |
| 11 | `LEVELPLAY_SDK_VERIFICATION` #5 — static `setCCPA(false)` only | **(a) doc** | `docs/LEVELPLAY_SDK_VERIFICATION.md` | Post-consent `applyToLevelPlaySdk()` |
| 12 | `DEVICE_TEST_TASK_7` — `znewe3rrge3dh03f` | **(a) doc** | `docs/DEVICE_TEST_TASK_7.md` | `YOUR_BANNER_UNIT_ID` |
| 13 | `DEVICE_TEST_TASK_13` — hardcoded banner unit | **(a) doc** | `docs/DEVICE_TEST_TASK_13.md` | `LEVELPLAY_BANNER_AD_UNIT` |
| 14 | `DEVICE_TEST_CHECKLIST` — hardcoded banner unit | **(a) doc** | `docs/DEVICE_TEST_CHECKLIST.md` | dart-define name |
| 15 | `RELEASE_NOTES_PHASE6` #2 — hardcoded banner unit | **(a) doc** | `docs/RELEASE_NOTES_PHASE6.md` | dart-define name |
| 16 | `ADS_README` #12 (duplicate class) — caps behavior | **(a) doc** | Same as row 3 | — |
| 17 | `MONETIZATION_BLUEPRINT` “every 3rd tap” | **(a) doc** | *no change* — **PARTIAL** kept; rotator is authoritative | Code: `channel_tap_ad_rotator.dart` |
| 18 | `ADS_SETUP` #3 channel tap Unity path | **(a) doc** | `docs/ADS_SETUP.md` | LevelPlay A/B slots only |

**Also fixed (MISSING → doc, not counted in DRIFT=18):**

| Item | Decision | File |
|------|----------|------|
| `PHASE5` #4 `ServerCapClient.check()` | **(a) doc** | `PHASE5_SECURITY.md` §5.3 already uses `ServerCapService.allowsPlacement()` |

**Verification:**

```bash
rg 'znewe3rrge3dh03f|serverCapBaseUrl|ServerCapClient\.check' docs/ --glob '!DRIFT_REPORT.md'
# Expect no matches outside DRIFT_REPORT.md
```

`docs/DRIFT_REPORT.md` status column: all **DRIFT** rows marked **[RESOLVED]** in summary below.
