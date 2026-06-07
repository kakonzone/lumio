import 'package:flutter/material.dart';

import '../services/app_update_service.dart';
import '../theme/app_theme.dart';

/// In-app sideload update dialog — Appwrite Storage download + APK install.
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({
    super.key,
    required this.info,
    required this.currentVersion,
  });

  final AppVersionInfo info;
  final String currentVersion;

  static Future<void> showIfNeeded(BuildContext context) async {
    try {
      final service = AppUpdateService.instance;
      if (!await service.isUpdateAvailable()) return;
      final info = await service.fetchLatestVersion();
      if (info == null || !context.mounted) return;
      final current = await service.currentVersion();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: !info.forceUpdate,
        builder: (_) => UpdateDialog(info: info, currentVersion: current),
      );
    } catch (e) {
      debugPrint('[AppUpdate] dialog check failed: $e');
    }
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });

    final path = await AppUpdateService.instance.downloadApk(
      widget.info.apkFileId,
      onProgress: (p) {
        if (!mounted) return;
        setState(() => _progress = p.clamp(0, 1));
      },
    );

    if (!mounted) return;
    if (path == null) {
      setState(() {
        _downloading = false;
        _error = 'ডাউনলোড ব্যর্থ হয়েছে। আবার চেষ্টা করুন।';
      });
      return;
    }

    final installed = await AppUpdateService.instance.installApk(path);
    if (!mounted) return;
    if (installed) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _downloading = false;
      _error = 'ইনস্টল শুরু করা যায়নি। Settings থেকে unknown apps allow করুন।';
    });
  }

  @override
  Widget build(BuildContext context) {
    final force = widget.info.forceUpdate;
    return PopScope(
      canPop: !force && !_downloading,
      child: AlertDialog(
        backgroundColor: AppColors.bg2Dark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'নতুন আপডেট পাওয়া গেছে 🎉',
          style: GF.head(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.txtDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'বর্তমান: v${widget.currentVersion}\n'
              'নতুন: v${widget.info.version}',
              style: GF.body(color: AppColors.txt2Dark, height: 1.5),
            ),
            if (_downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: AppColors.bg3Dark,
                color: AppColors.accent,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: GF.body(color: AppColors.txt2Dark, fontSize: 13),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: GF.body(color: AppColors.liveRed, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          if (!force && !_downloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'পরে করবো',
                style: GF.body(color: AppColors.txt2Dark),
              ),
            ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(120, 44),
            ),
            onPressed: _downloading ? null : _startDownload,
            child: Text(
              _downloading ? 'ডাউনলোড হচ্ছে…' : 'আপডেট করো',
              style: GF.body(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
