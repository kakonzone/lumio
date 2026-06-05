import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/blocked_apps_screen.dart';
import '../security/blocked_apps_guard.dart';

/// Re-checks for conflicting apps when the user returns from uninstall settings.
class BlockedAppsOverlay extends StatefulWidget {
  const BlockedAppsOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<BlockedAppsOverlay> createState() => _BlockedAppsOverlayState();
}

class _BlockedAppsOverlayState extends State<BlockedAppsOverlay>
    with WidgetsBindingObserver {
  List<String>? _blockingLabels;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_scan());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_scan());
    }
  }

  Future<void> _scan() async {
    if (!BlockedAppsGuard.shouldEnforce()) return;
    final labels = await BlockedAppsGuard.installedLabels();
    if (!mounted) return;
    setState(() {
      _blockingLabels = labels.isEmpty ? null : labels;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_blockingLabels == null || _blockingLabels!.isEmpty) {
      return widget.child;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        BlockedAppsScreen(
          appLabels: _blockingLabels!,
          onCleared: () {
            setState(() => _blockingLabels = null);
          },
        ),
      ],
    );
  }
}
