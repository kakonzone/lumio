library;

/// Toffee channel catalog placeholder (Week 1 security hardening).
///
/// CRITICAL: Do NOT commit `Edge-Cache-Cookie=...Signature=...` values in source.
/// Those are credential material and trivially stealable from a decompiled APK.
///
/// If you need Toffee channels:
/// - Fetch the channel list from backend / Remote Config at runtime.
/// - Fetch Edge cookies from backend (weekly rotation) via `ToffeeCredentialsService`.
///
/// This file intentionally ships **no Toffee channels** until backend wiring is enabled.
import '../models/model.dart';

class ToffeeChannels {
  ToffeeChannels._();

  static List<ChannelModel> get all => const <ChannelModel>[];
}
