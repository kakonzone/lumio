#!/usr/bin/env python3
"""Upload release APK to Appwrite Storage and patch app_version document.

Environment:
  APPWRITE_ENDPOINT       e.g. https://sgp.cloud.appwrite.io/v1
  APPWRITE_PROJECT_ID     SGP Lumio project id
  APPWRITE_API_KEY        Server API key (storage + databases write)
  APPWRITE_BUCKET_ID      default: lumio.apk
  APPWRITE_DATABASE_ID    default: iptv_main
  APPWRITE_COLLECTION_ID  default: app_version
  APPWRITE_VERSION_DOC_ID fixed document id
  APP_VERSION             semver from pubspec (e.g. 1.0.3)
  APK_PATH                path to built APK
  FORCE_UPDATE            optional, default false
"""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import requests

ENDPOINT = os.environ.get("APPWRITE_ENDPOINT", "").rstrip("/")
PROJECT_ID = os.environ.get("APPWRITE_PROJECT_ID", "").strip()
API_KEY = os.environ.get("APPWRITE_API_KEY", "").strip()
BUCKET_ID = os.environ.get("APPWRITE_BUCKET_ID", "lumio.apk").strip()
DATABASE_ID = os.environ.get("APPWRITE_DATABASE_ID", "iptv_main").strip()
COLLECTION_ID = os.environ.get("APPWRITE_COLLECTION_ID", "app_version").strip()
DOC_ID = os.environ.get("APPWRITE_VERSION_DOC_ID", "").strip()
APP_VERSION = os.environ.get("APP_VERSION", "").strip()
APK_PATH = Path(os.environ.get("APK_PATH", "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"))
FORCE_UPDATE = os.environ.get("FORCE_UPDATE", "false").strip().lower() in ("1", "true", "yes")


def _headers() -> dict[str, str]:
    return {
        "X-Appwrite-Project": PROJECT_ID,
        "X-Appwrite-Key": API_KEY,
    }


def _fail(msg: str) -> None:
    print(f"::error::{msg}", file=sys.stderr)
    raise SystemExit(1)


def upload_apk() -> str:
    if not APK_PATH.is_file():
        _fail(f"APK not found: {APK_PATH}")
    url = f"{ENDPOINT}/storage/buckets/{BUCKET_ID}/files"
    with APK_PATH.open("rb") as apk:
        resp = requests.post(
            url,
            headers=_headers(),
            files={
                "file": (APK_PATH.name, apk, "application/vnd.android.package-archive"),
            },
            data={"fileId": "unique()"},
            timeout=600,
        )
    if resp.status_code not in (200, 201):
        _fail(f"Storage upload failed HTTP {resp.status_code}: {resp.text[:500]}")
    body = resp.json()
    file_id = body.get("$id") or body.get("id")
    if not file_id:
        _fail(f"Storage upload OK but no file id in response: {body}")
    print(f"Uploaded {APK_PATH.name} → file_id={file_id}")
    return str(file_id)


def patch_version_doc(file_id: str) -> None:
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")
    url = (
        f"{ENDPOINT}/databases/{DATABASE_ID}/collections/"
        f"{COLLECTION_ID}/documents/{DOC_ID}"
    )
    payload = {
        "data": {
            "version": APP_VERSION,
            "apk_file_id": file_id,
            "updated_at": timestamp,
            "force_update": FORCE_UPDATE,
        }
    }
    resp = requests.patch(
        url,
        headers={**_headers(), "Content-Type": "application/json"},
        json=payload,
        timeout=60,
    )
    if resp.status_code not in (200, 201):
        _fail(f"Document PATCH failed HTTP {resp.status_code}: {resp.text[:500]}")
    print(f"Patched {COLLECTION_ID}/{DOC_ID} version={APP_VERSION} apk_file_id={file_id}")


def main() -> int:
    missing = [
        name
        for name, val in (
            ("APPWRITE_ENDPOINT", ENDPOINT),
            ("APPWRITE_PROJECT_ID", PROJECT_ID),
            ("APPWRITE_API_KEY", API_KEY),
            ("APPWRITE_VERSION_DOC_ID", DOC_ID),
            ("APP_VERSION", APP_VERSION),
        )
        if not val
    ]
    if missing:
        _fail(f"Missing env: {', '.join(missing)}")

    file_id = upload_apk()
    patch_version_doc(file_id)

    github_env = os.environ.get("GITHUB_ENV")
    if github_env:
        with open(github_env, "a", encoding="utf-8") as fh:
            fh.write(f"APK_FILE_ID={file_id}\n")

    print(json.dumps({"file_id": file_id, "version": APP_VERSION}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
