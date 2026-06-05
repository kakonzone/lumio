import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_config_model.dart';
import '../screens/splash_screen.dart';
import '../theme/app_theme.dart';

/// Full-screen block when [AppConfigModel.killSwitch] is active.
class KillSwitchScreen extends StatelessWidget {
  const KillSwitchScreen({
    super.key,
    required this.config,
  });

  final AppConfigModel config;

  @override
  Widget build(BuildContext context) {
    final message = (config.killMessage?.trim().isNotEmpty ?? false)
        ? config.killMessage!.trim()
        : 'This application has been disabled by the administrator.';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0C0C0E),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  SplashScreen.logoAsset,
                  width: 160,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.block,
                    size: 72,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'This app is currently unavailable.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
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

/// Full-screen maintenance block.
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({
    super.key,
    required this.config,
  });

  final AppConfigModel config;

  @override
  Widget build(BuildContext context) {
    final message = (config.maintenanceMessage?.trim().isNotEmpty ?? false)
        ? config.maintenanceMessage!.trim()
        : 'We are performing scheduled maintenance.';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0C0C0E),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.build_circle_outlined,
                  size: 88,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 28),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Please wait, we'll be back soon.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
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

/// Non-dismissible force-update dialog — opens APK download URL.
class ForceUpdateDialog extends StatelessWidget {
  const ForceUpdateDialog({
    super.key,
    required this.config,
  });

  final AppConfigModel config;

  static Future<void> show(BuildContext context, AppConfigModel config) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ForceUpdateDialog(config: config),
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = (config.updateMessage?.trim().isNotEmpty ?? false)
        ? config.updateMessage!.trim()
        : 'A new version ${config.latestVersion} is available!';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) SystemNavigator.pop();
      },
      child: AlertDialog(
        title: const Text(
          'Update Required',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            const Text(
              'Tap Update Now to download the latest APK and install it manually.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _openUpdateUrl(config.updateUrl),
              child: const Text('Update Now'),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _openUpdateUrl(String? url) async {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final uri = Uri.parse(trimmed);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Dismissible announcement strip for the home screen (session only).
class AnnouncementBanner extends StatefulWidget {
  const AnnouncementBanner({
    super.key,
    required this.text,
  });

  final String text;

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    if (!_visible || widget.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      color: AppColors.accent.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.campaign_outlined, color: AppColors.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.text.trim(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _visible = false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Auto-scrolling horizontal ticker.
class TickerWidget extends StatefulWidget {
  const TickerWidget({
    super.key,
    required this.text,
  });

  final String text;

  @override
  State<TickerWidget> createState() => _TickerWidgetState();
}

class _TickerWidgetState extends State<TickerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.trim().isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 32,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
        ),
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FractionalTranslation(
                translation: Offset(-_controller.value * 1.0, 0),
                child: child,
              );
            },
            child: Row(
              children: [
                _tickerLabel(widget.text.trim()),
                _tickerLabel(widget.text.trim()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tickerLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Compare semver-style version strings.
bool isAppVersionOlder(String current, String latest) {
  List<int> parts(String v) => v
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();

  final c = parts(current);
  final l = parts(latest);
  for (var i = 0; i < 3; i++) {
    final cv = i < c.length ? c[i] : 0;
    final lv = i < l.length ? l[i] : 0;
    if (lv > cv) return true;
    if (lv < cv) return false;
  }
  return false;
}
