import '../../config/ad_config.dart';
import '../../config/monetag_config.dart';

/// Picks URLs from Adsterra and Monetag direct links per channel-tap browser open.
/// Rotates sequentially (chain pattern) instead of random for consistent user experience.
class DirectLinkRotator {
  DirectLinkRotator._();

  static int _currentIndex = 0;

  static String? pickUrl() {
    // Combine Adsterra and Monetag direct links for rotation
    final pool = <String>[
      ...AdConfig.adsterraDirectLinksReleaseSafe,
      if (MonetagConfig.isConfigured) MonetagConfig.directLinkUrl,
    ];

    // Filter out empty strings
    final validPool = pool.where((url) => url.trim().isNotEmpty).toList();

    if (validPool.isEmpty) return null;
    
    // Sequential rotation (chain pattern)
    final url = validPool[_currentIndex % validPool.length];
    _currentIndex = (_currentIndex + 1) % validPool.length;
    
    return url;
  }
  
  /// Reset rotation index (for testing or manual reset)
  static void reset() {
    _currentIndex = 0;
  }
}
