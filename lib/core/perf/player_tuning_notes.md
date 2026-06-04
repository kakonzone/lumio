# Player tuning notes (WC hotfix)

1. **Redmi 9 / Note 10 Lite (MIUI):** `hwdec=auto-safe` often falls back to software decode; mediacodec keeps video on the SoC DSP/GPU path.
2. **Realme Narzo / C-series (ColorOS):** Same SW fallback pattern; thermal throttling within ~10 min on 1080p HLS without mediacodec.
3. **Samsung Galaxy A12/A22:** Budget Exynos/MediaTek chips overheat when libmpv applies `vf scale` on top of decode.
4. **vf scale on Android:** Doubles memory bandwidth (decode + scale); removed — rely on HLS rendition pick / `setVideoTrack`.
5. **Default 540p:** Cuts decode pixels ~44% vs 720p and ~75% vs 1080p on first launch.
6. **720p auto ceiling:** Cellular or battery &lt; 50% avoids 1080p auto step-up that spikes radio + decoder power.
7. **Probe during playback:** `ensureStreamHealth` competes with mediacodec for CPU; gated to idle-only.
8. **Prewarm during playback:** mpv filter graph rebuild stalls the render thread; idle-only on non–low-RAM devices.
9. **Low-RAM tier (≤2.8 GB):** Skips probe/prewarm entirely — matches Redmi 9 3 GB class devices in the field.
10. **Release vs debug:** Always validate thermals on `app-arm64-v8a-release.apk`; debug adds JIT overhead unrelated to player stack.
