# M5 — Shared Wi‑Fi soak test plan

**Phase 3 M5** — Document only.  
**Goal:** Validate per-device caps, install IDs, server caps, and ad routing when **many devices share one public IP** (hostel, café, stadium Wi‑Fi).

---

## 1. Why this test exists

| Risk on shared IP | Mitigation in Lumio |
|-------------------|---------------------|
| One device exhausts hourly cap for everyone | Caps keyed by **`installId`** + fingerprint, not IP |
| Ad network flags “invalid traffic” | `setDynamicUserId` / device fingerprint before LevelPlay init |
| Server cap treats subnet as one user | GET `/caps/{installId}` per device |
| VPN-heavy networks | H4 confidence → prefer LevelPlay, disable Adsterra |

---

## 2. Lab setup

| Item | Spec |
|------|------|
| Wi‑Fi | Single AP, no client isolation (all devices same public egress IP) |
| Devices | **≥5** physical phones (mix OEMs) |
| Builds | Identical release APK, same `CAP_BASE_URL` / LevelPlay keys |
| Backend | Cap API logging: `installId`, placement, allow/deny, timestamp |
| Duration | **4 hours** soak (minimum **2 hours** for smoke) |

Optional: one device on VPN, one on clean network — compare `[AdSafety] vpn_tier`.

---

## 3. Pre-soak checklist

- [ ] All devices: `adb install` same APK SHA-256  
- [ ] `CAP_BASE_URL` reachable from Wi‑Fi  
- [ ] Server dashboard / logs ready for cap hits  
- [ ] Disable “Private DNS” / VPN on control devices (except VPN test arm)  
- [ ] Note public IP: `curl -s ifconfig.me` from a laptop on same Wi‑Fi  

---

## 4. Test arms

### Arm A — Independent caps (primary)

| Step | Each device independently |
|------|---------------------------|
| A1 | Clear app data; cold start; complete consent |
| A2 | Record `installId` from logcat `[AdSafety]` |
| A3 | Trigger **8** interstitial-eligible events in 1 hour (channel funnel) |
| A4 | 9th attempt | **Blocked** locally; server cap log shows same `installId` |

**Pass:** Device B still allowed after Device A hits cap (different `installId`).

### Arm B — Server cap sync (M2)

| Step | Action |
|------|--------|
| B1 | Set server limit `interstitial: 2` for test IDs |
| B2 | Two devices same Wi‑Fi, different install IDs |
| B3 | Each shows 2 interstitials | Server returns allow |
| B4 | Third attempt each | Deny from server; log `fail_closed` if API down |

### Arm C — Fail-closed under outage

| Step | Action |
|------|--------|
| C1 | Block `CAP_BASE_URL` on router firewall mid-soak |
| C2 | Wait >5 min (cache TTL) |
| C3 | All devices | No new interstitials; `[ServerCap] fail_closed` |
| C4 | Restore API | Cold start one device | Ads resume after sync |

### Arm D — Adsterra vs LevelPlay routing

| Step | Action |
|------|--------|
| D1 | One device on VPN (Nord/WireGuard) |
| D2 | Log `vpn_confidence` ≥ 0.55 or tier `confirmed` |
| D3 | Confirm Adsterra disabled; channel tap uses LevelPlay rotator only |

---

## 5. Metrics to record (hourly)

| Metric | Source |
|--------|--------|
| Active devices | Tester count |
| Interstitials shown / device | Manual tally + `[Cap]` logs |
| Server cap 200 vs 4xx/timeout | Backend logs |
| `fail_closed` count | Logcat grep |
| LevelPlay init failures | `[LevelPlay] init_failed` |
| Adsterra telemetry POSTs | `[AdsterraTelemetry] post_ok` |
| Crash / ANR | `adb logcat` |

---

## 6. Failure criteria (stop soak)

| Condition | Action |
|-----------|--------|
| Wrong device blocked after another hit cap | **Fail** — cap keyed by IP bug |
| All devices share one `installId` | **Fail** — migration/storage bug |
| Server down but ads unlimited | **Fail** — M2 regression |
| >10% init_failed on clean devices | Investigate LevelPlay / network |

---

## 7. Reporting template

```markdown
## Shared Wi‑Fi soak — YYYY-MM-DD
- AP / location:
- Public IP:
- Devices: N
- APK SHA-256:
- Duration:

### Arm A
- Pass/Fail:
- Notes:

### Arm B
- Pass/Fail:

### Arm C
- Pass/Fail:

### Arm D
- Pass/Fail:

### Defects filed
- 
```

---

## 8. Automation hints (optional later)

- Script `adb` multi-serial log harvest  
- Server cap load test with distinct `installId` headers (not a substitute for real devices)

**REQUIRES DEVICE TEST** — execute on physical hardware; emulator Wi‑Fi does not replicate carrier NAT behavior.
