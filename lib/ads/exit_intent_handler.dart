import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ads/ad_manager.dart';
// import '../ads/ad_waterfall.dart'; // REMOVED: Waterfall system disabled
import '../ads/adsterra_engine.dart';
import '../services/notification_service.dart';

/// Centralized back / exit / minimize monetization stack (Week 3).
class ExitIntentHandler {
  ExitIntentHandler._();

  static final ExitIntentHandler instance = ExitIntentHandler._();

  /// HOME root back press flow.
  ///
  /// Returns `true` when the app should exit.
  Future<bool> handleHomeBack(BuildContext context) async {
    // 50% probability gate - don't show exit ads every time
    final random = Random();
    if (random.nextDouble() >= 0.5) {
      // Skip exit ads, go straight to exit dialog
      return await _showExitDialog(context);
    }

    // Step 1: interstitial via Adsterra direct (waterfall removed).
    // Removed popunder step (high ban risk).
    await AdsterraEngine.instance.openDirectLink(
      placement: 'exit_intent_home',
      analytics: AdManager.instance.analytics,
    );

    // Step 2: confirmation dialog.
    if (!context.mounted) return false;
    return await _showExitDialog(context);
  }

  Future<bool> _showExitDialog(BuildContext context) async {
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
      // System exit.
      await SystemNavigator.pop();
      return true;
    }
    return false;
  }

  /// Player close (back / X) — post-roll only.
  Future<void> handlePlayerClose(BuildContext context) async {
    // 50% probability gate
    final random = Random();
    if (random.nextDouble() < 0.5) {
      // Full-screen interstitial via Adsterra direct (waterfall removed).
      await AdsterraEngine.instance.openDirectLink(
        placement: 'exit_intent_player_postroll',
        analytics: AdManager.instance.analytics,
      );
    }

    // Removed popunder step (high ban risk).
    // Return to previous screen.
    if (!context.mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  /// App minimize (home button) — called from [WidgetsBindingObserver].
  Future<void> handleAppMinimize() async {
    // Step 1: background impression ping.
    unawaited(AdManager.instance.maybeShowPopunder());

    // Step 2: schedule "live match starting" notification 5 minutes later.
    await NotificationService.scheduleReengagementInMinutes(5);
  }
}
