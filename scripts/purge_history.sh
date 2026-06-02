#!/usr/bin/env bash
# DO NOT RUN without explicit approval — rewrites git history for all clones.
#
# Prerequisites:
#   pip install git-filter-repo
#   cp replacements.txt.example replacements.txt  # fill old→REMOVED pairs
#
# Usage (documented only):
#   git filter-repo --replace-text replacements.txt
#   git push --force-with-lease origin main
#
set -euo pipefail

cat <<'EOF'
History purge is MANUAL. Steps:
1. Back up repo: git clone --mirror <url> lumio-backup.git
2. Create replacements.txt (one line per secret):
     literal:OLD_SECRET==>***REMOVED***
3. Run: git filter-repo --replace-text replacements.txt
4. Notify all developers to re-clone
5. Rotate every exposed credential (docs/CREDENTIAL_ROTATION.md)
EOF

exit 1
