import 'package:flutter/material.dart';

/// Builds ad WebViews only when within [preloadPx] of the visible viewport.
class LazyAdViewport extends StatefulWidget {
  const LazyAdViewport({
    super.key,
    required this.placeholderHeight,
    required this.builder,
    this.preloadPx = 200,
  });

  final double placeholderHeight;
  final Widget Function() builder;
  final double preloadPx;

  @override
  State<LazyAdViewport> createState() => _LazyAdViewportState();
}

class _LazyAdViewportState extends State<LazyAdViewport> {
  final GlobalKey _key = GlobalKey();
  bool _nearViewport = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateVisibility());
  }

  void _updateVisibility() {
    if (!mounted) return;
    final box = _key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;

    final topLeft = box.localToGlobal(Offset.zero);
    final bottom = topLeft.dy + box.size.height;
    final viewportH = MediaQuery.sizeOf(context).height;
    final near = bottom >= -widget.preloadPx && topLeft.dy <= viewportH + widget.preloadPx;

    if (near != _nearViewport) {
      setState(() => _nearViewport = near);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _updateVisibility());
        return false;
      },
      child: SizedBox(
        key: _key,
        height: widget.placeholderHeight,
        child: _nearViewport
            ? widget.builder()
            : ColoredBox(color: Colors.transparent),
      ),
    );
  }
}
