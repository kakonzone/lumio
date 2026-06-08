import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ads/ad_manager.dart';
import '../ads/rewarded_features.dart';
import '../services/user_preferences.dart';

/// Daily rewarded prompt shown once per day at app open.
class DailyRewardedPrompt extends StatefulWidget {
  const DailyRewardedPrompt({super.key});

  @override
  State<DailyRewardedPrompt> createState() => _DailyRewardedPromptState();
}

class _DailyRewardedPromptState extends State<DailyRewardedPrompt> {
  static const String _lastPromptKey = 'last_daily_rewarded_prompt_day';
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _checkAndShow();
  }

  Future<void> _checkAndShow() async {
    // Skip if user is VIP
    if (UserPreferences.removeAdsPurchased) {
      return;
    }

    final adFreeUntil = UserPreferences.adFreeUntil;
    if (adFreeUntil != null && DateTime.now().isBefore(adFreeUntil)) {
      return;
    }

    // Check if already shown today
    final prefs = await SharedPreferences.getInstance();
    final lastPromptDay = prefs.getString(_lastPromptKey);
    final today = _todayKey();

    if (lastPromptDay == today) {
      return;
    }

    // Show the prompt
    if (mounted) {
      setState(() {
        _visible = true;
      });
    }
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  Future<void> _onWatchAd() async {
    final earned = await AdManager.instance.showRewardedFeature(
      feature: RewardedFeatures.coinBonus,
    );

    if (earned) {
      // Grant 20 coins (implementation depends on CoinEconomy)
      // TODO: Implement CoinEconomy.grantCoins(20)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('২০ কয়েন পেয়েছেন!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _dismiss();
    }
  }

  void _dismiss() async {
    // Mark today as shown
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPromptKey, _todayKey());

    if (mounted) {
      setState(() {
        _visible = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'আজকের ফ্রি কয়েন নিন',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'শুধু একটি বিজ্ঞাপন দেখুন',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _onWatchAd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('বিজ্ঞাপন দেখুন'),
                  ),
                  TextButton(
                    onPressed: _dismiss,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('এখন না'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
