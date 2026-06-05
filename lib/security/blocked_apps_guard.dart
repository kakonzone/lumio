import 'dart:io';

import 'package:flutter/foundation.dart';

import 'security_config.dart';
import 'security_native.dart';

/// Detects MITM / RE / hooking apps installed on the device (Android only).
class BlockedAppsGuard {
  BlockedAppsGuard._();

  static bool shouldEnforce() {
    if (!Platform.isAndroid) return false;
    if (!SecurityConfig.blockConflictingApps) return false;
    if (kDebugMode && SecurityConfig.bypassChecksInDebug) return false;
    if (SecurityConfig.sideloadDevBuild) return false;
    return true;
  }

  /// Human-readable app labels (no package names exposed to Dart UI).
  static Future<List<String>> installedLabels() async {
    if (!Platform.isAndroid) return const [];
    try {
      final raw = await SecurityNative.findBlockedAppLabels();
      if (raw == null || raw.isEmpty) return const [];
      return raw.whereType<String>().where((s) => s.isNotEmpty).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BlockedAppsGuard] scan failed: $e');
      }
      return const [];
    }
  }

  static Future<bool> hasBlockedApps() async {
    if (!shouldEnforce()) return false;
    final labels = await installedLabels();
    return labels.isNotEmpty;
  }

  static Future<void> openUninstallSettings() async {
    if (!Platform.isAndroid) return;
    await SecurityNative.openFirstBlockedAppUninstall();
  }
}
