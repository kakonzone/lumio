# Device test — Task 5 (fingerprint + VPN + integrity stub)

**READY_FOR_DEVICE_TEST**

---

## What this task covers

| Area | Implementation |
|------|----------------|
| Stable `installId` | `lumio_install_id` + encrypted prefs; legacy `lumio_device_fingerprint` → derived UUID |
| Device fingerprint | SHA-256(`installId` + device signals), 32 chars |
| VPN routing | `tun` / `ppp` / `utun` via native `detectVpnInterface` |
| Geo heuristics | Premium locale **or** South Asia TZ — each independent; **≥2** → `preferCleanSdk` |
| Integrity | Stub token when `CAP_BASE_URL` set; sent once on first ServerCap GET |

---

## Build / run

### A — Local caps only (default)

```bash
flutter run --dart-define=ADS_TEST_MODE=true
```

### B — Server cap + integrity header

```bash
flutter run \
  --dart-define=ADS_TEST_MODE=true \
  --dart-define=CAP_BASE_URL=https://your-api.example.com/v1/
```

---

## Log patterns (logcat)

```bash
adb logcat -d | grep -E '\[AdSafety\]|\[Integrity\]|\[VpnSignal\]'
```

| Pattern | Expected |
|---------|----------|
| `[AdSafety] installId=` | UUID after first launch |
| `[AdSafety] migrated installId from legacy fingerprint` | Once after upgrade from fingerprint-only build |
| `[AdSafety] vpn_signals interfaces=` | `true` when VPN tun/ppp active |
| `locale_mismatch=` / `tz_mismatch=` | Each can be true independently |
| `routing=preferCleanSdk` | When ≥2 signals true |
| `[Integrity] stub token` | **Debug only**, when `CAP_BASE_URL` is set |

---

## Steps (physical Android)

1. **Fresh install** — note `installId` in log; force-stop and relaunch → same id.
2. **Upgrade path** — install an older build that only wrote `lumio_device_fingerprint`, then upgrade → log shows migration; `installId` stable across restarts.
3. **VPN** — enable VPN → `interfaces=true`; disable → `false`.
4. **Routing** — VPN on + set device locale to US/GB + timezone UTC+6 (e.g. Dhaka) → `routing=preferCleanSdk`, Adsterra surfaces off, channel tap rotates LevelPlay only.
5. **Integrity** — run build **B**; cold start → `[Integrity] stub token` once in debug; proxy/log first `GET .../caps/{installId}` includes header `X-Integrity-Token: stub:...`.

---

## Pass / fail criteria

| # | Criterion | Pass |
|---|-----------|------|
| 1 | Stable `installId` across cold starts | ☐ |
| 2 | Legacy fingerprint migrates without changing derived id | ☐ |
| 3 | VPN interface detection matches VPN on/off | ☐ |
| 4 | `preferCleanSdk` only when ≥2 signals | ☐ |
| 5 | Integrity stub only when `CAP_BASE_URL` set | ☐ |
| 6 | `flutter test test/services/ad_safety_migration_test.dart test/services/integrity_attestation_service_test.dart` | ☐ |

**Automated:**

```bash
flutter test test/services/ad_safety_migration_test.dart test/services/integrity_attestation_service_test.dart
```

**Task 5 result:** ☐ PASS ☐ FAIL — Tester: __________ Date: __________
