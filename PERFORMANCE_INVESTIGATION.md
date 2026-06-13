# Lumio App Performance Investigation

## Overview
Investigation into potential performance issues causing the app to feel not smooth.

---

## 🔍 Identified Performance Issues

### 1. Background Ad Engine (HIGH PRIORITY)

**File:** `lib/ads/background_ad_engine.dart`

**Issue:**
- Background WebView runs headless ad rotations every 60 seconds
- Runs JavaScript injection in WebView
- Competes for resources with main UI thread
- Network requests running in background

**Current Configuration:**
```dart
// ci_defines.json
"BACKGROUND_ENGINE_ENABLED": "true"

// lib/config/ad_config.dart
static const int backgroundAdRotationSeconds = 60; // Every 60 seconds
static const int backgroundAdSessionCap = 20;
static const bool backgroundEngineEnabled = true; // Default enabled
```

**Impact:**
- WebView loading overhead
- Network requests every 60s
- JavaScript execution
- Memory usage from WebView
- CPU usage during rotation

**Recommendation:**
- Disable background engine during active usage
- Increase rotation interval to 180s or more
- Only enable when app is backgrounded
- Consider removing if not critical for revenue

---

### 2. WebView Pool Configuration

**File:** `lib/ads/utils/webview_pool.dart`

**Current Configuration:**
```dart
static const int _defaultMaxConcurrent = 3;
```

**Issue:**
- Up to 3 WebViews can be active simultaneously
- Each WebView loads JavaScript and network content
- WebView Pool doesn't reduce count on low-end devices

**Impact:**
- High memory usage on low-RAM devices
- CPU usage from multiple WebViews
- Network contention

**Recommendation:**
- Reduce to 2 concurrent WebViews for normal tier
- Reduce to 1 for low-RAM devices
- Implement based on PerformanceTuning.tier

---

### 3. List Implementation Issues

**Screen:** `lib/screens/tv_screen.dart`

**Current Usage:**
```dart
// Line 347 - Uses ListView.separated without optimization
child: ListView.separated(
  scrollDirection: Axis.horizontal,
  padding: const EdgeInsets.symmetric(horizontal: 16),
  itemCount: results.length,
  separatorBuilder: (_, __) => const SizedBox(width: 8),
  itemBuilder: (ctx, i) { ... },
)

// Line 1019 - Another ListView.separated
child: ListView.separated(
  scrollDirection: Axis.horizontal,
  padding: const EdgeInsets.symmetric(horizontal: 16),
  itemCount: matches.length,
  separatorBuilder: (_, __) => const SizedBox(width: 10),
  itemBuilder: (_, i) { ... },
)

// Line 1864 - Regular ListView without builder
child: ListView(
  shrinkWrap: true,
  padding: const EdgeInsets.symmetric(vertical: 6),
  children: [ ... ],
)
```

**Issues:**
- Not using `OptimizedListView` from `lib/utils/list_performance.dart`
- No `itemExtent` set for fixed-height items
- No `RepaintBoundary` for complex items
- Regular ListView instead of ListView.builder for some cases

**Impact:**
- Unnecessary widget rebuilds during scroll
- Slower scrolling on large lists
- Higher CPU usage during scroll

---

### 4. Excessive setState Calls

**Screen:** `lib/screens/tv_screen.dart`

**Problem Areas:**
- Line 323: `onChanged: (_) => setState(() {})` - Called on every character input
- Line 338: `setState(() {})` - Potentially called frequently
- Line 1267: `if (mounted) setState(() {})` - Called after async operations
- Line 1652: `if (mounted) setState(() {})` - Another frequent setState

**Impact:**
- Rebuilds entire widget tree unnecessarily
- Can cause stutter during typing
- High CPU usage during rapid state changes

---

### 5. Image Loading

**Status:** ✅ Good - App uses CachedImage widget

**Files:** `lib/widgets/common/cached_image.dart`

**Current Configuration (from PerformanceTuning):**
```dart
// lib/core/performance_tuning.dart
static int get imageCacheMaxObjects =>
    switch (_tier) {
      DeviceRamTier.low => 40,
      DeviceRamTier.normal => 80,
      DeviceRamTier.high => 120,
    };

static int get imageCacheMaxBytes {
  if (kReleaseMode) {
    return switch (_tier) {
      DeviceRamTier.low => 16 * 1024 * 1024,   // 16 MB
      DeviceRamTier.normal => 28 * 1024 * 1024, // 28 MB
      DeviceRamTier.high => 40 * 1024 * 1024,   // 40 MB
    };
  }
  // Debug mode has higher limits
}
```

**Issue:**
- Cache sizes might be too high for low-end devices
- 40MB image cache on 2GB device is 2% of total RAM

**Recommendation:**
- Reduce low-tier cache to 8MB
- Reduce normal-tier cache to 16MB
- Keep high-tier at 32MB

---

### 6. Performance Tuning Configuration

**File:** `lib/core/performance_tuning.dart`

**Current Settings:**
```dart
static double get listCacheExtent =>
    switch (_tier) {
      DeviceRamTier.low => 200,
      DeviceRamTier.normal => 320,
      DeviceRamTier.high => 420,
    };

static int get playerBufferMb =>
    switch (_tier) {
      DeviceRamTier.low => 2,
      DeviceRamTier.normal => 3,
      DeviceRamTier.high => 4,
    };
```

**Issues:**
- List cache extent of 320px on normal devices is generous
- Could cause more off-screen widgets to be built
- Player buffer of 3MB might be too high for streaming

---

## 📊 Performance Metrics to Monitor

### Android Studio Profiler Checkpoints:
1. **CPU Usage** - Should be < 20% during idle
2. **Memory Usage** - Should be < 300MB during normal use
3. **GPU Rendering** - Should be > 90% green frames
4. **Network** - Check background ad network requests
5. **Energy Impact** - Check WebView energy consumption

### Flutter DevTools Checkpoints:
1. **Performance Overlay** - Check frame rate (target 60fps)
2. **Widget Rebuild** - Identify excessive rebuilds
3. **Memory** - Check for memory leaks
4. **Network** - Identify slow or blocking requests

---

## 🛠️ Recommended Fixes

### High Priority (Immediate Action):

#### 1. Disable Background Ad Engine
```dart
// ci_defines.json
"BACKGROUND_ENGINE_ENABLED": "false"
```

Or modify the timing:
```dart
// lib/config/ad_config.dart
static const int backgroundAdRotationSeconds = 300; // 5 minutes instead of 60s
```

#### 2. Optimize ListView Usage
Replace ListView.separated with OptimizedListView:
```dart
// Before
ListView.separated(
  scrollDirection: Axis.horizontal,
  itemCount: items.length,
  itemBuilder: (ctx, i) => CardWidget(items[i]),
  separatorBuilder: (_, __) => SizedBox(width: 8),
)

// After
OptimizedHorizontalList(
  itemCount: items.length,
  itemBuilder: (ctx, i) => CardWidget(items[i]),
  itemExtent: 120, // Set if items have fixed height
  useRepaintBoundary: true,
)
```

#### 3. Reduce Image Cache Sizes
```dart
// lib/core/performance_tuning.dart
static int get imageCacheMaxBytes {
  if (kReleaseMode) {
    return switch (_tier) {
      DeviceRamTier.low => 8 * 1024 * 1024,    // Reduced from 16MB
      DeviceRamTier.normal => 16 * 1024 * 1024, // Reduced from 28MB
      DeviceRamTier.high => 32 * 1024 * 1024,   // Reduced from 40MB
    };
  }
  return switch (_tier) {
    DeviceRamTier.low => 12 * 1024 * 1024,
    DeviceRamTier.normal => 24 * 1024 * 1024,
    DeviceRamTier.high => 48 * 1024 * 1024,
  };
}
```

### Medium Priority:

#### 4. Optimize WebView Pool
```dart
// lib/ads/utils/webview_pool.dart
static int get _defaultMaxConcurrent {
  if (PerformanceTuning.isLowRam) return 1;
  if (PerformanceTuning.isHighRam) return 3;
  return 2; // Normal tier reduced from 3
}
```

#### 5. Reduce List Cache Extent
```dart
// lib/core/performance_tuning.dart
static double get listCacheExtent =>
    switch (_tier) {
      DeviceRamTier.low => 150,   // Reduced from 200
      DeviceRamTier.normal => 250, // Reduced from 320
      DeviceRamTier.high => 350,   // Reduced from 420
    };
```

#### 6. Add RepaintBoundary to Complex Items
```dart
// In list item builders
itemBuilder: (context, index) {
  return RepaintBoundary(
    child: CardWidget(items[index]),
  );
}
```

### Low Priority:

#### 7. Optimize setState Usage
- Use debouncing for search input
- Use ValueNotifier for frequent updates
- Consider const constructors where possible

#### 8. Reduce Player Buffer
```dart
// lib/core/performance_tuning.dart
static int get playerBufferMb =>
    switch (_tier) {
      DeviceRamTier.low => 1,  // Reduced from 2
      DeviceRamTier.normal => 2, // Reduced from 3
      DeviceRamTier.high => 3,   // Reduced from 4
    };
```

---

## 🧪 Testing Plan

### Before Fixes:
1. Run app on low-end device (2GB RAM)
2. Open TV screen and scroll through channels
3. Monitor CPU usage in Android Studio Profiler
4. Check frame rate with Flutter DevTools
5. Measure memory usage after 5 minutes of use

### After Fixes:
1. Repeat same tests
2. Compare CPU usage (should be lower)
3. Compare frame rate (should be higher/more stable)
4. Compare memory usage (should be lower)
5. Check if scrolling is smoother

---

## 📈 Expected Improvements

### With Background Engine Disabled:
- CPU usage: -15% to -25%
- Memory usage: -20MB to -50MB
- Fewer GC pauses
- Smoother scrolling

### With ListView Optimizations:
- Scrolling FPS: +5 to +15 fps
- Fewer widget rebuilds
- Better scroll physics

### With Reduced Image Cache:
- Memory usage: -10MB to -20MB
- Fewer GC pauses
- Faster app startup

### Overall Expected:
- Smoother scrolling experience
- Reduced stuttering
- Better performance on low-end devices
- Lower battery usage

---

## 🎯 Quick Win (One-Line Fix)

The quickest fix that will have the most impact:

```json
// ci_defines.json
{
  "BACKGROUND_ENGINE_ENABLED": "false"  // Change from "true" to "false"
}
```

This single change will:
- Stop background WebView rotations
- Reduce network requests
- Free up CPU and memory
- Improve smoothness immediately

---

## 📝 Summary

**Main Culprits:**
1. Background Ad Engine (highest impact)
2. Unoptimized ListView implementations
3. WebView pool too large for low-end devices
4. Image cache sizes too generous
5. Excessive setState calls

**Recommended Action Order:**
1. Disable BACKGROUND_ENGINE_ENABLED (immediate, high impact)
2. Optimize ListView usage (medium effort, medium impact)
3. Reduce image cache sizes (quick, medium impact)
4. Optimize WebView pool (medium effort, medium impact)
5. Fix setState usage (ongoing, low-moderate impact)

**Expected Result:**
App should feel significantly smoother after disabling the background engine. Other optimizations will further improve performance, especially on low-end devices.