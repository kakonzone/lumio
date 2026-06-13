# Lumio Update Mechanism Investigation

## Overview
Lumio IPTV app has a **multi-layered update mechanism** with different services for different purposes. The app uses both Appwrite remote configuration and version JSON files for update management.

---

## Update System Architecture

### 🔄 Three Update Services

#### 1. `AppUpdateService` (app_update_service.dart)
**Purpose:** Sideload update checking with optional manifest URL  
**URL:** Configured via `APP_UPDATE_MANIFEST_URL` dart-define  
**Current Status:** Active but not configured (URL set to `__MISSING__`)

**Features:**
- Version comparison logic
- Update dialog with "Download APK" button
- NEW: "Update Now" button linking to lumio.kakonzone.me
- Used in Settings screen

**Flow:**
```
Settings → Version tap → AppUpdateService.checkForUpdate() 
→ Fetch version.json → Compare versions → Show dialog
```

#### 2. `UpdateService` (update_service.dart)
**Purpose:** Force update mechanism with cloudflare pages  
**URL:** `https://lumio.me/version.json` (hardcoded)  
**Current Status:** Active

**Features:**
- Force update (non-dismissible dialog)
- Bengali language UI
- Blocks navigation until update
- Opens lumio.me download page

**Flow:**
```
App launch/Navigation → UpdateService.blocksNavigation() 
→ Fetch lumio.me/version.json → Compare versions → Show force dialog
```

#### 3. Appwrite Remote Config (splash_screen.dart)
**Purpose:** Server-side configuration with kill switch and forced updates  
**Backend:** Appwrite Database `app_config` collection  
**Current Status:** Active

**Features:**
- Remote kill switch
- Maintenance mode
- Force update with custom message
- Version comparison via `latestVersion` field
- Custom download URL via `updateUrl`

**Flow:**
```
Splash screen → AppwriteAppConfig.fetchEntry('global_config') 
→ Check forceUpdate flag → Compare versions → Show ForceUpdateDialog
```

---

## Detailed Component Analysis

### 1. AppUpdateService (Sideload Updates)

**Configuration:**
```dart
// ci_defines.json
"APP_UPDATE_MANIFEST_URL": ""  // Currently empty

// lib/config/app_config.dart
static const String appUpdateManifestUrl = String.fromEnvironment(
  'APP_UPDATE_MANIFEST_URL',
  defaultValue: '__MISSING__',
);
```

**Version JSON Format:**
```json
{
  "version": "1.1.0",
  "apk_url": "https://github.com/kakonzone/lumio/releases/download/v1.1.0/app-arm64-v8a-release.apk",
  "message": "Optional update message"
}
```

**Update Dialog:**
```dart
// 3 buttons:
1. "Later" - Dismiss dialog
2. "Download APK" - Open configured APK URL
3. "Update Now" - Open lumio.kakonzone.me (NEW)
```

**Integration Points:**
- Settings screen → Version row
- Settings screen → "Update Now" row (NEW)
- Manual update checks

---

### 2. UpdateService (Force Updates)

**Configuration:**
```dart
static const String versionUrl = String.fromEnvironment(
  'FORCE_UPDATE_VERSION_URL',
  defaultValue: 'https://lumio.me/version.json',
);

static const String downloadPageUrl = String.fromEnvironment(
  'FORCE_UPDATE_DOWNLOAD_PAGE_URL',
  defaultValue: 'https://lumio.me/',
);
```

**Current Remote Version:**
```json
// https://lumio.me/version.json
{
  "version": "1.0.0",
  "apk_url": "https://github.com/kakonzone/lumio/releases/download/v1.0.0/app-arm64-v8a-release.apk"
}
```

**Force Update Dialog:**
- Bengali language: "⚠️ আপডেট করা আবশ্যক!"
- Non-dismissible (blocks back button)
- Single button: "আপডেট করুন"
- Opens lumio.me in external browser

**Integration Points:**
- Main.dart home screen load
- Navigation blocking
- Can be called manually

---

### 3. Appwrite Remote Config (Server-Side Control)

**Database Schema:**
```dart
// app_config collection
{
  "key": "global_config",
  "latestVersion": "1.1.0",
  "minimumVersion": "1.0.0",
  "forceUpdate": false,
  "updateUrl": "https://...",
  "updateMessage": "Custom message",
  "killSwitch": false,
  "maintenanceMode": false
}
```

**Splash Screen Logic:**
```dart
// lib/screens/splash_screen.dart
if (config.forceUpdate) {
  final packageInfo = await PackageInfo.fromPlatform();
  if (isAppVersionOlder(packageInfo.version, config.latestVersion)) {
    await ForceUpdateDialog.show(context, config);
    return; // Blocks home navigation
  }
}
```

**Force Update Dialog:**
```dart
// Non-dismissible
- Title: "Update Required"
- Message: Custom from server or default
- Button: "Update Now" → Opens config.updateUrl
- Blocks app usage until update
```

**Additional Controls:**
- Kill switch (blocks app entirely)
- Maintenance mode (blocks with message)
- Remote ad configuration
- Feature flags

---

## Version Comparison Logic

### Algorithm Used:
```dart
static bool isNewerVersion(String remote, String current) {
  final r = _parts(remote);  // [1, 1, 0]
  final c = _parts(current); // [1, 0, 0]
  
  for (var i = 0; i < 3; i++) {
    final rv = i < r.length ? r[i] : 0;
    final cv = i < c.length ? c[i] : 0;
    if (rv > cv) return true;  // Remote is newer
    if (rv < cv) return false; // Current is newer or equal
  }
  return false; // Equal
}

static List<int> _parts(String version) {
  return version
    .split('+')[0]        // Remove build number
    .split('.')           // Split by dots
    .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
    .toList();
}
```

**Examples:**
- `1.1.0` vs `1.0.0` → Update available
- `1.0.1` vs `1.0.0` → Update available  
- `1.0.0` vs `1.0.0` → No update
- `1.0.0+2` vs `1.0.0` → No update (build number ignored)

---

## Current Configuration Status

### ✅ Active Systems:
1. **UpdateService** - lumio.me/version.json (active)
2. **Appwrite Config** - Remote configuration (active)
3. **AppUpdateService** - Settings integration (active)

### ⚠️ Configuration Issues:
1. **APP_UPDATE_MANIFEST_URL** - Not set in ci_defines.json
2. **Version Mismatch** - Different versions in different files:
   - version.json: 1.1.0
   - web/version.json: 1.0.0
   - lumio.me/version.json: 1.0.0

### 📋 Files Needing Updates:
1. `ci_defines.json` - Add APP_UPDATE_MANIFEST_URL
2. `version.json` - Update to latest version
3. `web/version.json` - Update to latest version
4. Appwrite database - Update latestVersion field

---

## Update Flow Summary

### App Launch Flow:
```
1. Splash Screen Starts
   ↓
2. Appwrite Config Fetch (global_config)
   ↓
3. Check killSwitch → Block if true
   ↓
4. Check maintenanceMode → Block if true
   ↓
5. Check forceUpdate → Show dialog if version old
   ↓
6. Ad Consent Loading
   ↓
7. Navigate to Home
```

### Home Screen Flow:
```
1. Home Screen Loads
   ↓
2. UpdateService.checkForUpdate() (4s delay)
   ↓
3. Fetch lumio.me/version.json
   ↓
4. Show force dialog if version old
```

### Settings Screen Flow:
```
1. User taps "Version" row
   ↓
2. AppUpdateService.showUpdateDialogIfNeeded()
   ↓
3. Fetch APP_UPDATE_MANIFEST_URL if configured
   ↓
4. Show dialog with 3 buttons (Later, Download APK, Update Now)
```

### Manual Update Flow:
```
1. User taps "Update Now" row in settings
   ↓
2. Open lumio.kakonzone.me directly
```

---

## URLs and Endpoints

### Update Sources:
1. **Appwrite Config:** `nyc.cloud.appwrite.io/v1/databases/iptv_main/collections/app_config`
2. **Force Update JSON:** `https://lumio.me/version.json`
3. **Sideload Manifest:** `APP_UPDATE_MANIFEST_URL` (not configured)
4. **Download Website:** `https://lumio.kakonzone.me` (NEW)
5. **GitHub Releases:** `https://github.com/kakonzone/lumio/releases`

### Current Download URLs:
- Main: `https://lumio.me/`
- Alternative: `https://github.com/kakonzone/lumio/releases/`
- NEW: `https://lumio.kakonzone.me`

---

## Security Considerations

### ✅ Secure Practices:
- HTTPS only for all update endpoints
- Version comparison prevents downgrade attacks
- Non-dismissible force update prevents bypass
- Appwrite provides server-side control

### ⚠️ Potential Issues:
- HTTP GitHub URLs (should use HTTPS)
- No signature verification for APK downloads
- Multiple version sources could cause conflicts
- No rollback mechanism

---

## Recommendations

### Short Term:
1. **Configure APP_UPDATE_MANIFEST_URL** in ci_defines.json
2. **Sync all version files** to use same version number
3. **Update lumio.me/version.json** to latest version
4. **Test all three update mechanisms** independently

### Long Term:
1. **Consolidate to single source of truth** (Appwrite only)
2. **Add APK signature verification**
3. **Implement rollback mechanism**
4. **Add update download progress indicator**
5. **Consider in-app APK download** instead of external browser

---

## Testing Checklist

### AppUpdateService:
- [ ] Configure APP_UPDATE_MANIFEST_URL
- [ ] Test version comparison logic
- [ ] Test "Later" button functionality
- [ ] Test "Download APK" button functionality
- [ ] Test "Update Now" button (NEW)
- [ ] Test settings integration

### UpdateService:
- [ ] Test lumio.me/version.json fetch
- [ ] Test force dialog blocking
- [ ] Test back button blocking
- [ ] Test Bengali language display
- [ ] Test browser launch

### Appwrite Config:
- [ ] Test Appwrite config fetch
- [ ] Test forceUpdate flag
- [ ] Test killSwitch
- [ ] Test maintenanceMode
- [ ] Test custom update messages

---

## Summary

**Update Services:** 3 different systems  
**Active Systems:** 2 (UpdateService, Appwrite Config)  
**Configured Systems:** 1 (UpdateService)  
**New Features:** "Update Now" button with lumio.kakonzone.me link  

The update mechanism is **multi-layered but fragmented**. The app has three different update systems that could conflict with each other. For production, it's recommended to **consolidate to a single source of truth** (Appwrite remote config) and disable the other two systems to avoid version conflicts and user confusion.