# Performance Guidelines

This document outlines the performance features implemented in Lumio and guidelines for maintaining optimal app performance.

## Implemented Features

### 1. Skeleton Loading States

Comprehensive skeleton loaders for all content areas:

**Base Skeleton Widget** (`lib/widgets/common/skeleton.dart`)
- Surface2 base color, Surface3 highlight
- 1200ms shimmer cycle with easeInOut curve
- Respects reduce motion setting
- Pre-built shapes: avatar, thumbnail, textLine, title, button, card, listTile

**Specialized Skeletons** (`lib/widgets/common/skeleton_loaders.dart`)
- `movieCard()` - Home screen movie cards
- `channelRow()` - Live TV channel rows
- `epgProgramBlock()` - EPG timeline program blocks
- `settingsRow()` - Settings screen rows
- `searchResult()` - Search result items
- `fullPage()` - Full page loading state
- `movieCardList()` - Horizontal movie card list
- `verticalList()` - Vertical list items

**Usage:**
```dart
// Basic skeleton
Skeleton(width: 100, height: 100)

// Pre-built shapes
SkeletonShapes.avatar()
SkeletonShapes.thumbnail()
SkeletonShapes.textLine()

// Specialized
SkeletonLoaders.movieCard()
SkeletonLoaders.channelRow()
```

### 2. Image Caching with Fade-In Transitions

**CachedImage Widget** (`lib/widgets/common/cached_image.dart`)
- Memory and disk caching via cached_network_image
- 300ms fade-in transition
- Skeleton placeholder while loading
- Error fallback with broken image icon
- Configurable memory cache dimensions
- Disk cache limit: 1000x1000 pixels

**Specialized Image Loaders:**
- `CachedAvatar` - Circle avatar with automatic clipping
- `CachedThumbnail` - 16:9 aspect ratio thumbnail
- `CachedLogo` - Logo with name fallback

**Usage:**
```dart
CachedImage(
  imageUrl: 'https://example.com/image.jpg',
  width: 200,
  height: 200,
  fit: BoxFit.cover,
)

CachedAvatar(imageUrl: '...', size: 48)
CachedThumbnail(imageUrl: '...', width: 160)
CachedLogo(imageUrl: '...', name: 'Channel Name')
```

### 3. Page Transition Animations

**PageTransitions Utility** (`lib/widgets/common/page_transitions.dart`)
- `fadeInPage()` - Standard fade-in (300ms)
- `slideInFromRight()` - iOS-style slide from right
- `slideInFromBottom()` - Android-style slide from bottom
- `scaleInPage()` - Scale-up with spring curve
- `staggeredItem()` - Staggered list item animations
- `AnimatedPageRoute` - Custom page route with animation

**Usage:**
```dart
// Animate page content
PageTransitions.fadeInPage(child)

// Custom page route
Navigator.push(
  context,
  AnimatedPageRoute(
    transitionType: PageTransitionType.fadeIn,
    child: NextScreen(),
  ),
)

// Staggered list items
ListView.builder(
  itemBuilder: (context, index) {
    return PageTransitions.staggeredItem(
      CardWidget(index),
      index,
    );
  },
)
```

### 4. Refresh and Load More

**Refresh Indicator** (`lib/widgets/common/refresh_indicator.dart`)
- `AppRefreshIndicator` - Custom pull-to-refresh with accent color
- `LoadMoreIndicator` - Pagination load more button
- `EndOfListIndicator` - End of list divider

**Usage:**
```dart
AppRefreshIndicator(
  onRefresh: () async => _refreshData(),
  child: ListView.builder(...),
)

LoadMoreIndicator(
  isLoading: _isLoading,
  hasMore: _hasMore,
  onLoadMore: () => _loadMore(),
)
```

### 5. Optimized Lists

All lists should use:
- `ListView.builder` for large lists
- `CachedNetworkImage` for images
- Lazy loading for long lists
- Pagination or infinite scroll

## Guidelines for Developers

### When Adding New Screens

1. **Always add skeleton loading states:**
   - Use `SkeletonLoaders` for common patterns
   - Create new patterns if needed
   - Show skeleton during data fetching
   - Replace with actual content when loaded

2. **Use CachedImage for all network images:**
   - Never use `Image.network` directly
   - Use specialized loaders (Avatar, Thumbnail, Logo)
   - Provide error fallbacks
   - Set appropriate cache dimensions

3. **Add page transitions:**
   - Use `PageTransitions` utilities
   - Choose appropriate transition type
   - Keep duration to 300ms
   - Use staggered animations for lists

4. **Implement pull-to-refresh:**
   - Use `AppRefreshIndicator` for scrollable lists
   - Keep refresh actions under 2 seconds
   - Show appropriate loading state
   - Provide error feedback

5. **Optimize list performance:**
   - Use `ListView.builder` for long lists
   - Implement item extent if item heights are fixed
   - Use const constructors where possible
   - Avoid rebuilding entire lists on small changes

### Image Loading Best Practices

**Do:**
```dart
CachedImage(
  imageUrl: url,
  width: 200,
  height: 200,
  memCacheWidth: 200,
  memCacheHeight: 200,
)
```

**Don't:**
```dart
Image.network(url) // No caching
```

**Set Appropriate Cache Dimensions:**
- Thumbnails: 160x90 (16:9)
- Posters: 300x450
- Avatars: 100x100
- Logos: 200x200

### Loading States

**Skeleton Loading Pattern:**
```dart
if (isLoading) {
  return SkeletonLoaders.movieCardList();
}

if (error != null) {
  return ErrorState();
}

return ActualContent();
```

**Progress Indicators:**
- Use `CircularProgressIndicator` for indeterminate progress
- Use `LinearProgressIndicator` for determinate progress
- Use `Skeleton` for content loading
- Use `AppRefreshIndicator` for pull-to-refresh

### Optimistic UI Updates

For actions that have visual feedback:
```dart
// Optimistic update
setState(() {
  items[index].isFavorite = true;
});

// Actual API call
await api.toggleFavorite(item.id);

// Rollback if failed
if (error) {
  setState(() {
    items[index].isFavorite = false;
  });
}
```

### Animation Guidelines

**Duration Standards:**
- Page transitions: 300ms
- Press animations: 100ms
- Fade transitions: 300ms
- Shimmer cycle: 1200ms
- Staggered delay: 50ms per item

**Curve Standards:**
- Default: `Curves.easeInOut`
- Spring: `Curves.elasticOut`
- Enter: `Curves.easeOut`
- Exit: `Curves.easeIn`

**Reduce Motion:**
Always check `MotionTokens.reduceMotion(context)` before adding animations.

## Performance Optimization Checklist

### Image Loading
- [ ] All network images use CachedImage
- [ ] Memory cache dimensions set appropriately
- [ ] Error fallbacks provided
- [ ] Placeholder skeletons shown during loading
- [ ] Large images resized before display

### Lists
- [ ] Use ListView.builder for long lists
- [ ] Implement pagination or infinite scroll
- [ ] Use const constructors where possible
- [ ] Avoid unnecessary widget rebuilds
- [ ] Set item extent if heights are fixed

### Animations
- [ ] Respects reduce motion setting
- [ ] Duration under 300ms for transitions
- [ ] Use appropriate easing curves
- [ ] Avoid nested animations
- [ ] Test on low-end devices

### Loading States
- [ ] Skeleton states for all content areas
- [ ] Pull-to-refresh on scrollable lists
- [ ] Load more indicators for pagination
- [ ] Error states with retry options
- [ ] Progress indicators for long operations

### Caching
- [ ] Network images cached
- [ ] API responses cached where appropriate
- [ ] Avoid caching sensitive data
- [ ] Clear cache on logout
- [ ] Configure cache limits

## Testing Performance

### Manual Testing

- [ ] Test on low-end device (2GB RAM)
- [ ] Test with slow network (3G)
- [ ] Test with reduce motion enabled
- [ ] Monitor memory usage
- [ ] Check frame rate (60fps target)
- [ ] Test with large datasets (1000+ items)

### Profiling Tools

- Use Flutter DevTools for:
  - Performance overlays
  - Widget rebuild inspector
  - Memory profiling
  - Network profiling
- Use Android Studio Profiler for:
  - CPU profiling
  - Memory allocation
  - Network traffic

### Performance Targets

- **App startup:** < 3 seconds
- **Page transitions:** < 300ms
- **Image loading:** < 500ms
- **List scroll:** 60fps smooth
- **Memory usage:** < 200MB
- **APK size:** < 50MB

## Common Performance Issues

### Issue: Janky List Scrolling

**Solution:**
- Use `ListView.builder` instead of `ListView`
- Set `itemExtent` if item heights are fixed
- Avoid heavy computations in build method
- Use `const` constructors

### Issue: Images Loading Slowly

**Solution:**
- Use `CachedImage` with proper cache dimensions
- Reduce image sizes server-side
- Implement progressive loading
- Use webp format if supported

### Issue: High Memory Usage

**Solution:**
- Clear image cache when not needed
- Dispose controllers properly
- Avoid storing large objects in state
- Use pagination instead of loading all data

### Issue: Slow Animations

**Solution:**
- Reduce animation duration
- Use simpler animations
- Check for heavy widgets in animation
- Respect reduce motion setting

## References

- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices)
- [Flutter Performance Profiling](https://docs.flutter.dev/perf/ui-performance)
- [Cached Network Image Package](https://pub.dev/packages/cached_network_image)
- [Flutter Animate Package](https://pub.dev/packages/flutter_animate)

## Quick Reference

### Common Patterns

```dart
// Loading state
if (isLoading) {
  return SkeletonLoaders.movieCardList();
}

// Image loading
CachedImage(
  imageUrl: url,
  width: 160,
  height: 90,
  memCacheWidth: 160,
  memCacheHeight: 90,
)

// Page transition
PageTransitions.fadeInPage(child)

// Pull-to-refresh
AppRefreshIndicator(
  onRefresh: () async => refresh(),
  child: ListView.builder(...),
)

// Staggered list
ListView.builder(
  itemBuilder: (context, index) {
    return PageTransitions.staggeredItem(
      ItemWidget(item),
      index,
    );
  },
)
```

### Performance Checklist for New Features

Before merging, verify:
- [ ] Skeleton loading states added
- [ ] Images use CachedImage
- [ ] Page transitions implemented
- [ ] Pull-to-refresh added
- [ ] Lists use builder pattern
- [ ] Animations respect reduce motion
- [ ] Tested on low-end device
- [ ] Memory usage within limits
- [ ] Frame rate at 60fps
- [ ] No memory leaks
