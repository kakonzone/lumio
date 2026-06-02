# APK Size Reduction Plan for 14-20MB Target

## Current Estimated Size Breakdown
- **Native Libraries (media_kit)**: ~15-20MB
- **Flutter Engine**: ~8-10MB
- **Firebase Services**: ~3-5MB
- **Ad Networks**: ~2-3MB
- **WebView**: ~2-3MB
- **Assets & Resources**: ~1-2MB
- **Other Dependencies**: ~2-3MB
- **Total**: ~35-45MB

## To Achieve 14-20MB, You MUST Remove:

### 1. **Video Player Native Libraries** (BIGGEST IMPACT: -15-20MB)
**Option A:** Remove media_kit entirely
- Use Flutter's built-in video_player (smaller but fewer features)
- OR use ExoPlayer directly with minimal configuration
- **Impact:** -15-20MB

**Option B:** Keep media_kit but remove unused architectures
- Already done (arm64-v8a, armeabi-v7a only)
- Can try to strip unused symbols further
- **Impact:** -2-3MB

### 2. **Firebase Services** (IMPACT: -3-5MB)
Remove if not essential:
- `firebase_analytics` - if you don't need analytics
- `firebase_crashlytics` - if you don't need crash reporting
- `firebase_remote_config` - if you don't need remote config
- Keep only: `firebase_core` + `firebase_messaging` (if needed for push)
- **Impact:** -3-5MB

### 3. **Ad Networks** (IMPACT: -2-3MB)
- `unity_levelplay_mediation` - if ads are not critical
- Can use lighter ad SDKs or remove ads entirely
- **Impact:** -2-3MB

### 4. **WebView** (IMPACT: -2-3MB)
- `webview_flutter` - if not used for critical features
- Check if WebView is only used for ads (see #3)
- **Impact:** -2-3MB

### 5. **Other Dependencies** (IMPACT: -2-3MB)
Review and remove:
- `battery_plus` - if not used
- `connectivity_plus` - if not used
- `device_info_plus` - if not used
- `package_info_plus` - if not used
- **Impact:** -1-2MB

## Realistic Scenarios

### Scenario 1: Aggressive Removal (14-18MB)
- Remove media_kit, use video_player
- Remove Firebase analytics/crashlytics/remote_config
- Remove ad networks
- Remove WebView
- Remove unused utilities
- **Result:** 14-18MB
- **Trade-off:** Lose many features

### Scenario 2: Moderate Removal (20-25MB)
- Keep media_kit but optimize
- Remove Firebase analytics/crashlytics
- Keep minimal ad SDK
- Keep WebView (for ads)
- **Result:** 20-25MB
- **Trade-off:** Keep core features

### Scenario 3: Conservative (25-30MB)
- Keep all current features
- Only apply optimizations already done
- **Result:** 25-30MB
- **Trade-off:** No feature loss

## Recommended Actions for 14-20MB

### Step 1: Analyze What's Actually Used
```bash
# Build and analyze APK
flutter build apk --release --split-per-abi
# Open APK in Android Studio -> Build -> Analyze APK
```

### Step 2: Remove Unused Dependencies
Check each dependency in pubspec.yaml:
```bash
# Search for usage of each package
grep -r "import 'package:firebase_analytics" lib/
grep -r "import 'package:firebase_crashlytics" lib/
grep -r "import 'package:unity_levelplay" lib/
grep -r "import 'package:webview_flutter" lib/
```

### Step 3: Replace Heavy Components
**Video Player:**
```yaml
# Remove:
media_kit: 1.2.6
media_kit_video: 2.0.1
media_kit_libs_android_video: 1.3.8

# Add (lighter alternative):
video_player: ^2.8.0
```

**Firebase:**
```yaml
# Remove:
firebase_analytics: 12.4.1
firebase_crashlytics: 5.2.2
firebase_remote_config: 6.5.1

# Keep only if needed:
firebase_core: 4.9.0
firebase_messaging: 16.2.2
```

### Step 4: Apply All Optimizations
- Font subsetting (already provided script)
- Asset compression
- Resource shrinking (already enabled)
- Code shrinking (already enabled)

## Conclusion

**14-20MB IS POSSIBLE but requires:**
1. Removing video player native libraries OR using lighter alternative
2. Removing non-essential Firebase services
3. Removing or simplifying ad networks
4. Removing WebView if not critical
5. Aggressive dependency cleanup

**If you want to keep all current features:**
- Realistic target: 25-30MB with current optimizations
- 14-20MB would require significant feature removal

## My Recommendation

For a streaming app, I recommend:
- **Target 25-30MB** with current features
- Keep media_kit (essential for streaming)
- Keep Firebase (useful for analytics/push)
- Keep ads (if monetization is important)
- Apply all optimizations already configured

If 14-20MB is absolutely required:
- You'll need to sacrifice features
- Consider using a lighter video player
- Remove non-essential services
- Accept reduced functionality
