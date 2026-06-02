# Network Security Audit (Phase 9)

## Scope

- File: `android/app/src/main/res/xml/network_security_config.xml`
- Goal: reduce cleartext traffic surface and keep only temporary exceptions.

## Reduction summary

- Total `<domain includeSubdomains="true">` entries:
  - Before: `202`
  - After: `19`
- Cleartext exception entries:
  - Before: very broad (legacy mixed list)
  - After: `6` temporary domains
- Reduction is greater than 70%.

## Remaining cleartext exceptions

| Domain | Reason | Migration target date |
|---|---|---|
| `starshare.net` | Legacy upstream stream host still served as HTTP by provider | 2026-06-15 |
| `198.195.239.50` | Legacy direct-origin stream host | 2026-06-15 |
| `103.161.153.165` | Legacy direct-origin stream host | 2026-06-15 |
| `103.175.73.12` | Legacy direct-origin stream host | 2026-06-15 |
| `103.159.180.34` | Legacy direct-origin stream host | 2026-06-15 |
| `151.80.18.177` | Legacy direct-origin stream host | 2026-06-15 |

## Enforcement

- Default is HTTPS-only.
- Token endpoint for signed stream URLs must be HTTPS-only.
- New cleartext host additions require explicit audit update in this file.
