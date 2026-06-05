#!/usr/bin/env python3
"""Upsert featured_live_events into NYC Appwrite app_config.

Reads assets/data/featured_live_events.json and writes one app_config row so
the app can load World Cup / featured cards from Appwrite (Guests Read).

Environment variables:
  APPWRITE_ENDPOINT                    default: https://nyc.cloud.appwrite.io/v1
  APPWRITE_PROJECT_ID                  default: 191876000995145
  APPWRITE_API_KEY                     required
  APPWRITE_DATABASE_ID                 default: iptv_main
  APPWRITE_APP_CONFIG_COLLECTION_ID    default: app_config
  FEATURED_JSON                        default: assets/data/featured_live_events.json
  FEATURED_DOCUMENT_ID                 default: featured_live_events
  FEATURED_KEY                         default: featured_live_events
"""
from __future__ import annotations

import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests

ROOT = Path(__file__).resolve().parent.parent
ENDPOINT = os.environ.get("APPWRITE_ENDPOINT", "https://nyc.cloud.appwrite.io/v1").rstrip("/")
PROJECT_ID = os.environ.get("APPWRITE_PROJECT_ID", "191876000995145").strip()
API_KEY = os.environ.get("APPWRITE_API_KEY", "").strip()
DATABASE_ID = os.environ.get("APPWRITE_DATABASE_ID", "iptv_main")
COLLECTION_ID = os.environ.get("APPWRITE_APP_CONFIG_COLLECTION_ID", "app_config")
JSON_PATH = Path(
    os.environ.get("FEATURED_JSON", str(ROOT / "assets" / "data" / "featured_live_events.json"))
)
DOCUMENT_ID = os.environ.get("FEATURED_DOCUMENT_ID", "featured_live_events").strip()
ROW_KEY = os.environ.get("FEATURED_KEY", "featured_live_events").strip()

BACKOFF_STEPS = [10, 20, 40]


def _headers() -> dict[str, str]:
    return {
        "Content-Type": "application/json",
        "X-Appwrite-Project": PROJECT_ID,
        "X-Appwrite-Key": API_KEY,
    }


def _request(
    method: str,
    path: str,
    *,
    json_body: dict[str, Any] | None = None,
    backoff_attempt: int = 0,
    retried: bool = False,
) -> requests.Response:
    url = f"{ENDPOINT}{path}"
    try:
        resp = requests.request(
            method,
            url,
            headers=_headers(),
            json=json_body,
            timeout=60,
        )
        if resp.status_code == 429:
            idx = min(backoff_attempt, len(BACKOFF_STEPS) - 1)
            wait = BACKOFF_STEPS[idx]
            print(f"[429] rate limited — sleeping {wait}s (attempt {backoff_attempt + 1})")
            time.sleep(wait)
            return _request(
                method,
                path,
                json_body=json_body,
                backoff_attempt=backoff_attempt + 1,
                retried=retried,
            )
        return resp
    except Exception as exc:
        if not retried:
            print(f"[retry] {exc} — sleeping 2s then retrying once")
            time.sleep(2)
            return _request(
                method,
                path,
                json_body=json_body,
                backoff_attempt=backoff_attempt,
                retried=True,
            )
        raise


def document_exists(doc_id: str) -> bool:
    path = f"/databases/{DATABASE_ID}/collections/{COLLECTION_ID}/documents/{doc_id}"
    resp = _request("GET", path)
    if resp.status_code == 404:
        return False
    if resp.status_code >= 400:
        raise RuntimeError(f"GET {doc_id} failed ({resp.status_code}): {resp.text}")
    return True


def create_document(doc_id: str, data: dict[str, Any]) -> None:
    path = f"/databases/{DATABASE_ID}/collections/{COLLECTION_ID}/documents"
    resp = _request(
        "POST",
        path,
        json_body={"documentId": doc_id, "data": data},
    )
    if resp.status_code >= 400:
        raise RuntimeError(f"POST {doc_id} failed ({resp.status_code}): {resp.text}")


def patch_document(doc_id: str, data: dict[str, Any]) -> None:
    path = f"/databases/{DATABASE_ID}/collections/{COLLECTION_ID}/documents/{doc_id}"
    resp = _request("PATCH", path, json_body={"data": data})
    if resp.status_code >= 400:
        raise RuntimeError(f"PATCH {doc_id} failed ({resp.status_code}): {resp.text}")


def load_payload() -> dict[str, Any]:
    if not JSON_PATH.is_file():
        raise FileNotFoundError(f"JSON not found: {JSON_PATH}")
    with JSON_PATH.open(encoding="utf-8") as fh:
        raw = json.load(fh)
    if not isinstance(raw, dict):
        raise ValueError("featured_live_events.json must be a JSON object")
    return raw


def main() -> int:
    if not ENDPOINT or not PROJECT_ID:
        print(
            "ERROR: APPWRITE_ENDPOINT and APPWRITE_PROJECT_ID are required",
            file=sys.stderr,
        )
        return 1
    if not API_KEY:
        print("ERROR: APPWRITE_API_KEY is required", file=sys.stderr)
        return 1

    payload = load_payload()
    updated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")
    data = {
        "key": ROW_KEY,
        "json_payload": json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
        "updated_at": updated_at,
    }

    print(
        f"[config] endpoint={ENDPOINT} project={PROJECT_ID} "
        f"db={DATABASE_ID} collection={COLLECTION_ID} doc={DOCUMENT_ID} file={JSON_PATH}"
    )

    try:
        if document_exists(DOCUMENT_ID):
            patch_document(DOCUMENT_ID, data)
            print(f"[updated] {DOCUMENT_ID} updated_at={updated_at}")
        else:
            create_document(DOCUMENT_ID, data)
            print(f"[created] {DOCUMENT_ID} updated_at={updated_at}")
    except Exception as exc:
        print(f"[failed] {DOCUMENT_ID}: {exc}", file=sys.stderr)
        return 2

    events = payload.get("events")
    event_count = len(events) if isinstance(events, list) else 0
    print(f"featured_live_events OK — events={event_count} updated_at={updated_at}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
