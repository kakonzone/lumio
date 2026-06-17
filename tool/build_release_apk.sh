#!/usr/bin/env bash
# One release APK (default) — same secrets.json as flutter run.
#
# Default BUILD_APK_MODE=split:
#   • TWO APKs: armeabi-v7a (32-bit) + arm64-v8a (64-bit) — smaller per device
#   • Install only the file that matches the phone (see build/app/outputs/flutter-apk/)
#
# Other modes: BUILD_APK_MODE=fat | universal | arm64
#   fat = one APK with both ABIs (~45–55 MB download)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SECRETS_FILE="${SECRETS_FILE:-$ROOT/secrets.json}"
BUILD_APK_MODE="${BUILD_APK_MODE:-split}"
MAX_APK_MB="${MAX_APK_MB:-35}"
MIN_APK_MB="${MIN_APK_MB:-20}"

require_secret() {
  local key="$1"
  local value
  value="$(python3 - "$SECRETS_FILE" "$key" <<'PY'
import json, sys
path, key = sys.argv[1], sys.argv[2]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    print(str(data.get(key, "")).strip())
except Exception:
    print("")
PY
)"
  if [[ -z "$value" || "$value" == "__MISSING__" ]]; then
    echo "ERROR: secrets.json missing required key: $key (see secrets.json.template)" >&2
    exit 1
  fi
}

cap_local_only() {
  local v
  v="$(python3 - "$SECRETS_FILE" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)
print(str(d.get("CAP_LOCAL_ONLY_MODE", "false")).lower())
PY
)"
  [[ "$v" == "true" || "$v" == "1" ]]
}

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "ERROR: $SECRETS_FILE missing." >&2
  echo "       cp secrets.json.template secrets.json" >&2
  exit 1
fi

if ! python3 -m json.tool "$SECRETS_FILE" > /dev/null 2>&1; then
  echo "ERROR: $SECRETS_FILE is not valid JSON." >&2
  exit 1
fi

cap_url="$(python3 - "$SECRETS_FILE" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    print(str(json.load(f).get("CAP_BASE_URL", "")).strip())
PY
)"

if ! cap_local_only && [[ -z "$cap_url" ]]; then
  echo "ERROR: CAP_BASE_URL empty and CAP_LOCAL_ONLY_MODE not true." >&2
  exit 1
fi

require_secret APPWRITE_PROJECT_ID
require_secret APPWRITE_ENDPOINT
require_secret APPWRITE_DATABASE_ID
require_secret APPWRITE_CHANNELS_COLLECTION_ID
require_secret APPWRITE_APP_CONFIG_COLLECTION_ID
# SGP Lumio (global_config, special_links) — optional; code defaults apply if omitted
# require_secret APPWRITE_MAIN_PROJECT_ID
# require_secret APPWRITE_MAIN_ENDPOINT
# require_secret APPWRITE_MAIN_DATABASE_ID

require_secret LEVELPLAY_APP_KEY
require_secret LEVELPLAY_INTERSTITIAL_AD_UNIT
require_secret LEVELPLAY_BANNER_AD_UNIT
require_secret PRIVACY_POLICY_URL
require_secret TERMS_OF_SERVICE_URL
require_secret CONTACT_EMAIL
require_secret STREAM_TOKEN_BASE_URL

if ! cap_local_only; then
  require_secret CAP_BASE_URL
  require_secret CAP_HMAC_KEY
fi

has_adsterra="$(python3 - "$SECRETS_FILE" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)
def s(k):
    return str(d.get(k, "")).strip()
ok = bool(s("ADSTERRA_DIRECT_LINK") or s("ADSTERRA_DIRECT_LINKS") or s("ADSTERRA_SMARTLINK_URL"))
for a, b in [
    ("ADSTERRA_POPUNDER_SCRIPT_URL", "ADSTERRA_POPUNDER_BASE_URL"),
    ("ADSTERRA_NATIVE_INVOKE_URL", "ADSTERRA_NATIVE_BASE_URL"),
    ("ADSTERRA_BANNER728_INVOKE_URL", "ADSTERRA_BANNER728_BASE_URL"),
]:
    if s(a) and s(b):
        ok = True
print("yes" if ok else "no")
PY
)"
if [[ "$has_adsterra" != "yes" ]]; then
  echo "ERROR: secrets.json needs Adsterra zones. See docs/SECRETS.md" >&2
  exit 1
fi

echo "==> Validating monetization keys (no template / example.com)..."
python3 - "$SECRETS_FILE" <<'PY' || exit 1
import json, sys, re

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    d = json.load(f)

def s(k):
    return str(d.get(k, "")).strip()

def bad_secret(v: str) -> bool:
    t = v.lower()
    if not t:
        return False
    if "আপনার" in v or "your_" in t or "placeholder" in t:
        return True
    if "example.com" in t or "example.org" in t:
        return True
    return False

def bad_url(v: str) -> bool:
    t = v.lower()
    if not t:
        return False
    if "example.com" in t or "example.org" in t or "placeholder" in t:
        return True
    return False

errors = []
for key in (
    "LEVELPLAY_APP_KEY",
    "LEVELPLAY_INTERSTITIAL_AD_UNIT",
    "LEVELPLAY_BANNER_AD_UNIT",
):
    v = s(key)
    if v and bad_secret(v):
        errors.append(f"{key} still has template text — set your real LevelPlay value")

for key in ("ADSTERRA_DIRECT_LINK", "ADSTERRA_DIRECT_LINKS", "ADSTERRA_SMARTLINK_URL", "ADSTERRA_SMARTLINKS"):
    v = s(key)
    if not v:
        continue
    parts = [p.strip() for p in v.split("|") if p.strip()]
    if any(bad_url(p) for p in parts):
        errors.append(f"{key} uses example.com / placeholder — paste real Adsterra URLs")

lp_ok = all(s(k) and not bad_secret(s(k)) for k in (
    "LEVELPLAY_APP_KEY",
    "LEVELPLAY_INTERSTITIAL_AD_UNIT",
    "LEVELPLAY_BANNER_AD_UNIT",
))
ad_urls = []
for k in ("ADSTERRA_DIRECT_LINK", "ADSTERRA_DIRECT_LINKS", "ADSTERRA_SMARTLINK_URL", "ADSTERRA_SMARTLINKS"):
    v = s(k)
    if not v:
        continue
    ad_urls.extend(p.strip() for p in v.split("|") if p.strip())
ad_ok = any(u and not bad_url(u) for u in ad_urls)

def webview_pair(script_k, base_k):
    return s(script_k) and s(base_k) and not bad_url(s(script_k)) and not bad_url(s(base_k))

wv_ok = any(
    webview_pair(a, b)
    for a, b in (
        ("ADSTERRA_POPUNDER_SCRIPT_URL", "ADSTERRA_POPUNDER_BASE_URL"),
        ("ADSTERRA_NATIVE_INVOKE_URL", "ADSTERRA_NATIVE_BASE_URL"),
        ("ADSTERRA_BANNER728_INVOKE_URL", "ADSTERRA_BANNER728_BASE_URL"),
    )
)

if errors:
    print("ERROR: secrets.json monetization invalid:", file=sys.stderr)
    for e in errors:
        print(f"  • {e}", file=sys.stderr)
    print("", file=sys.stderr)
    print("  Edit secrets.json with real keys from IronSource + Adsterra dashboards.", file=sys.stderr)
    print("  See docs/SECRETS.md", file=sys.stderr)
    sys.exit(1)

if not lp_ok and not ad_ok and not wv_ok:
    print("ERROR: No usable monetization stack in secrets.json.", file=sys.stderr)
    print("  Set LevelPlay (LEVELPLAY_*) and/or real Adsterra direct links / WebView zones.", file=sys.stderr)
    sys.exit(1)

print("OK: monetization keys look real (LevelPlay=%s Adsterra=%s WebView=%s)" % (lp_ok, ad_ok, wv_ok))
PY

# Legacy env aliases → BUILD_APK_MODE
if [[ "${BUILD_ARM64_ONLY:-}" == "true" || "${BUILD_ARM64_ONLY:-}" == "1" ]]; then
  BUILD_APK_MODE=arm64
fi
if [[ "${BUILD_SPLIT_ABI:-}" == "true" || "${BUILD_SPLIT_ABI:-}" == "1" ]]; then
  BUILD_APK_MODE=split
fi
if [[ "${BUILD_LEGACY_ABI:-}" == "true" || "${BUILD_LEGACY_ABI:-}" == "1" ]]; then
  BUILD_APK_MODE=split
fi

SPLIT_ARGS=()
TARGET_PLATFORMS=""
case "$BUILD_APK_MODE" in
  fat)
    TARGET_PLATFORMS="android-arm,android-arm64"
    echo "==> ONE FAT APK: 32-bit + 64-bit — all features, ads, security"
    echo "    Download target: ${MIN_APK_MB}–${MAX_APK_MB} MB | storage after install: ≤80 MB"
    ;;
  universal)
    TARGET_PLATFORMS="android-arm"
    echo "==> ONE APK (32-bit compat): smaller download ~25–38 MB, not native 64-bit"
    ;;
  arm64)
    TARGET_PLATFORMS="android-arm64"
    echo "==> ONE APK: arm64-v8a only (recommended sideload — smallest single file)"
    echo "    Target download: ${MIN_APK_MB}–${MAX_APK_MB} MB"
    ;;
  split)
    TARGET_PLATFORMS="android-arm,android-arm64"
    SPLIT_ARGS=(--split-per-abi)
    echo "==> TWO APKs (default): 32-bit + 64-bit — install the one for your phone"
    echo "    Target per APK: ${MIN_APK_MB}–${MAX_APK_MB} MB (arm64 usually smallest)"
    ;;
  *)
    echo "ERROR: unknown BUILD_APK_MODE=$BUILD_APK_MODE (universal|arm64|split|fat)" >&2
    exit 1
    ;;
esac

SYMBOLS_DIR="${SYMBOLS_DIR:-$ROOT/build/debug-info}"

flutter pub get

echo "==> Sync channel assets & Android HTTP allowlist"
python3 tool/gen_network_security_config.py
if [[ -f tool/user_playlist.m3u ]]; then
  python3 tool/ingest_user_playlist.py
fi

EXTRA_DEFINES=(
  --dart-define-from-file="$SECRETS_FILE"
  --dart-define=LUMIO_SIDELOAD_DEV=true
)
if cap_local_only; then
  EXTRA_DEFINES+=(--dart-define=CAP_LOCAL_ONLY_MODE=true)
fi
echo "==> Android 5.0 Lollipop (API 21)+ | mode=$BUILD_APK_MODE"

echo "==> flutter build apk --release (mode=$BUILD_APK_MODE)"
flutter build apk \
  --release \
  "${SPLIT_ARGS[@]}" \
  --target-platform="$TARGET_PLATFORMS" \
  --obfuscate \
  --split-debug-info="$SYMBOLS_DIR" \
  --tree-shake-icons \
  "${EXTRA_DEFINES[@]}" \
  "$@"

OUT_DIR="$ROOT/build/app/outputs/flutter-apk"

# Verify APK signature (fail if debug-signed in production)
echo "==> Verifying APK signature..."
PRIMARY_APK=""
case "$BUILD_APK_MODE" in
  fat|universal|arm64)
    PRIMARY_APK="$OUT_DIR/app-release.apk"
    ;;
  split)
    PRIMARY_APK="$OUT_DIR/app-arm64-v8a-release.apk"
    ;;
esac

if [[ -f "$PRIMARY_APK" ]]; then
  CERT_INFO=$(apksigner verify --print-certs "$PRIMARY_APK" 2>&1 || true)

  # Check if certificate issuer indicates Android Debug
  if echo "$CERT_INFO" | grep -qi "android debug"; then
    echo "ERROR: APK is debug-signed! This is a security vulnerability." >&2
    echo "The APK must be release-signed for production builds." >&2
    echo "Run with LUMIO_LOCAL_SIZE_CHECK=true only for local size audits." >&2
    exit 1
  fi

  # Additional check: issuer CN=Android Debug
  if echo "$CERT_INFO" | grep -qi "CN=Android Debug"; then
    echo "ERROR: APK is debug-signed! This is a security vulnerability." >&2
    echo "The APK must be release-signed for production builds." >&2
    echo "Run with LUMIO_LOCAL_SIZE_CHECK=true only for local size audits." >&2
    exit 1
  fi

  echo "OK: APK is properly signed (not Android Debug)"
else
  echo "WARNING: Could not verify signature - APK not found at $PRIMARY_APK" >&2
fi
PRIMARY_APK=""

case "$BUILD_APK_MODE" in
  fat|universal|arm64)
    PRIMARY_APK="$OUT_DIR/app-release.apk"
    if [[ -f "$PRIMARY_APK" ]]; then
      cp -f "$PRIMARY_APK" "$OUT_DIR/lumio-release.apk"
      echo ""
      echo "==> Share/install ONE file (all supported CPUs in this build):"
      ls -lh "$OUT_DIR/lumio-release.apk"
    fi
    ;;
  split)
    echo ""
    echo "==> Install ONE of these (match your phone CPU):"
    echo "    64-bit (most phones): app-arm64-v8a-release.apk"
    echo "    32-bit (older phones): app-armeabi-v7a-release.apk"
  ;;
esac

echo ""
ls -lh "$OUT_DIR"/*-release.apk 2>/dev/null || ls -lh "$OUT_DIR"/*.apk 2>/dev/null || true

echo ""
echo "==> APK sizes (target ${MIN_APK_MB}–${MAX_APK_MB} MB per install file):"
over_max=0
for apk in "$OUT_DIR"/*-release.apk "$OUT_DIR"/lumio-release.apk; do
  [[ -f "$apk" ]] || continue
  apk_mb=$(du -m "$apk" | cut -f1)
  echo "    $(basename "$apk"): ${apk_mb} MB"
  if [[ "$apk_mb" -gt "$MAX_APK_MB" ]]; then
    over_max=1
  fi
done
if [[ "$over_max" -eq 1 ]]; then
  echo "WARN: Some APKs exceed ${MAX_APK_MB} MB — try BUILD_APK_MODE=arm64 or FIREBASE_ENABLED=false; see docs/ANDROID_SIZE_AND_PERFORMANCE.md"
elif [[ -f "$OUT_DIR/app-arm64-v8a-release.apk" ]]; then
  echo "TIP: For WhatsApp share, prefer app-arm64-v8a-release.apk or BUILD_APK_MODE=arm64"
fi

echo ""
echo "Same full app as: flutter run --dart-define-from-file=secrets.json"
echo "After install: AppStorageGuard keeps app DATA cache ≤~22 MB (total storage target ≤80 MB)"
echo "Unsupported CPU/Android version: install fails — user needs a supported device"
echo "Symbols: $SYMBOLS_DIR"
