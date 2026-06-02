#!/usr/bin/env bash
# Scan repo for leaked secrets. Writes SECRETS_REPORT.md at repo root.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

REPORT="${1:-SECRETS_REPORT.md}"
OUT_JSON="${2:-gitleaks_report.json}"

echo "# Secrets audit report" > "$REPORT"
echo "" >> "$REPORT"
echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$REPORT"
echo "" >> "$REPORT"

if command -v gitleaks >/dev/null 2>&1; then
  echo "==> gitleaks detect"
  if gitleaks detect --source . --report-format json --report-path "$OUT_JSON" 2>/dev/null; then
    echo "## gitleaks" >> "$REPORT"
    echo "No leaks detected." >> "$REPORT"
  else
    echo "## gitleaks" >> "$REPORT"
    echo "Findings written to \`$OUT_JSON\`. Review and rotate any exposed credentials." >> "$REPORT"
  fi
else
  echo "## gitleaks" >> "$REPORT"
  echo "Not installed. Install: https://github.com/gitleaks/gitleaks" >> "$REPORT"
fi

echo "" >> "$REPORT"
echo "## Pattern scan (tracked files)" >> "$REPORT"

PATTERNS=(
  'BEGIN (RSA |OPENSSH )?PRIVATE KEY'
  'api[_-]?key\s*=\s*["\x27][^"\x27]{8,}'
  'password\s*=\s*["\x27][^"\x27]+'
  'bearer\s+[a-zA-Z0-9._-]{20,}'
  'sk_live_[a-zA-Z0-9]+'
)

FOUND=0
for pat in "${PATTERNS[@]}"; do
  if rg -n --hidden --glob '!.git' --glob '!build' --glob '!*.lock' -i "$pat" . 2>/dev/null | head -20 >> "$REPORT"; then
    FOUND=1
  fi
done

if [[ "$FOUND" -eq 0 ]]; then
  echo "No high-risk patterns in quick scan." >> "$REPORT"
fi

echo "" >> "$REPORT"
echo "## Dart-define hygiene" >> "$REPORT"
echo "Release must use CI secrets only (see \`NEW_DART_DEFINES.env\`, \`docs/SECRETS.md\`)." >> "$REPORT"
echo "Never commit \`secrets.json\` or \`.env\` with live keys." >> "$REPORT"

echo "Report: $REPORT"
