#!/usr/bin/env python3
"""Copy tool/user_playlist.m3u → assets/data/user_playlist.m3u for bundled import."""
from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = Path(__file__).resolve().parent / "user_playlist.m3u"
DST = ROOT / "assets" / "data" / "user_playlist.m3u"


def main() -> None:
    if not SRC.is_file():
        print(
            "Place your M3U playlist at tool/user_playlist.m3u then run again.\n"
            "Supports #EXTINF blocks and multi-URL lines (merged by channel name in app)."
        )
        raise SystemExit(1)
    DST.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(SRC, DST)
    lines = SRC.read_text(encoding="utf-8", errors="replace").count("\n")
    print(f"Installed {SRC.name} → {DST.relative_to(ROOT)} ({lines} lines)")


if __name__ == "__main__":
    main()
