import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

/// Easter egg types
enum EasterEggType {
  developerMode,
  newYearConfetti,
  konamiCode,
}

/// Easter egg manager for tasteful, subtle hidden features
/// 
/// Features:
/// - Developer mode: Long-press version 7x in Settings → About
/// - New Year confetti: Jan 1 first open
/// - Konami code: ↑↑↓↓←→←BA in Settings
class EasterEggManager {
  static final EasterEggManager _instance = EasterEggManager._internal();
  factory EasterEggManager() => _instance;
  EasterEggManager._internal();

  // Developer mode state
  int _versionTapCount = 0;
  Timer? _versionTapResetTimer;
  final int _requiredTaps = 7;
  bool _developerModeUnlocked = false;

  // Konami code state
  final List<LogicalKeyboardKey> _konamiCode = [
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.keyB,
    LogicalKeyboardKey.keyA,
  ];
  int _konamiIndex = 0;
  bool _konamiUnlocked = false;

  // New Year confetti state
  bool _newYearShown = false;

  /// Initialize and load persisted state
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _developerModeUnlocked = prefs.getBool('developer_mode_unlocked') ?? false;
    _konamiUnlocked = prefs.getBool('konami_unlocked') ?? false;
    _newYearShown = prefs.getBool('new_year_shown_${_getCurrentYear()}') ?? false;
  }

  /// Check if developer mode is unlocked
  bool get developerModeUnlocked => _developerModeUnlocked;

  /// Check if Konami code is unlocked
  bool get konamiUnlocked => _konamiUnlocked;

  /// Handle version tap for developer mode unlock
  /// 
  /// Call this when user taps on the version string in Settings → About
  /// Returns true if developer mode was just unlocked
  Future<bool> handleVersionTap() async {
    _versionTapCount++;
    
    // Provide haptic feedback
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(duration: 50);
    }
    
    // Reset after 2 seconds if not completed
    _versionTapResetTimer?.cancel();
    _versionTapResetTimer = Timer(const Duration(seconds: 2), () {
      _versionTapCount = 0;
    });
    
    // Check if unlocked
    if (_versionTapCount >= _requiredTaps && !_developerModeUnlocked) {
      _developerModeUnlocked = true;
      _versionTapCount = 0;
      _versionTapResetTimer?.cancel();
      
      // Persist
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('developer_mode_unlocked', true);
      
      // Strong haptic feedback for unlock
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: 100, amplitude: 255);
      }
      
      return true;
    }
    
    return false;
  }

  /// Handle key event for Konami code
  /// 
  /// Call this in Settings screen's KeyEvent handler
  /// Returns true if Konami code was just unlocked
  Future<bool> handleKeyEvent(KeyEvent event) async {
    if (_konamiUnlocked) return false;
    
    // Check if this key matches the next in sequence
    if (event.logicalKey == _konamiCode[_konamiIndex]) {
      _konamiIndex++;
      
      // Check if complete
      if (_konamiIndex >= _konamiCode.length) {
        _konamiUnlocked = true;
        _konamiIndex = 0;
        
        // Persist
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('konami_unlocked', true);
        
        // Subtle haptic feedback
        if (await Vibration.hasVibrator()) {
          await Vibration.vibrate(duration: 50);
        }
        
        return true;
      }
    } else {
      // Reset if wrong key
      _konamiIndex = 0;
    }
    
    return false;
  }

  /// Check if New Year confetti should be shown
  /// 
  /// Call on app open to check if today is Jan 1 and haven't shown yet
  /// Returns true if confetti should be shown
  Future<bool> shouldShowNewYearConfetti() async {
    if (_newYearShown) return false;
    
    final now = DateTime.now();
    if (now.month == 1 && now.day == 1) {
      _newYearShown = true;
      
      // Persist
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('new_year_shown_${_getCurrentYear()}', true);
      
      return true;
    }
    
    return false;
  }

  /// Get current year
  int _getCurrentYear() {
    return DateTime.now().year;
  }

  /// Reset developer mode (for testing)
  Future<void> resetDeveloperMode() async {
    _developerModeUnlocked = false;
    _versionTapCount = 0;
    _versionTapResetTimer?.cancel();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('developer_mode_unlocked');
  }

  /// Reset Konami code (for testing)
  Future<void> resetKonami() async {
    _konamiUnlocked = false;
    _konamiIndex = 0;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('konami_unlocked');
  }

  /// Reset New Year confetti (for testing)
  Future<void> resetNewYear() async {
    _newYearShown = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('new_year_shown_${_getCurrentYear()}');
  }

  /// Widget wrapper for version tap handling
  /// 
  /// Usage in Settings → About:
  /// ```dart
  /// EasterEggVersionTap(
  ///   onUnlock: () {
  ///     // Handle developer mode unlock
  ///   },
  ///   child: Text('Version 1.0.0'),
  /// )
  /// ```
}

/// Widget wrapper for version tap easter egg
class EasterEggVersionTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onUnlock;

  const EasterEggVersionTap({
    super.key,
    required this.child,
    this.onUnlock,
  });

  @override
  State<EasterEggVersionTap> createState() => _EasterEggVersionTapState();
}

class _EasterEggVersionTapState extends State<EasterEggVersionTap> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final manager = EasterEggManager();
        final unlocked = await manager.handleVersionTap();
        if (unlocked && widget.onUnlock != null) {
          widget.onUnlock!();
        }
      },
      child: widget.child,
    );
  }
}

/// Widget wrapper for Konami code handling
/// 
/// Usage in Settings screen:
/// ```dart
/// EasterEggKonamiCode(
///   onUnlock: () {
///     // Handle Konami code unlock
///   },
///   child: SettingsScreen(),
/// )
/// ```
class EasterEggKonamiCode extends StatefulWidget {
  final Widget child;
  final VoidCallback? onUnlock;

  const EasterEggKonamiCode({
    super.key,
    required this.child,
    this.onUnlock,
  });

  @override
  State<EasterEggKonamiCode> createState() => _EasterEggKonamiCodeState();
}

class _EasterEggKonamiCodeState extends State<EasterEggKonamiCode> {
  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        // Only process key down events
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        
        final manager = EasterEggManager();
        manager.handleKeyEvent(event).then((unlocked) {
          if (unlocked && widget.onUnlock != null) {
            widget.onUnlock!();
          }
        });
        return KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }
}

/// New Year confetti widget (placeholder)
/// 
/// Actual confetti animation should use confetti package
/// This is a placeholder structure
class NewYearConfetti extends StatefulWidget {
  const NewYearConfetti({super.key});

  @override
  State<NewYearConfetti> createState() => _NewYearConfettiState();
}

class _NewYearConfettiState extends State<NewYearConfetti> {
  @override
  void initState() {
    super.initState();
    // TODO: Trigger confetti animation here
    // Use confetti package: https://pub.dev/packages/confetti
  }

  @override
  Widget build(BuildContext context) {
    // Placeholder - replace with actual confetti widget
    return const SizedBox.shrink();
  }
}
