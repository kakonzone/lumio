import 'package:flutter/material.dart';

enum PlayerFitMode {
  fit,
  fill,
  stretch,
  original,
  ratio16_9,
  ratio4_3,
}

/// Tap-to-cycle order on the player video-size control (no sheet).
const List<PlayerFitMode> playerFitModeTapCycle = [
  PlayerFitMode.fit,
  PlayerFitMode.fill,
  PlayerFitMode.stretch,
];

PlayerFitMode normalizePlayerFitModeForTap(PlayerFitMode? mode) {
  if (mode != null && playerFitModeTapCycle.contains(mode)) return mode;
  return PlayerFitMode.fit;
}

PlayerFitMode nextPlayerFitModeInTapCycle(PlayerFitMode current) {
  final i = playerFitModeTapCycle.indexOf(current);
  if (i < 0) return PlayerFitMode.fit;
  return playerFitModeTapCycle[(i + 1) % playerFitModeTapCycle.length];
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
