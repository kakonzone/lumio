import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ads/ad_manager.dart';
import '../ads/ad_waterfall.dart';
import '../services/notification_service.dart';

/// Centralized back / exit / minimize monetization stack (Week 3).
class ExitIntentHandler {
  ExitIntentHandler._();

  static final ExitIntentHandler instance = ExitIntentHandler._();

  /// HOME root back press flow.
  ///
  /// Returns `true` when the app should exit.
  Future<bool> handleHomeBack(BuildContext context) async {
    // Step 2: silent Adsterra popunder (already session‑capped).
    unawaited(AdManager.instance.maybeShowPopunder());

    // Step 3: tiny delay to simulate “preparing offer…”.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preparing best offer…'),
        duration: Duration(milliseconds: 800),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 800));

    // Step 4: interstitial via AdWaterfall (LevelPlay → Adsterra → direct).
    await AdWaterfall.instance.showInterstitial(
      context,
      trigger: 'exit_intent_home',
    );

    // Step 5: confirmation dialog.
    final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Exit Lumio?'),
            content: const Text(
              'Matches, live TV and replays will stop when you exit.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Exit'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldExit) {
      // Step 6: System exit.
      await SystemNavigator.pop();
      return true;
    }
    return false;
  }

  /// Player close (back / X) — post‑roll + popunder.
  Future<void> handlePlayerClose(BuildContext context) async {
    // Step 1: Adsterra video overlay (10s, skippable after 5s).
    // Full-screen interstitial via AdWaterfall.
    await AdWaterfall.instance.showInterstitial(
      context,
      trigger: 'exit_intent_player_postroll',
    );

    // Step 2: popunder in background.
    unawaited(AdManager.instance.maybeShowPopunder());

    // Step 3: return to previous screen.
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  /// App minimize (home button) — called from [WidgetsBindingObserver].
  Future<void> handleAppMinimize() async {
    // Step 1: background impression ping.
    unawaited(AdManager.instance.maybeShowPopunder());

    // Step 2: schedule “live match starting” notification 5 minutes later.
    await NotificationService.scheduleReengagementInMinutes(5);
  }
}

