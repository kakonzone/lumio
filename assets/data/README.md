# Bundled channel playlist

Place your full M3U at `tool/user_playlist.m3u`, then run:

```bash
python3 tool/ingest_user_playlist.py
```

The app loads `assets/data/user_playlist.m3u` on startup and merges channels by name (multi-links become one channel with backup URLs).

Optional scanned catalog (JioTV + scan server, ~1000+ channels) for release APK offline:

```bash
python3 tool/build_scanned_iptv_m3u.py   # writes assets/data/scanned_iptv.m3u
python3 tool/gen_network_security_config.py   # HTTP allowlist for release
```

To add channels in code once (syncs everywhere), use `ExtraChannels.userChannels` or `ExtraChannels.fromMultiLinkPaste()` in `lib/data/extra_channels.dart`.
