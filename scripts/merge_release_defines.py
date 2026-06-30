#!/usr/bin/env python3
"""Merge ci_defines.json with CI/GitHub secrets into secrets.json for release APK.

Ensures release builds ship Appwrite endpoints, Adsterra WebView zones, Monetag zones,
and ADS_ENABLED=true while overlaying sensitive keys from the environment.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CI_DEFINES = ROOT / "ci_defines.json"
OUT = ROOT / "secrets.json"

# Sensitive or environment-specific keys — non-empty env values override ci_defines.
SECRET_ENV_KEYS = (
    "LEVELPLAY_APP_KEY",
    "LEVELPLAY_INTERSTITIAL_AD_UNIT",
    "LEVELPLAY_REWARDED_AD_UNIT",
    "LEVELPLAY_BANNER_AD_UNIT",
    "ADSTERRA_DL_1",
    "ADSTERRA_DL_2",
    "ADSTERRA_DL_3",
    "ADSTERRA_DL_4",
    "ADSTERRA_DIRECT_LINK",
    "ADSTERRA_DIRECT_LINKS",
    "ADSTERRA_SMARTLINK_URL",
    "ADSTERRA_SMARTLINKS",
    "ADSTERRA_NATIVE_INVOKE_URL",
    "ADSTERRA_NATIVE_CONTAINER_ID",
    "ADSTERRA_NATIVE_BASE_URL",
    "ADSTERRA_POPUNDER_SCRIPT_URL",
    "ADSTERRA_POPUNDER_BASE_URL",
    "ADSTERRA_SOCIAL_SCRIPT_URL",
    "ADSTERRA_SOCIAL_BASE_URL",
    "ADSTERRA_BANNER728_INVOKE_URL",
    "ADSTERRA_BANNER728_CONTAINER_ID",
    "ADSTERRA_BANNER728_BASE_URL",
    "CAP_BASE_URL",
    "CAP_HMAC_KEY",
    "TOFFEE_SUBSCRIBER_TOKEN",
    "STREAM_TOKEN_BASE_URL",
    "SSL_PIN_PRIMARY",
    "SSL_PIN_BACKUP",
    "LUMIO_BACKEND_BASE_URL",
    "LUMIO_BACKEND_APP_KEY",
    "GOOGLE_SERVICES_JSON",
    "APPWRITE_ENDPOINT",
    "APPWRITE_PROJECT_ID",
    "APPWRITE_DATABASE_ID",
    "APPWRITE_VERSION_COLLECTION_ID",
    "APPWRITE_VERSION_DOC_ID",
    "APPWRITE_API_KEY",
    "APPWRITE_BUCKET_ID",
)


def main() -> int:
    if not CI_DEFINES.is_file():
        print(f"ERROR: missing {CI_DEFINES}", file=sys.stderr)
        return 1

    with CI_DEFINES.open(encoding="utf-8") as fh:
        data: dict[str, str] = json.load(fh)

    for key in SECRET_ENV_KEYS:
        value = os.environ.get(key, "").strip()
        if value:
            data[key] = value

    # Release APK must always attempt ad init (release mode ignores debug gating).
    data["ADS_ENABLED"] = "true"
    data["CAP_LOCAL_ONLY_MODE"] = data.get("CAP_LOCAL_ONLY_MODE", "true")

    if not str(data.get("CAP_BASE_URL", "")).strip():
        data["CAP_LOCAL_ONLY_MODE"] = "true"

    with OUT.open("w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")

    print(f"Wrote {OUT} ({len(data)} keys, ADS_ENABLED=true, Appwrite+ads from ci_defines)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
