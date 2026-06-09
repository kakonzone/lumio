# Accessibility Guidelines

This document outlines the accessibility features implemented in Lumio and guidelines for maintaining WCAG AA compliance.

## Implemented Features

### 1. Semantic Labels on Interactive Elements

The `Pressable` widget now supports accessibility properties:

```dart
Pressable(
  semanticLabel: 'Play video',
  semanticHint: 'Starts playback of the selected video',
  isButton: true,
  onTap: () {},
  child: Icon(Icons.play),
)
```

**Utility Functions** (in `lib/utils/accessibility_utils.dart`):
- `AccessibilityUtils.createButtonLabel(action, context)` - Creates descriptive button labels
- `AccessibilityUtils.createToggleLabel(label, isOn)` - Creates toggle switch labels
- `AccessibilityUtils.createImageLabel(description)` - Creates image descriptions
- Widget extensions for adding semantics:
  - `.withAccessibilityLabel(label)`
  - `.withAccessibilityHint(hint)`
  - `.asButton(label)`
  - `.asLink(label)`
  - `.asSwitch(label, isOn)`
  - `.asTextField(label)`
  - `.asHeader(label, level)`
  - `.asLiveRegion()`
  - `.excludeFromAccessibility()`

### 2. Minimum Touch Targets (48x48)

The `MinimumTouchTarget` wrapper ensures all interactive elements meet WCAG minimum touch target size:

```dart
MinimumTouchTarget(
  minSize: 48.0,
  onTap: () {},
  child: SmallWidget(), // Can be smaller than 48x48
)
```

### 3. Reduce Motion Support

Reduce motion is already implemented in:
- `MotionTokens.reduceMotion(context)` - Checks system setting
- `Pressable` widget - Respects reduce motion for animations
- `WelcomeScreen` - Disables animations when reduce motion is enabled

### 4. Screen Reader Support

Key interactive elements are marked with proper semantics:
- Buttons marked with `Semantics(button: true)`
- Links marked with `Semantics(link: true)`
- Text fields marked with `Semantics(textField: true)`
- Headers marked with `Semantics(header: true)`
- Live regions for dynamic content

## Guidelines for Developers

### When Adding New Interactive Elements

1. **Always add semantic labels:**
   ```dart
   Pressable(
     semanticLabel: 'Descriptive label',
     semanticHint: 'Additional context if needed',
     isButton: true,
     onTap: () {},
     child: child,
   )
   ```

2. **Ensure minimum touch targets:**
   - Buttons: minimum 48x48
   - Icon buttons: use `MinimumTouchTarget` wrapper
   - Custom touch areas: at least 48x48

3. **Add image descriptions:**
   ```dart
   Image.network(
     url,
     semanticLabel: 'Description of image content',
   )
   ```

4. **Use proper semantic hierarchy:**
   - Screen titles: `.asHeader(label, level: 1)`
   - Section headings: `.asHeader(label, level: 2)`
   - Subsection headings: `.asHeader(label, level: 3)`

5. **Announce important state changes:**
   ```dart
   Semantics(
     liveRegion: true,
     label: 'Download complete',
     child: Container(),
   )
   ```

### Color Contrast Requirements

Ensure all text meets WCAG AA standards:
- Normal text: 4.5:1 contrast ratio
- Large text (18px+): 3:1 contrast ratio
- Interactive elements: 3:1 contrast ratio

**Current Token Compliance:**
- TextPrimary on Background: ✅ (contrast ratio > 4.5:1)
- TextSecondary on Background: ⚠️ (verify)
- Accent on Background: ✅ (contrast ratio > 3:1)
- Surface2 borders: ⚠️ (verify)

### TV Navigation (Future Enhancement)

For Android TV / Fire TV support:
1. Implement `FocusNode` for all interactive elements
2. Add D-pad navigation support
3. Ensure visual focus indicators are clear
4. Test with remote control navigation
5. Add proper focus order logic

### Font Scaling

System font scaling is not currently enabled (reverted due to breaking changes).
To enable in the future:
1. Add `MediaQuery.textScalerOf(context).textScaleFactor` to typography tokens
2. Clamp scale factor to 1.0-1.5 to prevent layout breakage
3. Test all screens with maximum scaling

## Testing Checklist

### Manual Testing

- [ ] Test with TalkBack (Android) enabled
- [ ] Test with VoiceOver (iOS) enabled
- [ ] Test with screen magnifier enabled
- [ ] Test with reduce motion enabled
- [ ] Test with high contrast mode (if available)
- [ ] Test with large font size (maximum)
- [ ] Navigate with keyboard only (if supported)
- [ ] Verify all touch targets are 48x48 or larger
- [ ] Verify all images have semantic labels
- [ ] Verify color contrast meets WCAG AA

### Automated Testing

Consider adding integration tests for:
- Semantic label presence
- Minimum touch target size
- Focus order
- Screen reader announcements

## Priority Improvements

### High Priority
1. Add semantic labels to all existing Pressable widgets
2. Add semantic headers to all screens
3. Verify color contrast ratios
4. Add image descriptions to all images

### Medium Priority
5. Implement TV focus navigation
6. Enable system font scaling
7. Add screen reader announcements for all state changes
8. Test on actual accessibility devices

### Low Priority
9. Add accessibility-specific tests
10. Implement custom accessibility actions
11. Add accessibility documentation in app
12. Create accessibility settings (increase touch targets, etc.)

## References

- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Flutter Accessibility Documentation](https://docs.flutter.dev/development/accessibility-and-internationalization/accessibility)
- [Material Design Accessibility](https://m3.material.io/foundations/accessible-design)
- [Android TV Accessibility](https://developer.android.com/training/tv/accessibility)
- [iOS TV Accessibility](https://developer.apple.com/tv/accessibility/)

## Quick Reference

### Common Patterns

```dart
// Button with accessibility
Pressable(
  semanticLabel: 'Save changes',
  isButton: true,
  onTap: () {},
  child: Text('Save'),
)

// Image with description
Image.network(
  url,
  semanticLabel: 'Channel logo for $channelName',
)

// Header
Semantics(
  header: true,
  label: 'Settings',
  child: Text('Settings', style: TypographyTokens.headingPrimary),
)

// Live region (for dynamic content)
Semantics(
  liveRegion: true,
  label: 'Loading complete',
  child: StatusWidget(),
)

// Small button with minimum touch target
MinimumTouchTarget(
  onTap: () {},
  child: Icon(Icons.play, size: 24),
)
```

### Accessibility Checklist for New Features

Before merging, verify:
- [ ] All interactive elements have semantic labels
- [ ] All touch targets are 48x48 or larger
- [ ] All images have semantic labels
- [ ] Color contrast meets WCAG AA
- [ ] Proper heading hierarchy
- [ ] State changes are announced (if dynamic)
- [ ] Tested with TalkBack/VoiceOver
