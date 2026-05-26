# Phase 8 — Security Hardening + Operability (2026-05-26)

Maps to `docs/FULL_APPLICATION_AUDIT.md` Risk Register (Section 16).

## Completed tasks

| Task | Risk | Summary | Evidence |
|------|------|---------|----------|
| T1 | R01 Critical | JWT removed from source; `TOFFEE_SUBSCRIBER_TOKEN` dart-define | `test/security/no_secrets_in_lib_test.dart` pass; `grep eyJ lib/` clean |
| T2 | R03 High | Single `ToffeeHeaders` + unit test | `test/network/toffee_headers_test.dart` |
| T3 | R04 High | Cleartext audit + policy; removed debug ingest URL | `docs/CLEARTEXT_AUDIT.txt`, `docs/CLEARTEXT_POLICY.md` |
| T4 | R05 High | Firebase Crashlytics wired (gated on init) | `test/services/crashlytics_bootstrap_test.dart` |
| T5 | R06 High | GitHub Actions CI + manual release APK workflow | `.github/workflows/ci.yml` |
| T6 | R09 High | `.gitignore` tightening, branch policy, baseline tag | `docs/BRANCH_POLICY.md`, tag `pre-phase8-baseline` |
| T7 | R16 Medium | Shelf server → `bin/dev_server.dart` | `docs/SERVER_REMOVAL.md` |
| T8 | R07 Medium | `scripts/firebase_precheck.sh` + preflight | `docs/FIREBASE_PRECHECK.md` |
| T9 | R10 Medium | Dismissible ADS DISABLED debug overlay | `test/config/ads_disabled_banner_test.dart` |
| T10 | — | This document | — |

**Manual follow-ups:** Rotate Toffee token at provider; run `docs/GIT_HISTORY_REWRITE.md` on a feature branch.

## Post-Phase-8 risk register (selected)

| ID | Severity (before → after) | Status |
|----|---------------------------|--------|
| R01 | Critical → **Mitigated** | Source clean; history rewrite + rotation pending human |
| R02 | Critical | **Open** — IPTV legal/sourcing |
| R03 | High → **Low** | Header deduped |
| R04 | High → **Medium** | Policy + allowlist; IPTV HTTP remains |
| R05 | High → **Low** | Crashlytics wired; needs `google-services.json` on device |
| R06 | High → **Low** | CI added |
| R07 | Medium → **Low** | Precheck script |
| R09 | High → **Medium** | Policy + tag; full WIP commit history ongoing |
| R10 | Medium → **Low** | Debug banner |
| R16 | Medium → **Resolved** | Server out of `lib/` |

## Readiness buckets (audit grades)

| Dimension | Pre-Phase-8 | Post-Phase-8 |
|-----------|-------------|--------------|
| Security engineering | C+ | **B** |
| Operability | D+ | **B-** |
| Store / legal readiness | F | **D** (IPTV legal still blocks) |

## Phase 9 backlog

- God-file decomposition (`player_screen.dart`, `app_provider.dart`)
- i18n (`intl` + ARB)
- Accessibility (`Semantics`)
- iOS ship path QA
- Analyzer warning cleanup (R19)
- Play Integrity Option B (R18)
