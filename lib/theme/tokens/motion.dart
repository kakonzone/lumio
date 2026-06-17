// lib/theme/tokens/motion.dart
import 'package:flutter/widgets.dart';

class MotionTokens {
  // Duration tokens
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationBase = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);

  // Curve tokens
  static const Curve curveDefault = Curves.easeOutCubic;
  static const Curve curveSpring = Curves.easeOutBack;
  static const Curve curveSharp = Curves.easeInOutQuart;

  // Animation durations for specific use cases
  static const Duration pressDown = Duration(milliseconds: 100);
  static const Duration pressUp = Duration(milliseconds: 200);
  static const Duration navIndicator = Duration(milliseconds: 200);
  static const Duration listStagger = Duration(milliseconds: 40);
  static const Duration pageTransition = Duration(milliseconds: 250);
  static const Duration bottomSheet = Duration(milliseconds: 300);
  static const Duration modal = Duration(milliseconds: 200);
  static const Duration shimmerCycle = Duration(milliseconds: 1200);

  // Animation curves for specific use cases
  static const Curve pressCurve = Curves.easeOutCubic;
  static const Curve navCurve = Curves.easeOutCubic;
  static const Curve listCurve = Curves.easeOutCubic;
  static const Curve pageCurve = Curves.easeOutCubic;
  static const Curve shimmerCurve = Curves.easeInOut;

  // Reduce motion check
  static bool reduceMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  // Get duration respecting reduce motion setting
  static Duration getDuration(BuildContext context, Duration defaultDuration) {
    return reduceMotion(context) ? Duration.zero : defaultDuration;
  }

  // Get curve respecting reduce motion setting
  static Curve getCurve(BuildContext context, Curve defaultCurve) {
    return reduceMotion(context) ? Curves.linear : defaultCurve;
  }
}
