import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/core/player/player_fit_mode.dart';

void main() {
  test('boxFitFor maps fit modes correctly', () {
    expect(boxFitFor(PlayerFitMode.fit), BoxFit.contain);
    expect(boxFitFor(PlayerFitMode.fill), BoxFit.cover);
    expect(boxFitFor(PlayerFitMode.stretch), BoxFit.fill);
    expect(boxFitFor(PlayerFitMode.original), BoxFit.none);
    expect(boxFitFor(PlayerFitMode.ratio16_9), BoxFit.contain);
  });

  test('aspectRatioFor only for forced ratios', () {
    expect(aspectRatioFor(PlayerFitMode.ratio16_9), closeTo(16 / 9, 0.001));
    expect(aspectRatioFor(PlayerFitMode.ratio4_3), closeTo(4 / 3, 0.001));
    expect(aspectRatioFor(PlayerFitMode.fit), isNull);
  });

  test('tap cycle is fit → fill → stretch → 16:9 → fit', () {
    var mode = PlayerFitMode.fit;
    mode = nextPlayerFitModeInTapCycle(mode);
    expect(mode, PlayerFitMode.fill);
    mode = nextPlayerFitModeInTapCycle(mode);
    expect(mode, PlayerFitMode.stretch);
    mode = nextPlayerFitModeInTapCycle(mode);
    expect(mode, PlayerFitMode.ratio16_9);
    mode = nextPlayerFitModeInTapCycle(mode);
    expect(mode, PlayerFitMode.fit);
  });

  test('normalizePlayerFitModeForTap maps legacy modes to fit', () {
    expect(
      normalizePlayerFitModeForTap(PlayerFitMode.original),
      PlayerFitMode.fit,
    );
    expect(
      normalizePlayerFitModeForTap(PlayerFitMode.ratio4_3),
      PlayerFitMode.fit,
    );
    expect(
      normalizePlayerFitModeForTap(PlayerFitMode.fill),
      PlayerFitMode.fill,
    );
    expect(
      normalizePlayerFitModeForTap(PlayerFitMode.ratio16_9),
      PlayerFitMode.ratio16_9,
    );
  });

  test('parsePlayerFitMode round-trips enum names', () {
    for (final mode in PlayerFitMode.values) {
      expect(parsePlayerFitMode(mode.name), mode);
    }
    expect(parsePlayerFitMode('invalid'), isNull);
  });
}
