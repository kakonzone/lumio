import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ad_log.dart';
import '../adsterra/adsterra_banner.dart';

/// Collapsible ad slot that hides entirely on load failure for the session.
///
/// Features:
/// - 10-second timeout for ad load
/// - Session-level failure tracking (persists until app restart)
/// - Collapses to zero height on failure
/// - Never shows placeholder images
class CollapsibleAdSlot extends StatefulWidget {
  const CollapsibleAdSlot({
    super.key,
    required this.placement,
    this.adWidget,
  });

  final String placement;
  final Widget? adWidget;

  @override
  State<CollapsibleAdSlot> createState() => _CollapsibleAdSlotState();
}

class _CollapsibleAdSlotState extends State<CollapsibleAdSlot> {
  static const _timeoutDuration = Duration(seconds: 10);
  static const _sessionFailurePrefix = 'ad_slot_failed_';

  bool _hasFailedThisSession = false;
  bool _isLoading = true;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _checkSessionFailure();
  }

  Future<void> _checkSessionFailure() async {
    final prefs = await SharedPreferences.getInstance();
    final hasFailed = prefs.getBool('$_sessionFailurePrefix${widget.placement}') ?? false;
    
    if (mounted) {
      setState(() {
        _hasFailedThisSession = hasFailed;
        if (!hasFailed) {
          _startTimeout();
        }
      });
    }
  }

  void _startTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_timeoutDuration, () {
      if (mounted && _isLoading) {
        adLog('[CollapsibleAdSlot] Timeout for placement ${widget.placement}');
        _markAsFailed();
      }
    });
  }

  void _markAsFailed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_sessionFailurePrefix${widget.placement}', true);
    
    if (mounted) {
      setState(() {
        _hasFailedThisSession = true;
        _isLoading = false;
      });
    }
  }

  void _onAdLoaded() {
    _timeoutTimer?.cancel();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onAdFailed() {
    _timeoutTimer?.cancel();
    adLog('[CollapsibleAdSlot] Ad failed for placement ${widget.placement}');
    _markAsFailed();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hide entirely if failed this session
    if (_hasFailedThisSession) {
      return const SizedBox.shrink();
    }

    // While loading, collapse to zero height (no placeholder)
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    // Show the ad widget if provided
    if (widget.adWidget != null) {
      return widget.adWidget!;
    }

    // Default to AdsterraBanner728 if no custom widget provided
    return AdLoadTracker(
      placement: widget.placement,
      onLoaded: _onAdLoaded,
      onFailed: _onAdFailed,
      child: const AdsterraBanner728(
        placement: 'home_bottom_banner',
      ),
    );
  }
}

/// Wrapper widget to track ad load events
class AdLoadTracker extends StatefulWidget {
  const AdLoadTracker({
    super.key,
    required this.placement,
    required this.onLoaded,
    required this.onFailed,
    required this.child,
  });

  final String placement;
  final VoidCallback onLoaded;
  final VoidCallback onFailed;
  final Widget child;

  @override
  State<AdLoadTracker> createState() => _AdLoadTrackerState();
}

class _AdLoadTrackerState extends State<AdLoadTracker> {
  bool _hasNotified = false;

  void _notifyLoaded() {
    if (!_hasNotified) {
      _hasNotified = true;
      widget.onLoaded();
    }
  }

  void _notifyFailed() {
    if (!_hasNotified) {
      _hasNotified = true;
      widget.onFailed();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Note: This is a simplified tracker. In a real implementation,
    // you would need to integrate with the actual ad widget's load callbacks.
    // For now, we assume the ad loads successfully if it renders.
    // The actual failure detection would need to come from the ad network's callbacks.
    
    return NotificationListener<AdLoadNotification>(
      onNotification: (notification) {
        if (notification.placement == widget.placement) {
          if (notification.success) {
            _notifyLoaded();
          } else {
            _notifyFailed();
          }
        }
        return true;
      },
      child: widget.child,
    );
  }
}

/// Notification for ad load events
class AdLoadNotification extends Notification {
  const AdLoadNotification({
    required this.placement,
    required this.success,
  });

  final String placement;
  final bool success;
}
