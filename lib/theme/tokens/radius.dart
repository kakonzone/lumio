// lib/theme/tokens/radius.dart
import 'package:flutter/painting.dart';

class RadiusTokens {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double full = 999.0;

  static const BorderRadius circularXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius circularSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius circularMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius circularLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius circularFull = BorderRadius.all(Radius.circular(full));
}
