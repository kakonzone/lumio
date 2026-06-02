#!/usr/bin/env bash
# Scan lib/ + assets for http:// stream URLs; suggest HTTPS upgrades.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOLDOUTS="$ROOT/docs/HTTP_HOLDOUTS.md"
mkdir -p "$ROOT/docs"

echo "# HTTP stream holdouts" > "$HOLDOUTS"
echo "" >> "$HOLDOUTS"
echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$HOLDOUTS"
echo "" >> "$HOLDOUTS"
echo "Domains below require cleartext in \`network_security_config.xml\` until migrated." >> "$HOLDOUTS"
echo "" >> "$HOLDOUTS"

scan() {
  local path="$1"
  if [[ ! -e "$path" ]]; then return; fi
  grep -rhoE 'http://[a-zA-Z0-9._:-]+' "$path" 2>/dev/null \
    | sed 's|http://||' | cut -d/ -f1 | sort -u
}

{
  scan "$ROOT/lib"
  scan "$ROOT/assets"
} | sort -u | while read -r host; do
  [[ -z "$host" ]] && continue
  echo "- \`$host\`" >> "$HOLDOUTS"
done

echo "" >> "$HOLDOUTS"
echo "## lib/ matches" >> "$HOLDOUTS"
echo '```' >> "$HOLDOUTS"
grep -rn 'http://' "$ROOT/lib" --include '*.dart' 2>/dev/null | head -80 >> "$HOLDOUTS" || true
echo '```' >> "$HOLDOUTS"

echo "Wrote $HOLDOUTS"
