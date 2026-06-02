# Phase 10 — Task 4 verification (secrets audit)

## Run audit (no history rewrite)

```bash
chmod +x scripts/audit_secrets.sh
./scripts/audit_secrets.sh
```

Review `gitleaks_report.json` or `secrets_audit.txt`.

## .gitignore

```bash
git check-ignore -v secrets.json key.properties android/local.properties google-services.json
```

## gitleaks config

```bash
test -f .gitleaks.toml && echo OK
```

## Purge script

`scripts/purge_history.sh` prints instructions only — **not executed** unless ops approves.

## Post-rotation

After rotating keys at providers, re-run audit and document zero findings (or listed exceptions) here.
