import 'dart:async';

import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../theme/app_theme.dart';

/// "Watch in HD" / VIP — rewarded ad entry (no snackbars).
class RewardedButton extends StatefulWidget {
  final String label;
  final String trigger;
  final VoidCallback? onSuccess;

  const RewardedButton({
    super.key,
    required this.label,
    required this.trigger,
    this.onSuccess,
  });

  @override
  State<RewardedButton> createState() => _RewardedButtonState();
}

class _RewardedButtonState extends State<RewardedButton> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    unawaited(AdManager.instance.preloadRewarded());
  }

  Future<void> _tap() async {
    if (_loading) return;
    setState(() => _loading = true);
    final result = await AdManager.instance.showRewarded(
      trigger: widget.trigger,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (result != RewardResult.failed) {
      widget.onSuccess?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _loading ? null : _tap,
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.hd, size: 18),
      label: Text(widget.label),
      style: TextButton.styleFrom(foregroundColor: AppColors.accent),
    );
  }
}
