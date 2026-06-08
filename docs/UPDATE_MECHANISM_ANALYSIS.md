# Lumio App Update Mechanism - Full Analysis & Test Plan

## Current Implementation Analysis

### Architecture Overview

Lumio uses **two separate update services**:

1. **`UpdateService`** (Primary - Force Update) - **ACTIVE**
   - Location: `lib/services/update_service.dart`
   - Used in: `lib/main.dart:336`
   - Purpose: Force update dialog that blocks app usage
   - Manifest URL: `https://lumio.me/version.json` (default)
   - Configurable via: `--dart-define=FORCE_UPDATE_VERSION_URL`

2. **`AppUpdateService`** (Legacy - Soft Update) - **INACTIVE**
   - Location: `lib/services/app_update_service.dart`
   - Purpose: Optional soft update with "Later" button
   - Manifest URL: Configured via `--dart-define=APP_UPDATE_MANIFEST_URL`
   - Status: **NOT wired in main.dart** (per docs/SIDELOAD_UPDATE.md:58)

---

## Full Update Flow Trace

### 1. Release Flow (Developer/CI Side)

```
Developer bumps pubspec.yaml version (1.0.0 → 1.0.1)
  ↓
Push to main branch
  ↓
GitHub Actions: .github/workflows/release.yml triggers
  ↓
Build APK (flutter build apk --release --split-per-abi)
  ↓
Create GitHub Release (tag: v1.0.1)
  ↓
Upload APK to GitHub Release
  ↓
Update web/version.json & version.json files:
  {
    "version": "1.0.1",
    "apk_url": "https://github.com/kakonzone/lumio/releases/download/v1.0.1/app-arm64-v8a-release.apk"
  }
  ↓
Commit version.json changes (skip ci)
  ↓
Cloudflare Pages deploys web/ to lumio.me
  ↓
https://lumio.me/version.json now serves new version
```

**Evidence:** <ref_file file="/home/kakonzone/Downloads/FlutterProject/lumio/.github/workflows/release.yml" lines="158-173" />

### 2. Client Update Check Flow (App Side)

```
User opens Lumio app
  ↓
SplashScreen → MainShell loads
  ↓
Post-frame callback triggers (main.dart:321-343)
  ↓
UpdateService.checkForUpdate(context) called (main.dart:336)
  ↓
UpdateService._fetchPendingUpdate() executes:
  ├─ Fetch GET https://lumio.me/version.json (10s timeout)
  ├─ Parse JSON: { "version": "1.0.1", "apk_url": "..." }
  ├─ Get current app version via PackageInfo.fromPlatform()
  └─ Compare versions using isNewerVersion()
  ↓
If remote version > current version:
  ↓
_showForceUpdateDialog() displays
  ├─ Dialog is NON-DISMISSIBLE (barrierDismissible: false)
  ├─ System back button exits app (PopScope.canPop: false)
  ├─ Bengali UI: "⚠️ আপডেট করা আবশ্যক!"
  └─ "আপডেট করুন" button → opens https://lumio.me/
  ↓
User lands on lumio.me website
  ↓
User taps "ডাউনলোড করুন" button
  ↓
Browser downloads APK from version.json apk_url
  ↓
User installs APK (Android system installer)
  ↓
Old app replaced with new version
```

**Evidence:**
- Update check: <ref_file file="/home/kakonzone/Downloads/FlutterProject/lumio/lib/main.dart" lines="336" />
- Service implementation: <ref_file file="/home/kakonzone/Downloads/FlutterProject/lumio/lib/services/update_service.dart" />
- Version comparison: <ref_file file="/home/kakonzone/Downloads/FlutterProject/lumio/lib/services/update_service.dart" lines="64-81" />

---

## Version Comparison Logic

### `UpdateService.isNewerVersion()`

```dart
static bool isNewerVersion(String latest, String current) {
  final l = _parts(latest);  // e.g., [1, 0, 1]
  final c = _parts(current); // e.g., [1, 0, 0]
  for (var i = 0; i < 3; i++) {
    final lv = i < l.length ? l[i] : 0;
    final cv = i < c.length ? c[i] : 0;
    if (lv > cv) return true;  // Update needed
    if (lv < cv) return false; // Current is newer
  }
  return false; // Same version
}
```

**Behavior:**
- Compares semver parts (major.minor.patch)
- Only checks first 3 parts (i < 3)
- Strips non-numeric characters (e.g., "1.0.0+1" → [1, 0, 0, 1])
- Returns `true` only if remote version is strictly greater

**Test Coverage:** <ref_file file="/home/kakonzone/Downloads/FlutterProject/lumio/test/services/update_service_test.dart" />

---

## Current State

### App Version
- **pubspec.yaml:** `version: 1.0.0+1`
- **web/version.json:** `{"version":"1.0.0","apk_url":"https://github.com/kakonzone/Android-APK-Download/releases/download/v1.0.0/app-release.apk"}`

### Configuration
- **Default manifest URL:** `https://lumio.me/version.json`
- **Override capability:** `--dart-define=FORCE_UPDATE_VERSION_URL`
- **Download page:** `https://lumio.me/` (not direct APK link)
- **Timeout:** 10 seconds for HTTP fetch
- **Check frequency:** On app open (post-frame callback in MainShell)

---

## Potential Issues Found

### ⚠️ Issue #1: APK URL Mismatch in version.json
**Current web/version.json:**
```json
{
  "version":"1.0.0",
  "apk_url":"https://github.com/kakonzone/Android-APK-Download/releases/download/v1.0.0/app-release.apk"
}
```

**Problem:** APK URL points to wrong GitHub repository (`Android-APK-Download` instead of `kakonzone/lumio`)

**Evidence:** <ref_file file="/home/kakonzone/Downloads/FlutterProject/lumio/web/version.json" />

**Impact:** Users clicking "ডাউনলোড করুন" on lumio.me will get 404 error

---

## Test Plan: v1.0.0 → v1.0.1 Update Verification

### Prerequisites
1. ✅ Lumio app installed with version 1.0.0
2. ✅ GitHub Actions workflow configured
3. ✅ Cloudflare Pages deployed for lumio.me
4. ✅ Android device/emulator for testing

### Step-by-Step Test Plan

#### Phase 1: Prepare Release v1.0.1

1. **Bump version in pubspec.yaml**
   ```yaml
   version: 1.0.1+2  # Increment version
   ```

2. **Commit and push to main**
   ```bash
   git add pubspec.yaml
   git commit -m "chore: bump version to 1.0.1"
   git push origin main
   ```

3. **Wait for GitHub Actions release.yml workflow**
   - Monitor: https://github.com/kakonzone/lumio/actions
   - Expected: APK build + GitHub Release + version.json update

4. **Verify version.json update**
   ```bash
   curl -s https://lumio.me/version.json
   ```
   Expected output:
   ```json
   {
     "version": "1.0.1",
     "apk_url": "https://github.com/kakonzone/lumio/releases/download/v1.0.1/app-arm64-v8a-release.apk"
   }
   ```

5. **Verify GitHub Release**
   - Check: https://github.com/kakonzone/lumio/releases
   - Confirm: Release v1.0.1 exists with APK

#### Phase 2: Test Update Detection (App Side)

6. **Launch Lumio app v1.0.0**
   - Open app on Android device
   - Wait for splash screen to complete
   - Navigate to home screen

7. **Wait for update check**
   - Update check happens in post-frame callback (~1-2 seconds after home loads)
   - Monitor logcat: `flutter logs` or Android Studio Logcat

8. **Verify force update dialog appears**
   - **Expected:** Dialog with "⚠️ আপডেট করা আবশ্যক!" title
   - **Expected:** Message: "নতুন Version 1.0.1 পাওয়া গেছে।"
   - **Expected:** Single button: "আপডেট করুন"
   - **Expected:** Dialog CANNOT be dismissed by tapping outside
   - **Expected:** System back button EXITS app

9. **Tap "আপডেট করুন" button**
   - **Expected:** Browser opens to https://lumio.me/
   - **Expected:** lumio.me loads with download button

10. **Verify website APK URL**
    - Tap "ডাউনলোড করুন" on website
    - **Expected:** Browser starts APK download from correct GitHub URL
    - **Expected:** Download completes successfully

11. **Install APK**
    - Open downloaded APK from browser/downloads
    - **Expected:** Android installer opens
    - **Expected:** Installer shows app update (v1.0.0 → v1.0.1)
    - Tap "Install"

12. **Verify update successful**
    - Open Lumio app
    - **Expected:** App version now shows 1.0.1
    - **Expected:** No update dialog appears (already on latest)

#### Phase 3: Edge Case Testing

13. **Test with same version**
    - Revert web/version.json to 1.0.0
    - Restart app
    - **Expected:** NO update dialog (same version)

14. **Test with older remote version**
    - Set web/version.json to 0.9.0
    - Restart app
    - **Expected:** NO update dialog (remote is older)

15. **Test network timeout**
    - Block internet connection
    - Restart app
    - **Expected:** App loads normally (update check fails silently)
    - **Expected:** No crash or error dialog

16. **Test malformed JSON**
    - Set web/version.json to invalid JSON
    - Restart app
    - **Expected:** App loads normally (update check fails silently)

17. **Test version URL override**
    - Build APK with: `--dart-define=FORCE_UPDATE_VERSION_URL=https://example.com/version.json`
    - Install and test
    - **Expected:** App fetches from custom URL

---

## Bug Fixes Required

### Fix #1: Correct APK URL in version.json

**Current (WRONG):**
```json
{
  "version":"1.0.0",
  "apk_url":"https://github.com/kakonzone/Android-APK-Download/releases/download/v1.0.0/app-release.apk"
}
```

**Should be:**
```json
{
  "version":"1.0.0",
  "apk_url":"https://github.com/kakonzone/lumio/releases/download/v1.0.0/app-arm64-v8a-release.apk"
}
```

**Fix:** Update web/version.json manually or trigger release workflow

---

## Recommendations

### 1. Add Update Check Logging
```dart
debugPrint('[Update] Checking for updates from $versionUrl');
debugPrint('[Update] Current version: ${packageInfo.version}');
debugPrint('[Update] Remote version: $latestVersion');
debugPrint('[Update] Update needed: $needsUpdate');
```

### 2. Add Retry Logic
Current implementation fails silently on network errors. Consider:
- Exponential backoff retry
- Cached last-known version for offline mode
- User-visible error message after 3 failed attempts

### 3. Add Beta Update Channel
Support beta updates for testing:
```json
{
  "stable": "1.0.0",
  "beta": "1.0.1-beta.1",
  "beta_apk_url": "..."
}
```

### 4. Add Update History
Track which version user installed from to prevent downgrade attacks:
```dart
final lastInstalledVersion = prefs.getString('last_installed_version');
if (isNewerVersion(lastInstalledVersion, latestVersion)) {
  // Allow update
} else {
  // Prevent downgrade
}
```

---

## Summary

**Status:** ✅ Update mechanism is **functionally correct** but has **data issue**

**Flow:** Release → GitHub Actions → version.json → App Check → Force Dialog → Website → Download → Install

**Critical Fix:** Update web/version.json APK URL to point to correct repository

**Test Plan:** Ready to execute once version is bumped to 1.0.1

**Next Steps:**
1. Fix web/version.json APK URL
2. Bump pubspec.yaml to 1.0.1
3. Execute test plan
4. Monitor first real-world update
