import 'package:flutter/material.dart';

enum PlayerFitMode {
  fit,
  fill,
  stretch,
  original,
  ratio16_9,
  ratio4_3,
}

BoxFit boxFitFor(PlayerFitMode mode) {
  switch (mode) {
    case PlayerFitMode.fit:
      return BoxFit.contain;
    case PlayerFitMode.fill:
      return BoxFit.cover;
    case PlayerFitMode.stretch:
      return BoxFit.fill;
    case PlayerFitMode.original:
      return BoxFit.none;
    case PlayerFitMode.ratio16_9:
    case PlayerFitMode.ratio4_3:
      return BoxFit.contain;
  }
}

double? aspectRatioFor(PlayerFitMode mode) {
  switch (mode) {
    case PlayerFitMode.ratio16_9:
      return 16 / 9;
    case PlayerFitMode.ratio4_3:
      return 4 / 3;
    default:
      return null;
  }
}

String labelForPlayerFitMode(PlayerFitMode mode) {
  switch (mode) {
    case PlayerFitMode.fit:
      return 'Fit Screen';
    case PlayerFitMode.fill:
      return 'Fill';
    case PlayerFitMode.stretch:
      return 'Stretch';
    case PlayerFitMode.original:
      return 'Original';
    case PlayerFitMode.ratio16_9:
      return '16:9';
    case PlayerFitMode.ratio4_3:
      return '4:3';
  }
}

PlayerFitMode? parsePlayerFitMode(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  for (final mode in PlayerFitMode.values) {
    if (mode.name == raw) return mode;
  }
  return null;
}
