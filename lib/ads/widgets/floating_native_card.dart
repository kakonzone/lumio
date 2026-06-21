import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ad_manager.dart';
import '../adsterra/adsterra_native.dart';
import '../state/scroll_idle_notifier.dart';
import '../utils/webview_pool.dart';

/// Bottom-right floating native after scroll idle (30s); dismiss = 5 min cooldown.
class FloatingNativeCard extends StatefulWidget {
  const FloatingNativeCard({
    super.key,
    required this.placement,
    this.bottomMargin = 88,
    this.rightMargin = 16,
    this.height = 120,
  });

  final String placement;
  final double bottomMargin;
  final double rightMargin;
  final double height;

  @override
  State<FloatingNativeCard> createState() => _FloatingNativeCardState();
}

class _FloatingNativeCardState extends State<FloatingNativeCard>
    with SingleTickerProviderStateMixin {
  static const _prefsDismissedUntil = 'lumio_floating_native_dismissed_until';

  ScrollIdleNotifier? _idleNotifier;
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  bool _visible = false;
  bool _webViewMounted = false;
  DateTime? _dismissedUntil;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.15, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    unawaited(_loadDismissedUntil());
  }

  Future<void> _loadDismissedUntil() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_prefsDismissedUntil);
    if (ms != null) {
      _dismissedUntil = DateTime.fromMillisecondsSinceEpoch(ms);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _idleNotifier?.removeListener(_onIdleChanged);
    _idleNotifier = context.read<ScrollIdleNotifier>();
    _idleNotifier!.addListener(_onIdleChanged);
  }

  void _onIdleChanged() {
    if (!mounted) return;
    final idle = _idleNotifier!;
    if (idle.idleReached && !_visible && !_dismissedActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _show());
    }
    if (!idle.idleReached && _visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _slideCtrl.reverse();
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  bool get _dismissedActive =>
      _dismissedUntil != null && DateTime.now().isBefore(_dismissedUntil!);

  void _show() {
    if (_visible || _dismissedActive) return;
    if (!WebViewPool.instance.acquire('floating_${widget.placement}')) return;
    setState(() {
      _visible = true;
      _webViewMounted = true;
    });
    _slideCtrl.forward();
  }

  Future<void> _dismiss() async {
    _dismissedUntil = DateTime.now().add(const Duration(minutes: 5));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _prefsDismissedUntil,
      _dismissedUntil!.millisecondsSinceEpoch,
    );
    if (_webViewMounted) {
      WebViewPool.instance.release('floating_${widget.placement}');
      _webViewMounted = false;
    }
    await _slideCtrl.reverse();
    if (mounted) setState(() => _visible = false);
  }

  @override
  void dispose() {
    _idleNotifier?.removeListener(_onIdleChanged);
    if (_webViewMounted) {
      WebViewPool.instance.release('floating_${widget.placement}');
    }
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdManager.instance.adsEnabled) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: AdManager.instance.adChromeHidden,
      builder: (context, hidden, _) {
        if (hidden) return const SizedBox.shrink();
        return _buildIdleCard(context);
      },
    );
  }

  Widget _buildIdleCard(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Positioned(
      right: widget.rightMargin,
      bottom: widget.bottomMargin,
      width: 300,
      child: SlideTransition(
        position: _slideAnim,
        child: RepaintBoundary(
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                AdsterraNativeBanner(
                  placement: widget.placement,
                  height: widget.height,
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _dismiss,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Provides [ScrollIdleNotifier] + optional floating card overlay for a tab.
class TabAdOverlay extends StatelessWidget {
  const TabAdOverlay({
    super.key,
    required this.child,
    this.showFloatingCard = false,
    this.floatingPlacement = 'tab_floating_native',
  });

  final Widget child;
  final bool showFloatingCard;
  final String floatingPlacement;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ScrollIdleNotifier()..attach(),
      child: Builder(
        builder: (ctx) {
          final idle = ctx.read<ScrollIdleNotifier>();
          return Stack(
            clipBehavior: Clip.none,
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is ScrollUpdateNotification ||
                      n is ScrollStartNotification) {
                    idle.onUserScroll();
                  }
                  return false;
                },
                child: child,
              ),
              if (showFloatingCard && AdManager.instance.adsEnabled)
                FloatingNativeCard(placement: floatingPlacement),
            ],
          );
        },
      ),
    );
  }
}
