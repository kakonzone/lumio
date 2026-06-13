import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

/// Sound types for UI feedback
enum SoundType {
  tabSwitch,
  success,
  error,
  modalOpen,
  press,
  dismiss,
  achievement,
}

/// Manager for playing UI sounds
///
/// Sounds sourced from Material Sound Library (royalty-free)
/// Disabled by default, can be enabled in Settings → Display
class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isEnabled = false;
  bool _isInitialized = false;

  /// Initialize the sound manager and load user preference
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadPreference();
      _isInitialized = true;
    } catch (e) {
      // Silently fail - sound is optional
      print('SoundManager initialization failed: $e');
    }
  }

  /// Load user preference from SharedPreferences
  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('ui_sounds_enabled') ?? false;
    } catch (e) {
      _isEnabled = false;
    }
  }

  /// Save user preference
  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ui_sounds_enabled', enabled);
      _isEnabled = enabled;
    } catch (e) {
      // Silently fail
    }
  }

  /// Check if sounds are enabled
  bool get isEnabled => _isEnabled;

  /// Play a sound of the given type
  ///
  /// This is a placeholder implementation. To enable actual sounds:
  /// 1. Add audio files to assets/audio/ directory
  /// 2. Update pubspec.yaml to include audio assets
  /// 3. Uncomment the asset loading and playback logic
  Future<void> play(SoundType type) async {
    if (!_isEnabled) return;

    try {
      // ISSUE: Uncomment when audio assets are added
      // See: https://github.com/your-repo/issues/XXX
      // await _playAsset(type);

      // For now, just haptic feedback
      _playHaptic(type);
    } catch (e) {
      // Silently fail - sound is optional
    }
  }

  /// Play haptic feedback for sound type
  void _playHaptic(SoundType type) {
    switch (type) {
      case SoundType.tabSwitch:
        // Light impact
        HapticFeedback.lightImpact();
        break;
      case SoundType.success:
      case SoundType.achievement:
        // Heavy impact
        HapticFeedback.heavyImpact();
        break;
      case SoundType.error:
        // Medium impact
        HapticFeedback.mediumImpact();
        break;
      case SoundType.modalOpen:
        // Medium impact
        HapticFeedback.mediumImpact();
        break;
      case SoundType.press:
        // Light impact
        HapticFeedback.lightImpact();
        break;
      case SoundType.dismiss:
        // Light impact
        HapticFeedback.lightImpact();
        break;
    }
  }

  /// Play audio asset (placeholder implementation)
  Future<void> _playAsset(SoundType type) async {
    final assetPath = _getAssetPath(type);

    if (assetPath == null) return;

    await _audioPlayer.play(AssetSource(assetPath));
  }

  /// Get asset path for sound type
  ///
  /// Assets should be placed in assets/audio/ directory:
  /// - tab_switch.mp3 (300ms)
  /// - success.mp3 (400ms)
  /// - error.mp3 (200ms)
  /// - modal_open.mp3 (300ms)
  /// - press.mp3 (100ms)
  /// - dismiss.mp3 (100ms)
  /// - achievement.mp3 (500ms)
  String? _getAssetPath(SoundType type) {
    switch (type) {
      case SoundType.tabSwitch:
        return 'audio/tab_switch.mp3';
      case SoundType.success:
        return 'audio/success.mp3';
      case SoundType.error:
        return 'audio/error.mp3';
      case SoundType.modalOpen:
        return 'audio/modal_open.mp3';
      case SoundType.press:
        return 'audio/press.mp3';
      case SoundType.dismiss:
        return 'audio/dismiss.mp3';
      case SoundType.achievement:
        return 'audio/achievement.mp3';
    }
  }

  /// Dispose resources
  void dispose() {
    _audioPlayer.dispose();
  }

  /// Convenience method to play tab switch sound
  static Future<void> tabSwitch() async {
    final manager = SoundManager();
    await manager.play(SoundType.tabSwitch);
  }

  /// Convenience method to play success sound
  static Future<void> success() async {
    final manager = SoundManager();
    await manager.play(SoundType.success);
  }

  /// Convenience method to play error sound
  static Future<void> error() async {
    final manager = SoundManager();
    await manager.play(SoundType.error);
  }

  /// Convenience method to play modal open sound
  static Future<void> modalOpen() async {
    final manager = SoundManager();
    await manager.play(SoundType.modalOpen);
  }

  /// Convenience method to play press sound
  static Future<void> press() async {
    final manager = SoundManager();
    await manager.play(SoundType.press);
  }

  /// Convenience method to play dismiss sound
  static Future<void> dismiss() async {
    final manager = SoundManager();
    await manager.play(SoundType.dismiss);
  }

  /// Convenience method to play achievement sound
  static Future<void> achievement() async {
    final manager = SoundManager();
    await manager.play(SoundType.achievement);
  }
}
