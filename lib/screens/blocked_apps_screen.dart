import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../security/blocked_apps_guard.dart';
import '../theme/app_theme.dart';

/// Full-screen gate when conflicting analysis/MITM apps are installed.
class BlockedAppsScreen extends StatefulWidget {
  const BlockedAppsScreen({
    super.key,
    required this.appLabels,
    this.onCleared,
  });

  final List<String> appLabels;
  final VoidCallback? onCleared;

  @override
  State<BlockedAppsScreen> createState() => _BlockedAppsScreenState();
}

class _BlockedAppsScreenState extends State<BlockedAppsScreen>
    with WidgetsBindingObserver {
  late List<String> _labels = List<String>.from(widget.appLabels);
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_recheck());
    }
  }

  Future<void> _recheck() async {
    if (_checking) return;
    _checking = true;
    try {
      final labels = await BlockedAppsGuard.installedLabels();
      if (!mounted) return;
      if (labels.isEmpty) {
        widget.onCleared?.call();
        return;
      }
      setState(() => _labels = labels);
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 56,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 20),
                Text(
                  'অসমর্থিত পরিবেশ',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Lumio চালু করতে নিচের অ্যাপ(গুলো) আনইনস্টল করুন। '
                  'এই ধরনের টুল থাকলে স্ট্রিম সুরক্ষিত রাখা যায় না।',
                  style: TextStyle(color: Colors.white70, height: 1.45),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView.separated(
                    itemCount: _labels.length,
                    separatorBuilder: (_, __) => const Divider(
                      color: Colors.white12,
                      height: 1,
                    ),
                    itemBuilder: (_, i) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.accent,
                      ),
                      title: Text(
                        _labels[i],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () =>
                      unawaited(BlockedAppsGuard.openUninstallSettings()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('আনইনস্টল করুন'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => SystemNavigator.pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('বন্ধ করুন'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _checking ? null : () => unawaited(_recheck()),
                  child: Text(
                    _checking ? 'যাচাই হচ্ছে…' : 'আবার যাচাই করুন',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
