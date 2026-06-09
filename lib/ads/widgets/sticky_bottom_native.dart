import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ads/ad_manager.dart';
import '../../ads/adsterra/adsterra_native.dart';
import '../../config/ad_config.dart';

/// Sticky bottom native ad for Categories tab only.
class StickyBottomNative extends StatefulWidget {
  const StickyBottomNative({super.key});

  @override
  State<StickyBottomNative> createState() => _StickyBottomNativeState();
}

class _StickyBottomNativeState extends State<StickyBottomNative> {
  static const String _dismissedSessionKeyPrefix = 'sticky_native_dismissed_session_';
  
  bool _visible = true;
  String? _currentSessionId;

  @override
  void initState() {
    super.initState();
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _checkDismissal();
  }

  Future<void> _checkDismissal() async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_dismissedSessionKeyPrefix$_currentSessionId';
    final wasDismissed = prefs.getBool(key) ?? false;
    
    if (wasDismissed && mounted) {
      setState(() {
        _visible = false;
      });
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_dismissedSessionKeyPrefix$_currentSessionId';
    await prefs.setBool(key, true);
    
    if (mounted) {
      setState(() {
        _visible = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || !AdManager.instance.showAdsterraWebViewSlots) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Native ad content
          AdsterraNativeBanner(
            placement: 'categories_sticky_bottom',
            height: 60,
            userVisible: AdConfig.playerAdsUserVisible,
          ),
          // Dismiss button
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
