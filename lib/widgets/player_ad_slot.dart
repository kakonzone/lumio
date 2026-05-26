import 'dart:async';

import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../ads/adsterra/adsterra_banner.dart';
import '../services/user_preferences.dart';
import '../theme/app_theme.dart';
import 'rewarded_button.dart';

/// Below-player ad strip — isolated rebuilds from [PlayerScreen] video tree.
class PlayerAdSlot extends StatefulWidget {
  const PlayerAdSlot({
    super.key,
    required this.onHdUnlocked,
  });

  final VoidCallback onHdUnlocked;

  @override
  State<PlayerAdSlot> createState() => _PlayerAdSlotState();
}

class _PlayerAdSlotState extends State<PlayerAdSlot> {
  @override
  void initState() {
    super.initState();
    unawaited(AdManager.instance.preloadRewarded());
  }

  @override
  Widget build(BuildContext context) {
    if (!AdManager.instance.adsEnabled) {
      return const SizedBox(height: 8);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (UserPreferences.hasActiveHd)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.hd, color: AppColors.accent, size: 18),
                const SizedBox(width: 6),
                Text(
                  'HD active',
                  style: GF.body(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          )
        else
          RewardedButton(
            label: 'Watch in HD',
            trigger: 'hd',
            onSuccess: widget.onHdUnlocked,
          ),
        const SizedBox(height: 10),
        const AdsterraBanner728(placement: 'player_below'),
        const SizedBox(height: 16),
      ],
    );
  }
}
