#!/usr/bin/env python3
"""Build assets/data/scanned_iptv.m3u from live IPTV scan sources."""
from __future__ import annotations

import json
import re
import urllib.request
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "data" / "scanned_iptv.m3u"

JIO_CHANNELS_URL = "http://103.180.212.191:3500/channels"
SCAN_PLAYLIST_URL = "http://202.70.146.135:8000/playlist.m3u8"
JIO_STREAM_BASE = "http://103.180.212.191:3500/live/{id}.m3u8"

# Manual entries from user scan (names + URLs not in Jio API shape).
USER_EXTRA: list[tuple[str, str, str]] = [
    ("National Geographic", "English", "http://202.70.146.135:8000/play/a05o/index.m3u8"),
    ("Discovery Bangla", "Bangladesh", "http://202.70.146.135:8000/play/a05z/index.m3u8"),
    ("Star Sports 1 Hindi", "Sports", "http://202.70.146.135:8000/play/a01e/index.m3u8"),
    ("Star Sports Select 1 HD", "Sports", "http://202.70.146.135:8000/play/a03c/index.m3u8"),
    ("Zee Cafe HD", "Hindi", "http://202.70.146.135:8000/play/a04n/index.m3u8"),
    ("Colors Cineplex SD", "Movies", "http://202.70.146.135:8000/play/a01b/index.m3u8"),
    ("Nick", "Kids", "http://202.70.146.135:8000/play/a04c/index.m3u8"),
]


def fetch(url: str, timeout: float = 25.0) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 Lumio/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", errors="replace")


def clean_name(raw: str) -> str:
    name = raw.strip()
    name = re.sub(r"\s*-\s*Rs\s+[\d.]+\s*$", "", name, flags=re.I)
    name = re.sub(r"^\s*&", "&", name)
    return name.strip(" ,")


def is_stream(line: str) -> bool:
    return line.startswith(("http://", "https://", "rtmp://", "rtsp://"))


def parse_m3u(body: str) -> list[tuple[str, str, str]]:
    """Return list of (name, group, url). Keeps duplicate names for multilink merge in app."""
    out: list[tuple[str, str, str]] = []
    pending_name = ""
    pending_group = ""
    for raw in body.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("#EXTINF"):
            pending_name = clean_name(line.split(",", 1)[-1])
            m = re.search(r'group-title="([^"]*)"', line, re.I)
            pending_group = m.group(1).strip() if m else ""
            continue
        if not is_stream(line):
            continue
        if not pending_name or pending_name.startswith("http://"):
            continue
        out.append((pending_name, pending_group or "Entertainment", line))
        pending_name = ""
        pending_group = ""
    return out


def jio_category(cat_id: int) -> str:
    # JioTV Go category ids (approximate).
    mapping = {
        5: "Entertainment",
        6: "Movies",
        7: "Sports",
        8: "News",
        9: "Kids",
        12: "Music",
        16: "News",
    }
    return mapping.get(cat_id, "Entertainment")


def load_jio_channels() -> list[tuple[str, str, str]]:
    raw = fetch(JIO_CHANNELS_URL)
    data = json.loads(raw)
    rows = data.get("result") or []
    out: list[tuple[str, str, str]] = []
    for row in rows:
        name = clean_name(str(row.get("channel_name") or ""))
        cid = str(row.get("channel_id") or "").strip()
        if not name or not cid:
            continue
        url = JIO_STREAM_BASE.format(id=cid)
        group = jio_category(int(row.get("channelCategoryId") or 5))
        out.append((name, group, url))
    return out


def write_m3u(entries: list[tuple[str, str, str]]) -> None:
    lines = ["#EXTM3U"]
    for name, group, url in entries:
        lines.append(f'#EXTINF:-1 group-title="{group}" ,{name}')
        lines.append(url)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    by_name: dict[str, list[tuple[str, str, str]]] = defaultdict(list)
    seen_url: set[str] = set()

    def add(name: str, group: str, url: str) -> None:
        url = url.strip()
        if not url or url in seen_url:
            return
        key = name.lower().strip()
        if not key:
            return
        seen_url.add(url)
        by_name[key].append((name, group, url))

    for name, group, url in USER_EXTRA:
        add(name, group, url)

    try:
        scan_body = fetch(SCAN_PLAYLIST_URL)
        for name, group, url in parse_m3u(scan_body):
            add(name, group or "Entertainment", url)
        print(f"Scan playlist: {len(parse_m3u(scan_body))} entries")
    except Exception as e:
        print(f"Scan playlist skipped: {e}")

    try:
        jio = load_jio_channels()
        for name, group, url in jio:
            add(name, group, url)
        print(f"JioTV API: {len(jio)} entries")
    except Exception as e:
        print(f"JioTV API skipped: {e}")

    flat: list[tuple[str, str, str]] = []
    for items in by_name.values():
        flat.extend(items)

    write_m3u(flat)
    multi = sum(1 for v in by_name.values() if len(v) > 1)
    print(f"Wrote {OUT.relative_to(ROOT)} — {len(flat)} streams, {len(by_name)} unique names, {multi} multilink names")


if __name__ == "__main__":
    main()
