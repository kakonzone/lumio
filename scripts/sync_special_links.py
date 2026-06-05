#!/usr/bin/env python3
"""Upsert special_links documents from data/special_links.json into Appwrite.

Only creates or updates documents listed in the JSON — never deletes others.

Environment variables (required unless noted):
  APPWRITE_ENDPOINT
  APPWRITE_PROJECT_ID
  APPWRITE_API_KEY
  APPWRITE_DATABASE_ID       default: iptv_main
  SPECIAL_LINKS_JSON         default: data/special_links.json
  SPECIAL_LINKS_COLLECTION   default: special_links
"""
from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path
from typing import Any

import requests

ROOT = Path(__file__).resolve().parent.parent
ENDPOINT = os.environ.get("APPWRITE_ENDPOINT", "").rstrip("/")
PROJECT_ID = os.environ.get("APPWRITE_PROJECT_ID", "").strip()
API_KEY = os.environ.get("APPWRITE_API_KEY", "").strip()
DATABASE_ID = os.environ.get("APPWRITE_DATABASE_ID", "iptv_main")
COLLECTION_ID = os.environ.get("SPECIAL_LINKS_COLLECTION", "special_links")
JSON_PATH = Path(os.environ.get("SPECIAL_LINKS_JSON", str(ROOT / "data" / "special_links.json")))

BACKOFF_STEPS = [10, 20, 40]

ALLOWED_FIELDS = (
    "name",
    "stream_url",
    "logo_url",
    "group_title",
    "category",
    "is_active",
    "sort_order",
)

_PLACEHOLDER_MARKERS = (
    "তোমার",
    "your_",
    "your ",
    "api_key",
    "api key",
    "placeholder",
    "<set>",
    "xxx",
)


def _validate_api_key(key: str) -> str | None:
    """Return error message when key is missing/invalid; None when OK."""
    if not key:
        return "APPWRITE_API_KEY is empty"
    try:
        key.encode("ascii")
    except UnicodeEncodeError:
        return (
            "APPWRITE_API_KEY must be ASCII only (paste the real key from "
            "Appwrite Console → API Keys — not Bengali placeholder text)"
        )
    lower = key.lower()
    if len(key) < 20 or any(m in lower for m in _PLACEHOLDER_MARKERS):
        return (
            "APPWRITE_API_KEY looks like a placeholder. Copy the real key from "
            "Appwrite Console → Project → API Keys"
        )
    return None


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


def get_document(doc_id: str) -> bool:
    path = (
        f"/databases/{DATABASE_ID}/collections/{COLLECTION_ID}/documents/{doc_id}"
    )
    resp = _request("GET", path)
    if resp.status_code == 404:
        return False
    if resp.status_code >= 400:
        body = resp.text
        if resp.status_code == 401 and "not accessible in this region" in body:
            raise RuntimeError(
                f"GET {doc_id} failed (401): wrong APPWRITE_ENDPOINT for this project. "
                f"Use the regional URL from Appwrite Console (e.g. "
                f"https://sgp.cloud.appwrite.io/v1). Response: {body}"
            )
        raise RuntimeError(f"GET {doc_id} failed ({resp.status_code}): {body}")
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
    path = (
        f"/databases/{DATABASE_ID}/collections/{COLLECTION_ID}/documents/{doc_id}"
    )
    resp = _request("PATCH", path, json_body={"data": data})
    if resp.status_code >= 400:
        raise RuntimeError(f"PATCH {doc_id} failed ({resp.status_code}): {resp.text}")


def load_items() -> list[dict[str, Any]]:
    if not JSON_PATH.is_file():
        raise FileNotFoundError(f"JSON not found: {JSON_PATH}")
    with JSON_PATH.open(encoding="utf-8") as fh:
        raw = json.load(fh)
    if not isinstance(raw, list):
        raise ValueError("special_links.json must be a JSON array")
    return raw


def row_payload(item: dict[str, Any]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key in ALLOWED_FIELDS:
        if key not in item:
            continue
        out[key] = item[key]
    if "name" not in out or not str(out["name"]).strip():
        raise ValueError("each item requires non-empty name")
    if "stream_url" not in out or not str(out["stream_url"]).strip():
        raise ValueError("each item requires non-empty stream_url")
    if "category" not in out:
        out["category"] = "Sports"
    if "is_active" not in out:
        out["is_active"] = True
    if "sort_order" not in out:
        out["sort_order"] = 0
    return out


def main() -> int:
    if not ENDPOINT or not PROJECT_ID:
        print(
            "ERROR: APPWRITE_ENDPOINT and APPWRITE_PROJECT_ID are required",
            file=sys.stderr,
        )
        return 1
    key_err = _validate_api_key(API_KEY)
    if key_err:
        print(f"ERROR: {key_err}", file=sys.stderr)
        return 1

    items = load_items()
    parsed = len(items)
    created = 0
    updated = 0
    failed = 0

    print(
        f"[config] endpoint={ENDPOINT} project={PROJECT_ID} "
        f"db={DATABASE_ID} collection={COLLECTION_ID} file={JSON_PATH}"
    )

    for item in items:
        doc_id = str(item.get("id", "")).strip()
        if not doc_id:
            print("[skip] item missing id")
            failed += 1
            continue
        try:
            data = row_payload(item)
            if get_document(doc_id):
                patch_document(doc_id, data)
                updated += 1
                print(f"[updated] {doc_id} — {data['name']}")
            else:
                create_document(doc_id, data)
                created += 1
                print(f"[created] {doc_id} — {data['name']}")
        except Exception as exc:
            print(f"[failed] {doc_id}: {exc}")
            failed += 1

    print("═" * 50)
    print("SYNC SUMMARY")
    print(f"  total parsed : {parsed}")
    print(f"  created      : {created}")
    print(f"  updated      : {updated}")
    print(f"  failed       : {failed}")
    print("═" * 50)

    return 0 if failed == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
