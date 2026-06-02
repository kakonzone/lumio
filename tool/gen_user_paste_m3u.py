#!/usr/bin/env python3
"""Build assets/data/user_playlist.m3u from tool/user_paste_urls.txt (one URL per line)."""
from __future__ import annotations
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
URLS_FILE = Path(__file__).parent / "user_paste_urls.txt"
OUT = ROOT / "assets" / "data" / "user_playlist.m3u"

# path/host fragment -> (display name, group-title category)
NAME_MAP = {
    "tsports": ("T Sports", "Sports"),
    "starsports2": ("Star Sports 2", "Sports"),
    "starsportsselect1": ("Star Sports Select 1", "Sports"),
    "starsportsselect2": ("Star Sports Select 2", "Sports"),
    "sonytensports2": ("Sony Ten Sports 2", "Sports"),
    "sonytensports5": ("Sony Ten Sports 5", "Sports"),
    "eurosport": ("Eurosport", "Sports"),
    "beinsport": ("beIN Sports", "Sports"),
    "beinsport3": ("beIN Sports 3", "Sports"),
    "sport1": ("Sport 1", "Sports"),
    "sport2": ("Sport 2", "Sports"),
    "sport3": ("Sport 3", "Sports"),
    "sport4": ("Sport 4", "Sports"),
    "sport5": ("Sport 5", "Sports"),
    "sport6": ("Sport 6", "Sports"),
    "machtv": ("Match TV", "Sports"),
    "jalshamovies": ("Jalsha Movies", "Movies"),
    "zeebanglacinema": ("Zee Bangla Cinema", "Movies"),
    "colorsbanglachinema": ("Colors Bangla Cinema", "Movies"),
    "sonyaath": ("Sony Aath", "Entertainment"),
    "sonymax": ("Sony MAX", "Movies"),
    "sonytv": ("Sony TV", "Entertainment"),
    "starplus": ("Star Plus", "Hindi"),
    "stargold": ("Star Gold", "Movies"),
    "starmovies": ("Star Movies", "Movies"),
    "zeetv": ("Zee TV", "Hindi"),
    "discoverykids": ("Discovery Kids", "Kids"),
    "cartoonnetwork": ("Cartoon Network", "Kids"),
    "nationalgeographic": ("National Geographic", "English"),
    "discovery": ("Discovery", "English"),
    "news24": ("News24 BD", "Bangladesh"),
    "nagorik": ("Nagorik TV", "Bangladesh"),
    "deeptotv": ("Deepto TV", "Bangladesh"),
    "etvlivesn": ("Ekushey TV", "Bangladesh"),
    "deshitv": ("Deshi TV", "Bangladesh"),
    "greentv": ("Green TV", "Bangladesh"),
    "jagonews24": ("Jagonews 24", "Bangladesh"),
    "mnews24": ("M News 24", "Bangladesh"),
    "amarbanglatv": ("Amar Bangla TV", "Bangladesh"),
    "ruposhibangla": ("Ruposhi Bangla", "Bangladesh"),
    "anandatv": ("Ananda TV", "Bangladesh"),
    "atnbanglauk": ("ATN Bangla UK", "Bangladesh"),
    "biswabanglatv": ("Biswa Bangla TV", "Bangladesh"),
    "millenniumtv": ("Millennium TV", "Bangladesh"),
    "ntvuk": ("NTV UK", "Bangladesh"),
    "nrb-eu": ("NRB TV EU", "Bangladesh"),
    "samaykolkata": ("Samay Kolkata", "Bangladesh"),
    "montv": ("Mon TV", "Bangladesh"),
    "amardigital": ("Amar Digital", "Bangladesh"),
    "sbin": ("S Bin", "Bangladesh"),
    "chsukoff": ("Channel S UK", "English"),
    "cgtn": ("CGTN", "English"),
    "ndtvindia": ("NDTV India", "Hindi"),
    "ndtv24x7": ("NDTV 24x7", "English"),
    "rplusnews24x7": ("R Plus News 24x7", "Bangladesh"),
    "rongeentv": ("Rongeen TV", "Bangladesh"),
    "zillarbarta": ("Zillar Barta", "Bangladesh"),
    "pratidintime": ("Pratidin Time", "Bangladesh"),
    "ekhonkolkata": ("Ekhon Kolkata", "Bangladesh"),
    "newstime": ("News Time", "Bangladesh"),
    "newslive": ("News Live", "Bangladesh"),
    "taratv": ("Tara TV", "Bangladesh"),
    "friendstv": ("Friends TV", "Bangladesh"),
    "shreebangla": ("Shree Bangla", "Bangladesh"),
    "bhichannel": ("Bhi Channel", "Bangladesh"),
    "cnnnews": ("CNN News", "English"),
    "ctvnakdplus": ("CTV Nakd Plus", "Bangladesh"),
    "raatdinbangla": ("Raat Din Bangla", "Bangladesh"),
    "sklivenews": ("SK Live News", "Bangladesh"),
    "dcnhindi": ("DCN Hindi", "Hindi"),
    "hometv": ("Home TV", "Bangladesh"),
    "raatdintripura": ("Raat Din Tripura", "Bangladesh"),
    "nebharat24": ("Nebharat 24", "Bangladesh"),
    "kolkatatv": ("Kolkata TV", "Bangladesh"),
    "probashi_tv": ("Probashi TV", "Bangladesh"),
    "timetv": ("Time TV", "Bangladesh"),
    "tbn24": ("TBN24", "Bangladesh"),
    "noortvuk": ("Noor TV UK", "English"),
    "mqtv": ("MQ TV", "Bangladesh"),
    "tv9": ("TV9 Bangla", "Bangladesh"),
    "bollywood-hd": ("Bollywood HD", "Movies"),
    "starsports1": ("Star Sports 1", "Sports"),
    "actionhollywood": ("Action Hollywood", "Movies"),
    "yrfmusic": ("YRF Music", "Entertainment"),
    "shemaroo": ("Shemaroo Bollywood", "Hindi"),
    "dangal": ("Dangal", "Hindi"),
    "bhojpuri": ("Bhojpuri Live", "Hindi"),
    "foxnews": ("Fox News", "English"),
    "bbc_world": ("BBC World Service", "English"),
    "dwstream": ("DW News", "English"),
    "realwild": ("Real Wild", "English"),
    "insighttv": ("Insight TV", "English"),
    "animal-planet": ("Animal Planet", "Kids"),
    "disckids": ("Discovery Kids", "Kids"),
    "minimax": ("Mini Max", "Kids"),
    "baby_tv": ("Baby TV", "Kids"),
    "extremakids": ("Extrema Kids", "Kids"),
    "wildearth": ("Wild Earth", "Kids"),
    "zoomoonz": ("Zoo Moo", "Kids"),
    "junglebook": ("Jungle Book", "Kids"),
    "bollyflix": ("BollyFlix", "Movies"),
    "godtv": ("GOD TV", "English"),
    "trace sport": ("Trace Sport", "Sports"),
    "tracesport": ("Trace Sport", "Sports"),
    "radiolive": ("Radio TV", "Entertainment"),
    "realmadrid": ("Real Madrid TV", "Sports"),
    "caze_tv": ("Caze TV BR", "Sports"),
    "mtrspt": ("Motor Sport TV", "Sports"),
    "sportinghd": ("Sporting HD", "Sports"),
    "telecosta": ("Tele Costa", "Sports"),
    "puertorico": ("NBC Puerto Rico", "English"),
    "masr": ("Al Masryia", "English"),
    "saudi_sunnah": ("Saudi Sunnah", "English"),
    "saudi_quran": ("Saudi Quran", "English"),
    "al_ekhbariya": ("Al Ekhbariya", "English"),
    "alqamar": ("Al Qamar", "English"),
    "almasirah": ("Al Masirah", "English"),
    "arabica": ("Arabica", "English"),
    "rtnews": ("RT News", "English"),
    "rtdoc": ("RT Doc", "English"),
    "arihant": ("Arihant TV", "Hindi"),
    "accuweather": ("AccuWeather", "English"),
    "leadstory": ("Lead Story", "English"),
    "histoire": ("Histoire", "English"),
    "rtl9": ("RTL9", "English"),
    "tf1": ("TF1 HD", "English"),
    "canal+_sport": ("Canal+ Sport HD", "Sports"),
    "infosport": ("Info Sport", "Sports"),
    "onlymusic": ("Only Music", "Entertainment"),
    "pardesi": ("Pardesi TV", "Entertainment"),
    "music.m3u8": ("30A Music", "Entertainment"),
    "mytime": ("My Time", "Kids"),
    "epic": ("Epic TV", "Movies"),
    "balleballetv": ("Balle Ballet TV", "Entertainment"),
    "moviebangla": ("Movie Bangla", "Movies"),
    "gseriesdrama": ("G Series Drama", "Entertainment"),
    "akash": ("Akash TV", "Entertainment"),
}

SPORTS_HINTS = (
    "sport", "cricket", "football", "bein", "eurosport", "starsports",
    "sonyten", "tsports", "willow", "match", "arena", "machtv", "trace",
)


GPCDN_MAP = {
    "1701": ("Jamuna TV", "Bangladesh"),
    "1702": ("Somoy TV", "Bangladesh"),
    "1703": ("Channel 24", "Bangladesh"),
    "1704": ("Independent TV", "Bangladesh"),
    "1705": ("Ekattor TV", "Bangladesh"),
    "1706": ("ATN News", "Bangladesh"),
    "1708": ("News 24", "Bangladesh"),
    "1709": ("BTV", "Bangladesh"),
    "1710": ("Star News", "Bangladesh"),
    "1711": ("Deepto TV", "Bangladesh"),
    "1713": ("Kingdom of Saudi Arabia", "Bangladesh"),
    "1715": ("Bangla Vision", "Bangladesh"),
    "1716": ("Ekhon TV", "Bangladesh"),
    "1721": ("Al Jazeera TV", "Bangladesh"),
    "1723": ("Channel i", "Bangladesh"),
    "1724": ("Islamic TV", "Bangladesh"),
}


def guess_name_category(url: str) -> tuple[str, str]:
    low = url.lower()
    for key, (name, cat) in NAME_MAP.items():
        if key in low:
            return name, cat

    m = re.search(r"bpk-tv/(\d+)", low)
    if m:
        cid = m.group(1)
        if cid in GPCDN_MAP:
            return GPCDN_MAP[cid]
        return f"GP CDN {cid}", "Bangladesh"

    m = re.search(r"/([^/]+)/(?:index|playlist|tracks)[^/]*\.m3u8", low)
    if m:
        slug = m.group(1)
        name = re.sub(r"[_\-]+", " ", slug).strip().title()
        if any(h in low for h in SPORTS_HINTS):
            return name, "Sports"
        if "news" in low or "tv" in slug:
            return name, "Bangladesh"
        if "cinema" in low or "movie" in low or "max" in low:
            return name, "Movies"
        if "kid" in low or "cartoon" in low or "baby" in low:
            return name, "Kids"
        return name, "Entertainment"

    host = re.search(r"https?://([^/]+)", low)
    host_s = host.group(1) if host else "Stream"
    return f"Stream {host_s[:24]}", "Entertainment"


def main() -> None:
    if not URLS_FILE.exists():
        print(f"Missing {URLS_FILE}")
        return

    urls = [
        u.strip()
        for u in URLS_FILE.read_text().splitlines()
        if u.strip().startswith("http")
    ]
    # name -> list of urls (preserve order, dedupe urls)
    by_name: dict[str, list[str]] = {}
    meta: dict[str, str] = {}

    for url in urls:
        name, cat = guess_name_category(url)
        key = name.lower()
        by_name.setdefault(key, [])
        if url not in by_name[key]:
            by_name[key].append(url)
        meta[key] = cat

    lines = ["#EXTM3U"]
    for key in sorted(by_name.keys(), key=lambda k: (meta[k], k)):
        name_display = NAME_MAP.get(key.replace(" ", ""), (None, None))
        # recover display name from first url guess
        display = key.title() if key else "Channel"
        for nk, (dn, _) in NAME_MAP.items():
            if nk in key.replace(" ", ""):
                display = dn
                break
        else:
            # use original guess from first url
            display, _ = guess_name_category(by_name[key][0])

        cat = meta[key]
        for url in by_name[key]:
            lines.append(f'#EXTINF:-1 group-title="{cat}" ,{display}')
            lines.append(url)

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {len(by_name)} channels ({len(urls)} URLs) -> {OUT}")


if __name__ == "__main__":
    main()
