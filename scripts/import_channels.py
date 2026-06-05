#!/usr/bin/env python3
"""Import M3U playlist channels into Appwrite `channels` collection.

Environment variables:
  APPWRITE_ENDPOINT          default: https://nyc.cloud.appwrite.io/v1 (legacy channels project)
  APPWRITE_PROJECT_ID        default: 191876000995145 (legacy channels project)
  APPWRITE_API_KEY           required
  APPWRITE_DATABASE_ID       default: iptv_main
  APPWRITE_CHANNELS_COLLECTION_ID  default: channels
  IMPORT_DELAY_SEC           default: 0.2 — delay between document inserts
  M3U_FILE                   path to local .m3u / .m3u8 file (required)
  RESUME_FILE                default: .import_channels_resume.json
  SKIP_DELETE                set to 1 to skip batch delete phase
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any
from urllib.parse import quote

# ── Config ────────────────────────────────────────────────────────────────────

ENDPOINT = os.environ.get("APPWRITE_ENDPOINT", "https://nyc.cloud.appwrite.io/v1").rstrip("/")
PROJECT_ID = os.environ.get("APPWRITE_PROJECT_ID", "191876000995145")
API_KEY = os.environ.get("APPWRITE_API_KEY", "").strip()
DATABASE_ID = os.environ.get("APPWRITE_DATABASE_ID", "iptv_main")
COLLECTION_ID = os.environ.get("APPWRITE_CHANNELS_COLLECTION_ID", "channels")
IMPORT_DELAY_SEC = float(os.environ.get("IMPORT_DELAY_SEC", "0.2"))
M3U_FILE = os.environ.get("M3U_FILE", "").strip()
RESUME_FILE = os.environ.get("RESUME_FILE", ".import_channels_resume.json")
SKIP_DELETE = os.environ.get("SKIP_DELETE", "").strip() in {"1", "true", "yes"}
PAGE_SIZE = 100

BACKOFF_STEPS = [10, 20, 40]


@dataclass
class ChannelRow:
    name: str
    stream_url: str
    group: str = ""
    logo: str = ""
    category: str = ""

    @property
    def doc_id(self) -> str:
        raw = f"{self.name}|{self.stream_url}".encode("utf-8")
        return hashlib.sha256(raw).hexdigest()[:32]


# ── HTTP helpers ──────────────────────────────────────────────────────────────


class AppwriteError(Exception):
    def __init__(self, status: int, message: str) -> None:
        super().__init__(message)
        self.status = status
        self.message = message


def _request(
    method: str,
    path: str,
    body: dict[str, Any] | None = None,
    *,
    backoff_attempt: int = 0,
    retried: bool = False,
) -> dict[str, Any]:
    url = f"{ENDPOINT}{path}"
    data = None
    headers = {
        "X-Appwrite-Project": PROJECT_ID,
        "X-Appwrite-Key": API_KEY,
        "Content-Type": "application/json",
    }
    if body is not None:
        data = json.dumps(body).encode("utf-8")

    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read().decode("utf-8")
            if not raw.strip():
                return {}
            return json.loads(raw)
    except urllib.error.HTTPError as exc:
        err_body = exc.read().decode("utf-8", errors="replace")
        if exc.code == 429:
            idx = min(backoff_attempt, len(BACKOFF_STEPS) - 1)
            wait = BACKOFF_STEPS[idx]
            print(f"[429] rate limited — sleeping {wait}s (attempt {backoff_attempt + 1})")
            time.sleep(wait)
            return _request(
                method,
                path,
                body,
                backoff_attempt=backoff_attempt + 1,
                retried=retried,
            )
        raise AppwriteError(exc.code, err_body or str(exc)) from exc
    except Exception as exc:
        if not retried:
            print(f"[retry] {exc} — sleeping 2s then retrying once")
            time.sleep(2)
            return _request(method, path, body, backoff_attempt=backoff_attempt, retried=True)
        raise


def list_documents(offset: int = 0) -> dict[str, Any]:
    queries = [
        f'queries[]={quote(json.dumps({"method": "limit", "values": [PAGE_SIZE]}))}',
        f'queries[]={quote(json.dumps({"method": "offset", "values": [offset]}))}',
    ]
    qs = "&".join(queries)
    path = (
        f"/databases/{DATABASE_ID}/collections/{COLLECTION_ID}/documents"
        f"?{qs}"
    )
    return _request("GET", path)


def delete_document(doc_id: str) -> None:
    path = f"/databases/{DATABASE_ID}/collections/{COLLECTION_ID}/documents/{doc_id}"
    _request("DELETE", path)


def create_document(doc_id: str, data: dict[str, Any]) -> None:
    path = f"/databases/{DATABASE_ID}/collections/{COLLECTION_ID}/documents"
    _request("POST", path, {"documentId": doc_id, "data": data})


# ── M3U parser ────────────────────────────────────────────────────────────────

_ATTR_RE = re.compile(r'(\w[\w-]*)="([^"]*)"')


def _parse_attrs(line: str) -> dict[str, str]:
    return {m.group(1).lower(): m.group(2) for m in _ATTR_RE.finditer(line)}


def parse_m3u(text: str) -> list[ChannelRow]:
    rows: list[ChannelRow] = []
    pending_name = ""
    pending_logo = ""
    pending_group = ""

    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        upper = line.upper()
        if upper == "#EXTM3U":
            continue
        if upper.startswith("#EXTINF"):
            attrs = _parse_attrs(line)
            pending_logo = attrs.get("tvg-logo", attrs.get("logo", ""))
            pending_group = attrs.get("group-title", attrs.get("group", ""))
            if "," in line:
                pending_name = line.rsplit(",", 1)[-1].strip()
            else:
                pending_name = attrs.get("tvg-name", attrs.get("name", "")).strip()
            continue
        if line.startswith("#"):
            continue
        if not pending_name:
            pending_name = line
        rows.append(
            ChannelRow(
                name=pending_name,
                stream_url=line,
                group=pending_group,
                logo=pending_logo,
            )
        )
        pending_name = ""
        pending_logo = ""
        pending_group = ""

    return rows


# ── Resume checkpoint ─────────────────────────────────────────────────────────


def load_resume() -> set[str]:
    if not os.path.isfile(RESUME_FILE):
        return set()
    try:
        with open(RESUME_FILE, encoding="utf-8") as fh:
            data = json.load(fh)
        return set(data.get("done_ids", []))
    except (json.JSONDecodeError, OSError):
        return set()


def save_resume(done_ids: set[str]) -> None:
    with open(RESUME_FILE, "w", encoding="utf-8") as fh:
        json.dump({"done_ids": sorted(done_ids)}, fh, indent=2)


def clear_resume() -> None:
    if os.path.isfile(RESUME_FILE):
        os.remove(RESUME_FILE)


# ── Import phases ─────────────────────────────────────────────────────────────


def batch_delete_all() -> tuple[int, int]:
    deleted = 0
    failed = 0
    offset = 0
    print("[delete] listing existing documents…")
    while True:
        try:
            page = list_documents(offset)
        except Exception as exc:
            print(f"[delete] list failed at offset={offset}: {exc}")
            failed += 1
            break

        docs = page.get("documents", [])
        if not docs:
            break

        for doc in docs:
            doc_id = doc.get("$id") or doc.get("id") or ""
            if not doc_id:
                continue
            try:
                delete_document(doc_id)
                deleted += 1
                if deleted % 50 == 0:
                    print(f"[delete] removed {deleted}…")
            except Exception as exc:
                print(f"[delete] failed {doc_id}: {exc}")
                failed += 1

        if len(docs) < PAGE_SIZE:
            break
        offset += PAGE_SIZE

    print(f"[delete] done — deleted={deleted} failed={failed}")
    return deleted, failed


def import_channels(rows: list[ChannelRow]) -> tuple[int, int, int]:
    done_ids = load_resume()
    success = 0
    failed = 0
    skipped = 0

    total = len(rows)
    for idx, row in enumerate(rows, start=1):
        if not row.name or not row.stream_url:
            skipped += 1
            continue

        doc_id = row.doc_id
        if doc_id in done_ids:
            skipped += 1
            continue

        payload = {
            "name": row.name,
            "stream_url": row.stream_url,
        }
        if row.group:
            payload["group_title"] = row.group
        if row.logo:
            payload["logo"] = row.logo
        if row.category:
            payload["category"] = row.category

        try:
            create_document(doc_id, payload)
            success += 1
            done_ids.add(doc_id)
            save_resume(done_ids)
            if idx % 25 == 0 or idx == total:
                print(f"[insert] {idx}/{total} — ok={success} fail={failed} skip={skipped}")
            time.sleep(IMPORT_DELAY_SEC)
        except Exception as exc:
            print(f"[insert] failed {row.name!r}: {exc}")
            failed += 1

    return success, failed, skipped


# ── Main ──────────────────────────────────────────────────────────────────────


def main() -> int:
    if not API_KEY:
        print("ERROR: APPWRITE_API_KEY is required", file=sys.stderr)
        return 1
    if not M3U_FILE or not os.path.isfile(M3U_FILE):
        print("ERROR: set M3U_FILE to a valid playlist path", file=sys.stderr)
        return 1

    with open(M3U_FILE, encoding="utf-8", errors="replace") as fh:
        m3u_text = fh.read()

    rows = parse_m3u(m3u_text)
    parsed = len(rows)
    print(
        f"[config] endpoint={ENDPOINT} project={PROJECT_ID} "
        f"db={DATABASE_ID} collection={COLLECTION_ID} "
        f"delay={IMPORT_DELAY_SEC}s parsed={parsed}"
    )

    delete_failed = 0
    if SKIP_DELETE:
        print("[delete] skipped (SKIP_DELETE=1)")
    else:
        _, delete_failed = batch_delete_all()
        if delete_failed == 0:
            clear_resume()

    success, failed, skipped = import_channels(rows)

    print("═" * 50)
    print("IMPORT SUMMARY")
    print(f"  total parsed : {parsed}")
    print(f"  success      : {success}")
    print(f"  failed       : {failed + delete_failed}")
    print(f"  skipped      : {skipped}")
    print("═" * 50)

    if success > 0 and failed == 0 and delete_failed == 0:
        clear_resume()

    return 0 if failed == 0 and delete_failed == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
