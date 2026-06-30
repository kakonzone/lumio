import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/ad_config.dart';

/// Full-width dismissible strip when debug builds run without `ADS_ENABLED=true`.
class AdsDebugBanner extends StatefulWidget {
  const AdsDebugBanner({super.key});

  @override
  State<AdsDebugBanner> createState() => _AdsDebugBannerState();
}

class _AdsDebugBannerState extends State<AdsDebugBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode || _dismissed || !AdConfig.shouldShowAdsDisabledBanner) {
      return const SizedBox.shrink();
    }

    return Material(
      color: const Color(0xFFB71C1C),
      elevation: 8,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ADS DISABLED — use scripts/flutter_run_with_ads.sh '
                  'or set ADS_ENABLED=true',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                onPressed: () => setState(() => _dismissed = true),
                tooltip: 'Dismiss for this session',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
