# Bundled channel playlist

Place your full M3U at `tool/user_playlist.m3u`, then run:

```bash
python3 tool/ingest_user_playlist.py
```

The app loads `assets/data/user_playlist.m3u` on startup and merges channels by name (multi-links become one channel with backup URLs).

To add channels in code once (syncs everywhere), use `ExtraChannels.userChannels` or `ExtraChannels.fromMultiLinkPaste()` in `lib/data/extra_channels.dart`.
