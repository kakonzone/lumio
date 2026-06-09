# Vibe Lock — Cinematic-Premium Design Direction

## Vibe Commitment

**Chosen Direction:** Cinematic-Premium

This is our design personality — the "feeling" of the app. Every design decision should align with this direction.

### Core Attributes

**Apple TV Adjacent:**
- Premium streaming app aesthetics
- Clean, editorial layouts
- High-quality imagery prioritized
- Dark-first with pure black background (#000000)
- Refined typography with elegant hierarchy

**Dark + Editorial Typography:**
- Pure black background (no dark gray)
- Inter for UI elements (clean, readable)
- Instrument Serif for display headings (cinematic, premium)
- Limited type scale (only 6 sizes: caption, label, body, title, heading, display)
- Precise line heights (1.1-1.6 range)
- Tight letter spacing (-0.02 to 0)

**Restrained Color Palette:**
- Single accent color: #FF6B1A (burnt orange)
- Surface colors: #1C1C1C (surface1), #2D2D2D (surface2), #3D3D3D (surface3)
- Text hierarchy: #FFFFFF (primary), #B4B4B4 (secondary), #7A7A7A (tertiary)
- No other colors unless semantic (success #00C853, danger #FF3B30, live red #E50914)
- Gradients: only for hero overlays, max 2 stops, used sparingly

### Design Token System

All design decisions must use the token system in `lib/theme/tokens/`:

- **colors.dart:** Accent, Surface1/2/3, TextPrimary/Secondary/Tertiary, Semantic colors
- **typography.dart:** Inter + Instrument Serif, exact type scale, line heights, letter spacing
- **spacing.dart:** 4/8/12/16/20/24/32/40/48px scale
- **radius.dart:** 4/8/12/16/999 scale
- **motion.dart:** Animation curves and durations
- **shadows.dart:** Shadow tokens (single layer, subtle)
- **elevation.dart:** Depth levels (subtle 3-step scale)

### Visual Rules

**Dividers:**
- 1px border color only, never thicker
- Use tokens.AppTokens.border

**Shadows:**
- Single layer only
- Subtle, never multi-blur stack
- Use shadow tokens from elevation.dart
- Depth levels: none/elevated/overlay only

**Gradients:**
- Max 2 stops only
- Used sparingly for hero overlays only
- Linear gradients preferred over radial
- No complex multi-stop gradients

**Animations:**
- Always respect reduce motion setting
- Use MotionTokens.reduceMotion(context) check
- Duration: 100ms (press), 200ms (transition), 300ms (page), 1200ms (shimmer)
- Curves: easeInOut (default), elasticOut (spring), easeOut (enter), easeIn (exit)

**Icons:**
- Phosphor library only
- Consistent weight: Regular for UI, Duotone for active states, Fill for filled
- Size: 16px (small), 20px (medium), 24px (large)
- Never mix icon families

## Sound Design (Optional)

### UI Sound Library

Create `lib/utils/sound_manager.dart` with sounds from Material Sound Library:

**Sounds Required:**
- Tab switch: soft tick (300ms)
- Success: warm chime (400ms)
- Error: low thud (200ms)
- Modal open: whoosh (300ms)

**Implementation:**
```dart
class SoundManager {
  static Future<void> play(SoundType type) async {
    if (!SoundManager.enabled) return;
    // Play sound using audioplayers or similar
  }
  
  static bool enabled = false;
}
```

**Settings Toggle:**
- Settings → Display → UI Sounds (toggle, default off)
- Respect user preference throughout

## Loading Personality

Replace generic "Loading..." with rotating contextual messages:

### Contextual Loading Messages

**Data Loading:**
- "Tuning in..."
- "Fetching channels..."
- "Loading your library..."

**Search:**
- "Searching..."
- "Refining results..."

**Playback:**
- "Warming up..."
- "Buffering..."
- "Connecting..."

**Network:**
- "Connecting..."
- "Syncing..."

### Implementation:

```dart
class LoadingMessages {
  static const List<String> data = [
    "Tuning in...",
    "Finding your channels...",
    "Warming up the screen...",
  ];
  
  static String getRandom(List<String> messages) {
    return messages[DateTime.now().millisecond % messages.length];
  }
  
  static String getData() => getRandom(data);
}
```

Cycle every 2 seconds during operations > 1 second.

## Easter Eggs

### Implemented Easter Eggs

**1. Developer Mode Toggle:**
- Long-press app version 7 times in Settings → About
- Subtle vibration feedback on each press
- Success: toggle appears in debug menu
- No popup, no notification

**2. New Year Confetti:**
- Check date on app open (Jan 1)
- If first open on Jan 1: subtle confetti from top
- One-time only per year
- No popup, no delay

**3. Konami Code:**
- In Settings: ↑↑↓↓←→←BA
- Unlocks custom theme accent color picker
- Subtle checkmark confirmation
- Toggle available in Settings → Display

**Guidelines:**
- Understated, no popups
- No mid-task interruptions
- One-time triggers only
- Silent or haptic feedback only

## Detail Polish

### Visual Consistency Rules

**Dividers:**
- Always 1px
- Use tokens.AppTokens.border
- No thicker dividers anywhere

**Shadows:**
- Always single layer
- Use elevation tokens
- Never multi-blur stack
- Opacity: 0.10 (elevated), 0.20 (overlay), 0.30 (floating)

**Gradients:**
- Max 2 stops
- Linear only (no radial)
- Hero overlays only
- Color stops: accent + transparent
- Direction: top-bottom, top-left to bottom-right

**Animations:**
- Always check reduce motion
- Disable animations when enabled
- MotionTokens for consistency
- Spring curves for playful elements
- EaseInOut for transitions

**Icons:**
- Phosphor Regular for UI
- Phosphor Duotone for active states
- Phosphor Fill for filled elements
- Never mix icon families
- Consistent sizing by usage

### Consistency Audit Checklist

- [ ] All dividers use 1px border color
- [ ] All shadows use elevation tokens (single layer)
- [ ] All gradients have max 2 stops
- [ ] All animations check reduce motion
- [ ] All icons from Phosphor library only
- [ ] Icon weights consistent by usage
- [ ] No mixed icon families
- [ ] Padding follows spacing tokens
- [ ] Border radius follows radius tokens
- [ ] Colors use token system
- [ ] Typography uses type scale exactly
- [ ] No hardcoded colors, radii, or spacing

## Edge Case States

Every screen must have designed states for:

**Loading State:**
- Skeleton loader with shimmer
- Or contextual loading message
- Animation respects reduce motion
- Never shows spinner without context

**Empty State:**
- Using EmptyState widget with illustration
- Specific message for context
- Action button when applicable
- Background: pure black

**Error State:**
- Error message (specific, not generic)
- Clear description
- Retry button with accent color
- Haptic feedback on tap
- Optional help link

**Offline State:**
- "No internet connection"
- Reconnect button
- Subtle illustration
- Cache if applicable
- Check connection periodically

**Success/Populated State:**
- Content displayed clearly
- No awkward gaps
- Proper pagination
- Loading indicator for more content
- Empty state if applicable

**Long Content:**
- Text truncation with ellipsis
- Title maxLines: 2
- Body maxLines: 3
- View more expansion for long text
- Horizontal scroll for long lists

**Short Content:**
- No extra whitespace
- Cards collapse appropriately
- Lists show "No items" if empty
- No awkward empty spaces

## Onboarding for Returning Users

**"What's New" System:**

### Trigger:
- App update with significant features (major/minor version bump with visible changes)
- First open after update
- Subtle sheet slide-down from top
- Dismissible by swipe down

### Content:
- Feature highlights with icons
- Tap to navigate to feature
- "Don't show this again" checkbox
- Dismiss button

### Storage:
- Track last seen version
- Track which features dismissed
- Reset on major version bump
- Available from Settings → About

### Implementation:

```dart
class WhatsNewSheet extends StatefulWidget {
  final String currentVersion;
  final List<WhatsNewFeature> features;
  
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.7,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: tokens.AppTokens.surface2,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(tokens.RadiusTokens.lg),
            ),
          ),
          child: Column(
            children: [
              // Header with dismiss
              // Feature list
              // Footer with "Don't show again"
            ],
          ),
        );
      },
    );
  }
}
```

## Personality Moments

### Implemented Moments

**1. 404 / Not Found:**
- Screen: Search results
- Message: "Couldn't find that one."
- Illustration: Magnifying glass with confused face (subtle)
- Tone: Warm, empathetic, not robot

**2. First Favorite Added:**
- Trigger: User adds first channel to favorites
- Animation: Heart icon pulse (scale 1.0 → 1.2 → 1.0, 200ms)
- Haptic: Medium impact
- Confetti burst (subtle, top-center)
- No popup, no delay

**3. 100th Hour Watched:**
- Trigger: App tracking hits 100 hours
- Display: Subtle toast from top
- Message: "100 hours of entertainment 🎉"
- Icon: Party horn
- Haptic: Heavy impact
- Dismissible tap
- Only once per user

**Guidelines:**
- Rare triggers (once per user/session)
- Subtle animations
- No mid-task interruptions
- Dismissible without action
- Warm tone, not celebration overload

## Brand Voice Checklist

### String Guidelines

**Every string must be:**

✅ **Confident, not eager:**
- "Your watchlist" (not "Check out your watchlist!")
- "Channels" (not "Explore our channels!")
- Use periods, not exclamation points

✅ **Direct, not chatty:**
- "Loading..." (not "We're just getting things ready for you!")
- "No results" (not "Sorry, we couldn't find what you're looking for")
- Keep it brief

✅ **Warm, not cute:**
- "Couldn't find that one." (not "Oopsie! We couldn't find that one!")
- "Added to favorites" (not "Yay! Added to your favorites!")
- Avoid emojis in UI text (only in special moments)

✅ **Human, not corporate:**
- "Your playlists" (not "Content Management")
- "Watch later" (not "Save for Later Viewing")
- Conversational, functional

✅ **Specific, not generic:**
- "Tuning in..." (not "Loading...")
- "Finding your channels..." (not "Loading data...")
- Context-specific when possible

### Brand Voice Audit Checklist

- [ ] No exclamation points in UI strings
- [ ] No emojis except in personality moments
- [ ] No first-person pronouns ("we") in UI
- [ ] No corporate jargon ("Content", "Content Management")
- [ ] No placeholder text ("Lorem ipsum", "Test")
- [ ] No filler words ("just", "very", "really")
- [ ] No emoji-only strings (must have text)
- [ ] Action verbs: direct imperative ("Search", not "Let's search")
- [ ] Error messages: specific, helpful, not blaming ("We couldn't connect" → "Connection failed")

## Final QA Process

### On-Device Walkthrough

**Before Shipping:**

1. **Fresh Install:**
   - Open app fresh on real device
   - Walk every flow without touching code
   - Note generic/default moments

2. **Critical Flows:**
   - Onboarding
   - Home → Detail → Player → Back
   - Search → Result → Player
   - Settings navigation
   - Favorites add/remove
   - Live TV browsing

3. **Note Categories:**
   - Feels generic or AI-generated
   - Inconsistent spacing/padding
   - Mixed icon weights or families
   - Off-palette colors
   - Default Flutter widgets
   - Missing loading states
   - Awkward transitions
   - Unclear error messages

4. **Fix Each:**
   - Update design tokens if needed
   - Replace with custom widgets
   - Add skeleton states
   - Improve typography
   - Fix transitions

### Screenshot Grid Audit

**Screens to Screenshot:**

1. Home screen (hero + categories)
2. Detail screen (movie/show info)
3. Player screen (controls + video)
4. Search screen (results + empty)
5. Favorites screen (empty + populated)
6. Settings screen (all sections)
7. Live TV screen (3-panel)
8. Onboarding (all screens)
9. Search (autocomplete + results)

**Audit Grid Layout:**

1. Take screenshots of each screen
2. Arrange in a 3x3 grid
3. Check for:
   - Consistent padding across screens
   - Consistent corner radius
   - Consistent text sizes
   - Consistent icon sizes
   - No color drift
   - No mixed icon weights

## Implementation Checklist

### Vibe Lock (Cinematic-Premium)

- [ ] Pure black background (#000000) everywhere
- [ ] Accent color #FF6B1A only (except semantic)
- [ ] Surface colors: #1C1C1C, #2D2D2D, #3D3D3D only
- [ ] Inter for all UI typography
- [ ] Instrument Serif for display headings only
- [ ] Type scale exactly 6 sizes (no custom sizes)
- [ ] Line heights: 1.1-1.6 range only
- [ ] Letter spacing: -0.02 to 0 range only
- [ ] Spacing: 4/8/12/16/20/24/32/40/48px only
- [ ] Border radius: 4/8/12/16/999 only
- [ ] Single-layer shadows only
- [ ] 2-stop gradients max (hero only)
- [ ] Phosphor icons only
- [ ] Icon weight: Regular/Duotone/Fill (no mix)
- [ ] Reduce motion checked on all animations

### Loading Personality

- [ ] Replace "Loading..." with contextual messages
- [ ] Data loading: "Tuning in..." / "Finding channels..." / "Warming up..."
- [ ] Search: "Searching..." / "Refining results..."
- [ ] Playback: "Warming up..." / "Buffering..." / "Connecting..."
- [ ] Network: "Connecting..." / "Syncing..."
- [ ] Cycle messages every 2 seconds
- [ ] Only for operations > 1 second

### Easter Eggs

- [ ] Developer mode: long-press version 7x
- [ ] New Year confetti: Jan 1 detection
- [ ] Konami code: ↑↑↓↓←→←BA in Settings
- [ ] All understated, no popups
- [ ] Haptic feedback only
- [ ] One-time triggers only

### Edge Case States

- [ ] Loading: skeleton + contextual message
- [ ] Empty: EmptyState + illustration
- [ ] Error: specific message + retry
- [ ] Offline: "No internet" + reconnect
- [ ] Success: content + pagination
- [ ] Long content: truncation + ellipsis
- [ ] Short content: no awkward gaps

### "What's New" for Updates

- [ ] Track last seen version
- [ ] Show sheet on major version bump
- [   Feature highlights with icons
- [ ] Tap to navigate
- [ ] Dismissible + "Don't show again"
- [ ] Available in Settings → About

### Personality Moments

- [ ] 404: "Couldn't find that one" + illustration
- [ ] First favorite: heart pulse + confetti
- [ ] 100th hour: toast with celebration
- [ ] Subtle animations
- [ ] No mid-task interruptions

### Brand Voice

- [ ] No exclamation points in UI
- [ ] No emojis in UI text (except personality moments)
- [ ] No first-person pronouns
- [ ] No corporate jargon
- [ ] No placeholder text
- [ ] No filler words
- [ ] Direct imperative verbs
- [ ] Specific error messages
- [ ] Warm, human tone

### Final QA

- [ ] Fresh install on real device
- [ ] Walk every flow without code
- [ ] Note generic moments
- [ ] Fix each before shipping
- [ ] Screenshot all screens
- [ ] Arrange in 3x3 grid audit
- [ ] Fix inconsistencies

## Before Shipping

### Required Deliverables:

1. ✅ Vibe lock document (this file)
2. ⏳ Sound manager (optional, in `lib/utils/sound_manager.dart`)
3. ⏳ Loading message utilities (in `lib/utils/loading_messages.dart`)
4. ⏳ Easter egg manager (in `lib/utils/easter_eggs.dart`)
5. ⏳ "What's new" widget (in `lib/widgets/whats_new/whats_new_sheet.dart`)
6. ⏳ Personality moments manager (in `lib/utils/personality_moments.dart`)
7. ⏳ Brand voice audit (review all strings against checklist)
8. ⏳ Visual consistency audit (review all screens)
9. ⏳ Edge case state audit (review all screens)
10. ⏳ On-device QA walkthrough
11. ⏳ Screenshot grid audit

### Vibe Lock Status:

- **Direction:** Cinematic-Premium ✅
- **Color Palette:** Restrained, accent-only ✅
- **Typography:** Inter + Instrument Serif ✅
- **Spacing/Radii:** Token-based ✅
- **Icons:** Phosphor only ✅
- **Animations:** Motion tokens + reduce motion ✅
- **Dividers/Shadows/Gradients:** Strict rules ✅

### Next Steps:

1. Implement sound manager (optional)
2. Add loading message utilities
3. Implement easter egg manager
4. Create "What's New" widget
5. Add personality moment tracking
6. Audit and fix brand voice in strings
7. Perform visual consistency audit
8. Ensure all edge cases are handled
9. Complete on-device QA
10. Generate screenshot grid for final review

This document serves as the single source of truth for the Lumio design vibe lock. Every design decision should reference this document.
