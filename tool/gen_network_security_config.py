#!/usr/bin/env python3
"""Regenerate android/app/src/main/res/xml/network_security_config.xml stream allowlist."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "android/app/src/main/res/xml/network_security_config.xml"

ADS_HTTPS = {
    "app-measurement.com",
    "applovin.com",
    "applvn.com",
    "effectivecpmnetwork.com",
    "fcm.googleapis.com",
    "fcmtoken.googleapis.com",
    "firebase.googleapis.com",
    "firebaseinstallations.googleapis.com",
    "firebaselogging.googleapis.com",
    "firebaseremoteconfig.googleapis.com",
    "google-analytics.com",
    "google.com",
    "googleapis.com",
    "gstatic.com",
    "highperformanceformat.com",
    "ironsource.mobi",
    "isprog.com",
    "supersonicads.com",
    "unity3d.com",
    "www.google.com",
}

SOURCES = [
    ROOT / "assets/data/user_playlist.m3u",
    ROOT / "assets/data/scanned_iptv.m3u",
    ROOT / "lib/provider/app_provider.dart",
    ROOT / "lib/data/extra_channels.dart",
    ROOT / "lib/services/scanned_iptv_service.dart",
]
# All Dart sources — extract http:// hosts for cleartext allowlist.
SOURCES.extend(sorted((ROOT / "lib").rglob("*.dart")))


def extract_hosts(text: str) -> set[str]:
    hosts: set[str] = set()
    for m in re.finditer(r"https?://([^/\s\"'<>]+)", text):
        raw = m.group(1).split("@")[-1]
        host = raw.split(":")[0].split("/")[0]
        if host and not host.startswith("127."):
            hosts.add(host)
    return hosts


def main() -> None:
    hosts: set[str] = set()
    for path in SOURCES:
        if path.exists():
            hosts |= extract_hosts(path.read_text(errors="ignore"))
    stream = sorted(hosts - ADS_HTTPS)

    lines = [
        '<?xml version="1.0" encoding="utf-8"?>',
        "<!-- Lumio: default HTTPS; monetization hosts explicit; HTTP only for curated IPTV streams. -->",
        "<network-security-config>",
        '    <base-config cleartextTrafficPermitted="false">',
        '        <trust-anchors><certificates src="system" /></trust-anchors>',
        "    </base-config>",
        '    <domain-config cleartextTrafficPermitted="false">',
    ]
    for d in sorted(ADS_HTTPS):
        lines.append(f'        <domain includeSubdomains="true">{d}</domain>')
    lines.extend(
        [
            "    </domain-config>",
            '    <domain-config cleartextTrafficPermitted="true">',
        ]
    )
    for h in stream:
        lines.append(f'        <domain includeSubdomains="true">{h}</domain>')
    lines.extend(
        [
            "    </domain-config>",
            "    <debug-overrides>",
            '        <base-config cleartextTrafficPermitted="true">',
            "            <trust-anchors>",
            '                <certificates src="system" />',
            '                <certificates src="user" />',
            "            </trust-anchors>",
            "        </base-config>",
            "    </debug-overrides>",
            "</network-security-config>",
            "",
        ]
    )
    OUT.write_text("\n".join(lines))
    print(f"Wrote {OUT} ({len(stream)} stream hosts, {len(ADS_HTTPS)} ad domains)")


if __name__ == "__main__":
    main()
