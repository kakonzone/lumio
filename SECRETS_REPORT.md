# Secrets audit report

Generated: 2026-05-28T16:48:41Z

## gitleaks
Not installed. Install: https://github.com/gitleaks/gitleaks

## Pattern scan (tracked files)
No high-risk patterns in quick scan.

## Dart-define hygiene
Release must use CI secrets only (see `NEW_DART_DEFINES.env`, `docs/SECRETS.md`).
Never commit `secrets.json` or `.env` with live keys.
