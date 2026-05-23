import 'package:flutter/material.dart';

/// Screen-percent helpers (base design width 375).
class Responsive {
  Responsive._();

  static double w(BuildContext context, double percent) =>
      MediaQuery.sizeOf(context).width * (percent / 100);

  static double h(BuildContext context, double percent) =>
      MediaQuery.sizeOf(context).height * (percent / 100);

  static double sp(BuildContext context, double size) {
    final width = MediaQuery.sizeOf(context).width;
    return size * (width / 375.0);
  }

  static bool isNarrow(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 360;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600;

  /// Shell app bar side slots — shrink on narrow phones to avoid action overflow.
  static double shellSideSlot(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    // Right actions need ~100–118px; keep slots wide enough to avoid overflow.
    if (w < 340) return 100;
    if (w < 400) return 108;
    return 118;
  }

  static EdgeInsets screenPadding(BuildContext context) {
    final h = Responsive.w(context, 4);
    final v = Responsive.h(context, 1.5);
    return EdgeInsets.symmetric(horizontal: h.clamp(12.0, 20.0), vertical: v);
  }
}

/// Text that never overflows its parent — ellipsis + optional scale-down.
class OverflowSafeText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;
  final bool scaleDown;

  const OverflowSafeText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.textAlign,
    this.scaleDown = false,
  });

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      softWrap: true,
      textAlign: textAlign,
    );
    if (!scaleDown) return textWidget;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: _alignmentFor(textAlign),
      child: textWidget,
    );
  }

  static Alignment _alignmentFor(TextAlign? align) {
    switch (align) {
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.end:
      case TextAlign.right:
        return Alignment.centerRight;
      default:
        return Alignment.centerLeft;
    }
  }
}
