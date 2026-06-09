import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:lumio_tv/theme/tokens/colors.dart';
import 'package:lumio_tv/l10n/strings.dart';

/// Feature highlight for "What's New" sheet
class WhatsNewFeature {
  final String title;
  final String description;
  final IconData icon;
  final String? navigationRoute;

  const WhatsNewFeature({
    required this.title,
    required this.description,
    required this.icon,
    this.navigationRoute,
  });
}

/// Manager for "What's New" functionality
class WhatsNewManager {
  static final WhatsNewManager _instance = WhatsNewManager._internal();
  factory WhatsNewManager() => _instance;
  WhatsNewManager._internal();

  String? _lastSeenVersion;
  String? _currentVersion;
  Set<String> _dismissedFeatures = {};

  /// Initialize and load persisted state
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _lastSeenVersion = prefs.getString('last_seen_version');
    _currentVersion = await _getCurrentVersion();
    _dismissedFeatures = prefs.getStringList('dismissed_features')?.toSet() ?? {};
  }

  /// Get current app version
  Future<String> _getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }

  /// Check if "What's New" should be shown
  /// 
  /// Returns true if:
  /// - This is a version update from last seen
  /// - There are features to show
  bool shouldShowWhatsNew(List<WhatsNewFeature> features) {
    if (_lastSeenVersion == null) return true; // First launch
    if (_currentVersion == null) return false;
    if (_lastSeenVersion == _currentVersion) return false; // Same version
    if (features.isEmpty) return false;
    
    return true;
  }

  /// Mark current version as seen
  Future<void> markVersionSeen() async {
    if (_currentVersion == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_seen_version', _currentVersion!);
    _lastSeenVersion = _currentVersion;
  }

  /// Mark a feature as dismissed
  Future<void> dismissFeature(String featureId) async {
    _dismissedFeatures.add(featureId);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('dismissed_features', _dismissedFeatures.toList());
  }

  /// Check if a feature has been dismissed
  bool isFeatureDismissed(String featureId) {
    return _dismissedFeatures.contains(featureId);
  }

  /// Reset dismissed features (for testing or major version bump)
  Future<void> resetDismissedFeatures() async {
    _dismissedFeatures.clear();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dismissed_features');
  }

  /// Reset last seen version (for testing)
  Future<void> resetLastSeenVersion() async {
    _lastSeenVersion = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_seen_version');
  }

  /// Get last seen version
  String? get lastSeenVersion => _lastSeenVersion;

  /// Get current version
  String? get currentVersion => _currentVersion;
}

/// "What's New" sheet widget
/// 
/// Slide-down sheet shown on app update with feature highlights
class WhatsNewSheet extends StatefulWidget {
  final List<WhatsNewFeature> features;
  final VoidCallback? onDismiss;
  final VoidCallback? onFeatureTap;

  const WhatsNewSheet({
    super.key,
    required this.features,
    this.onDismiss,
    this.onFeatureTap,
  });

  @override
  State<WhatsNewSheet> createState() => _WhatsNewSheetState();
}

class _WhatsNewSheetState extends State<WhatsNewSheet> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.7,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTokens.surface2,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: 40,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTokens.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Strings.whatsNewTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTokens.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: Icon(PhosphorIcons.x()),
                      onPressed: _handleDismiss,
                    ),
                  ],
                ),
              ),
              
              // Feature list
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.features.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    color: AppTokens.border,
                  ),
                  itemBuilder: (context, index) {
                    final feature = widget.features[index];
                    return _FeatureTile(
                      feature: feature,
                      onTap: () => _handleFeatureTap(feature),
                    );
                  },
                ),
              ),
              
              // Footer
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Checkbox(
                      value: _dontShowAgain,
                      onChanged: (value) {
                        setState(() {
                          _dontShowAgain = value ?? false;
                        });
                      },
                      fillColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppTokens.accent;
                        }
                        return AppTokens.surface3;
                      }),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _dontShowAgain = !_dontShowAgain;
                          });
                        },
                        child: const Text(
                          Strings.whatsNewDontShowAgain,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTokens.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleDismiss() async {
    if (_dontShowAgain) {
      final manager = WhatsNewManager();
      await manager.markVersionSeen();
    }
    
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    }
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleFeatureTap(WhatsNewFeature feature) async {
    if (widget.onFeatureTap != null) {
      widget.onFeatureTap!();
    }
    
    if (feature.navigationRoute != null && mounted) {
      Navigator.of(context).pop();
      Navigator.of(context).pushNamed(feature.navigationRoute!);
    }
  }
}

/// Individual feature tile
class _FeatureTile extends StatelessWidget {
  final WhatsNewFeature feature;
  final VoidCallback? onTap;

  const _FeatureTile({
    required this.feature,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTokens.accentMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                feature.icon,
                color: AppTokens.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feature.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTokens.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Arrow if navigable
            if (feature.navigationRoute != null)
              Icon(
                PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
                color: AppTokens.textSecondary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget to show "What's New" sheet on app start
/// 
/// Usage in main.dart or root widget:
/// ```dart
/// WhatsNewChecker(
///   features: [
///     WhatsNewFeature(
///       title: 'New Feature',
///       description: 'Description here',
///       icon: PhosphorIcons.star(),
///       navigationRoute: '/feature',
///     ),
///   ],
///   child: YourApp(),
/// )
/// ```
class WhatsNewChecker extends StatefulWidget {
  final List<WhatsNewFeature> features;
  final Widget child;

  const WhatsNewChecker({
    super.key,
    required this.features,
    required this.child,
  });

  @override
  State<WhatsNewChecker> createState() => _WhatsNewCheckerState();
}

class _WhatsNewCheckerState extends State<WhatsNewChecker> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final manager = WhatsNewManager();
    await manager.initialize();
    
    if (mounted) {
      if (manager.shouldShowWhatsNew(widget.features)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showWhatsNewSheet();
        });
      }
    }
  }

  void _showWhatsNewSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WhatsNewSheet(
        features: widget.features,
        onDismiss: () async {
          final manager = WhatsNewManager();
          await manager.markVersionSeen();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
