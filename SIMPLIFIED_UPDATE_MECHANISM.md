# Simplified Update Mechanism - Appwrite Only

## Overview
Simplified the Lumio IPTV app update mechanism to use **only Appwrite remote configuration** for updates. This ensures that when you push code and the CI/CD workflow deploys a new APK to Appwrite Storage, running apps will detect the version mismatch and show an "Update Now" screen.

---

## Changes Made

### ✅ Disabled UpdateService (lumio.me based)
**File:** `lib/main.dart`

**Changes:**
- Commented out `import 'services/update_service.dart'`
- Removed `UpdateService.checkForUpdate(context)` call from home screen
- Added comment: "UpdateService disabled - using Appwrite remote config only"

**Reason:** Eliminate conflicting update sources

---

### ✅ Simplified AppUpdateService Settings Integration
**File:** `lib/screens/settings_screen.dart`

**Changes:**
- Removed `import '../services/app_update_service.dart'`
- Added `import '../provider/app_config_provider.dart'`
- Added `import '../widgets/remote_config_widgets.dart'`
- Modified version row to use Appwrite config for update checks
- Changed "Update Now" to "Download Latest APK from Appwrite Storage"
- Updated button to use Appwrite config updateUrl or fallback to lumio.kakonzone.me

**New Logic:**
```dart
// Version row now checks Appwrite config
final config = context.read<AppConfigProvider>().config;
if (config.forceUpdate) {
  final packageInfo = await PackageInfo.fromPlatform();
  if (isAppVersionOlder(packageInfo.version, config.latestVersion)) {
    await ForceUpdateDialog.show(context, config);
  }
}
```

---

### ✅ Enhanced ForceUpdateDialog
**File:** `lib/widgets/remote_config_widgets.dart`

**Changes:**
- Updated dialog description to mention "Appwrite Storage"
- Added fallback URL to `https://lumio.kakonzone.me` if updateUrl not configured
- Improved error handling for empty URLs

**New Behavior:**
```dart
static Future<void> _openUpdateUrl(String? url) async {
  final trimmed = url?.trim() ?? '';
  final finalUrl = trimmed.isEmpty 
      ? 'https://lumio.kakonzone.me' 
      : trimmed;
  
  final uri = Uri.parse(finalUrl);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
```

---

## New Update Flow

### 🔄 Single Source of Truth: Appwrite Remote Config

```
┌─────────────────────────────────────────────────────────────┐
│                    CI/CD Workflow                          │
│  git push → GitHub Actions → Build APK → Upload to        │
│           Appwrite Storage → Update Appwrite Config        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    App Launch                                │
│                  Splash Screen                              │
│              Fetch Appwrite Config                         │
│         Check latestVersion vs currentVersion                │
└─────────────────────────────────────────────────────────────┘
                            ↓
                ┌───────────────┴───────────────┐
                ↓                               ↓
        forceUpdate = true                 forceUpdate = false
                ↓                               ↓
    ┌───────────────────┐            ┌───────────────────┐
    │ Show ForceUpdate  │            │ Allow Home Screen │
    │    Dialog         │            │                  │
    │   "Update Now"    │            │                  │
    └───────────────────┘            └───────────────────┘
                ↓
    Open Appwrite Storage APK URL
    (or lumio.kakonzone.me fallback)
```

---

## Settings Screen Integration

### Version Row
- **Action:** Tapping version checks Appwrite config
- **Logic:** Compares current app version with Appwrite latestVersion
- **Result:** Shows update dialog if outdated, shows "up to date" message if current

### Download APK Row  
- **Action:** Tapping opens download URL directly
- **Source:** Appwrite config updateUrl (primary) or lumio.kakonzone.me (fallback)
- **Purpose:** Manual download without version check

---

## Appwrite Config Requirements

### Required Fields in `global_config`:
```json
{
  "key": "global_config",
  "latestVersion": "1.1.0",
  "forceUpdate": true,
  "updateUrl": "https://nyc.cloud.appwrite.io/v1/storage/buckets/...",
  "updateMessage": "New version available with bug fixes!"
}
```

### Field Descriptions:
- **latestVersion**: The version number that should trigger update
- **forceUpdate**: If true, blocks app until update (recommended)
- **updateUrl**: Direct APK download URL from Appwrite Storage
- **updateMessage**: Custom message shown in update dialog

---

## CI/CD Integration

### Update Workflow:
1. **Developer** pushes code to GitHub
2. **GitHub Actions** builds new APK
3. **CI script** uploads APK to Appwrite Storage
4. **CI script** updates Appwrite `global_config`:
   - Increments `latestVersion`
   - Sets `forceUpdate: true`
   - Updates `updateUrl` with new APK Storage URL
   - Sets custom `updateMessage`
5. **Running apps** fetch Appwrite config on next launch
6. **Apps detect version mismatch** and show "Update Now" dialog
7. **Users tap "Update Now"** and download new APK from Appwrite Storage

---

## Benefits of Simplified System

### ✅ Single Source of Truth
- Only Appwrite config controls updates
- No conflicting version sources
- Consistent behavior across all users

### ✅ Server-Side Control
- Enable/disable force updates instantly
- Custom messages for each update
- Emergency kill switch capability

### ✅ Seamless CI/CD Integration
- Automatic version bumping in workflow
- APK storage and config update in one process
- No manual file editing required

### ✅ Better User Experience
- Clear "Update Now" dialog
- Direct download from Appwrite Storage
- Fallback to website if Storage URL unavailable

---

## Configuration Example

### Appwrite `global_config` document:
```json
{
  "key": "global_config",
  "json_payload": {
    "latestVersion": "1.2.0",
    "minimumVersion": "1.1.0",
    "forceUpdate": true,
    "updateUrl": "https://nyc.cloud.appwrite.io/v1/storage/buckets/lumio-apks/files/abc123/view?project=191876000995145",
    "updateMessage": "Version 1.2.0 includes World Cup improvements and bug fixes!",
    "killSwitch": false,
    "maintenanceMode": false,
    "adsEnabled": true
  }
}
```

---

## Testing Checklist

### Manual Testing:
- [ ] Set forceUpdate to false → verify no update dialog
- [ ] Set forceUpdate to true with higher latestVersion → verify update dialog appears
- [ ] Test "Update Now" button opens correct URL
- [ ] Test fallback to lumio.kakonzone.me if updateUrl empty
- [ ] Verify splash screen blocks navigation when force update required

### CI/CD Testing:
- [ ] Trigger GitHub Actions workflow
- [ ] Verify APK uploaded to Appwrite Storage
- [ ] Verify Appwrite config updated with new version
- [ ] Test running app detects new version after workflow
- [ ] Verify download URL points to new APK in Storage

---

## Migration Notes

### Removed Systems:
- ❌ UpdateService (lumio.me/version.json)
- ❌ AppUpdateService (APP_UPDATE_MANIFEST_URL)
- ❌ Local version.json files

### Active System:
- ✅ Appwrite Remote Config (global_config)
- ✅ ForceUpdateDialog with Appwrite Storage integration
- ✅ Settings screen Appwrite-based update checks

---

## Summary

**Before:** 3 conflicting update systems  
**After:** 1 Appwrite-based system  
**Result:** Simplified, server-controlled, CI/CD integrated

The update mechanism is now **fully controlled by Appwrite remote configuration**. When you push code and the CI/CD workflow runs, it automatically updates the Appwrite config with the new version and APK Storage URL, causing running apps to show the "Update Now" screen on their next launch.