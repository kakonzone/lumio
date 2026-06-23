import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'security_config.dart';
import 'security_native.dart';
import '../utils/agent_debug_log.dart';

/// নিরাপত্তা চেকের ফলাফল
enum SecurityCheckId {
  root,
  emulator,
  debugger,
  frida,
  xposed,
  vpn,
  signature,
  installer,
  proxy,
  nativeIntegrity,
  adbDebugging,
}

/// রিলিজে চেক ব্যর্থ হলে কী হবে
enum SecurityFailureMode {
  /// অ্যাপ বন্ধ + জেনেরিক নেটওয়ার্ক এরর
  exitSilently,

  /// স্ট্রিম/API কাজ করবে না (ডিগ্রেডেড মোড)
  blockFeatures,
}

/// LUMIO রানটাইম নিরাপত্তা — স্টার্টআপ ও পিরিয়ডিক চেক।
///
/// **নোট:** Play Protect এড়ানো বা ভুয়া স্ট্রিম URL দেওয়ার মতো
/// "এভেশন" লজিক ইচ্ছাকৃতভাবে অন্তর্ভুক্ত নেই — শুধু প্রকৃত হুমকি মিটিগেশন।
class SecurityManager {
  SecurityManager._();

  static final SecurityManager instance = SecurityManager._();

  bool _lastCheckPassed = true;
  bool _initialized = false;
  Timer? _watchdog;

  bool get isSecure => _lastCheckPassed;

  /// অ্যাপ স্টার্টআপে কল করুন (`main()` থেকে)
  Future<bool> initialize() async {
    if (_initialized) return _lastCheckPassed;
    _initialized = true;

    if (kDebugMode && SecurityConfig.bypassChecksInDebug) {
      _lastCheckPassed = true;
      return true;
    }

    _lastCheckPassed = await performSecurityChecks();
    if (!_lastCheckPassed) {
      if (SecurityConfig.sideloadDevBuild) {
        // ignore: avoid_print
        print(
          '[SecurityManager] LUMIO_SIDELOAD_DEV — checks failed but app continues '
          '(USB debugging / sideload testing)',
        );
        _lastCheckPassed = true;
      } else if (SecurityConfig.strictModeInRelease) {
        await _handleFailure(SecurityFailureMode.exitSilently);
      }
    }
    if (_lastCheckPassed) {
      _startWatchdog();
    }
    return _lastCheckPassed;
  }

  /// পিরিয়ডিক পুনঃযাচাই (৬০ সেকেন্ড)
  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(SecurityConfig.watchdogInterval, (_) async {
      if (kDebugMode && SecurityConfig.bypassChecksInDebug) return;
      final ok = await performSecurityChecks();
      if (!ok &&
          SecurityConfig.strictModeInRelease &&
          !SecurityConfig.sideloadDevBuild) {
        _lastCheckPassed = false;
        await _handleFailure(SecurityFailureMode.exitSilently);
      }
    });
  }

  void dispose() => _watchdog?.cancel();

  /// সব চেক একসাথে — যেকোনো একটি ব্যর্থ = false
  Future<bool> performSecurityChecks() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final results = await Future.wait<bool>([
      _checkRootStatus(),
      _checkEmulator(),
      _checkDebugger(),
      _checkFrida(),
      _checkXposed(),
      if (SecurityConfig.blockVpn) _checkVpn() else Future.value(true),
      _checkAppSignature(),
      if (SecurityConfig.requireKnownInstaller)
        _checkInstallerSource()
      else
        Future.value(true),
      _checkProxyDetection(),
      _checkNativeIntegrity(),
      if (SecurityConfig.strictModeInRelease &&
          !SecurityConfig.relaxAdbDebuggingCheck)
        _checkAdbDebugging()
      else
        Future.value(true),
    ]);

    return results.every((v) => v);
  }

  /// স্ট্রিম/API কলের আগে দ্রুত গেট
  Future<void> assertSecureOrThrow() async {
    if (kDebugMode && SecurityConfig.bypassChecksInDebug) return;
    if (!_lastCheckPassed) {
      throw SecurityBlockedException('Network Error');
    }
    final ok = await performSecurityChecks();
    if (!ok) {
      _lastCheckPassed = false;
      throw SecurityBlockedException('Network Error');
    }
  }

  // ── Root ─────────────────────────────────────────────────────────────

  Future<bool> _checkRootStatus() async {
    const paths = <String>[
      '/system/app/Superuser.apk',
      '/system/xbin/su',
      '/system/bin/su',
      '/sbin/su',
      '/data/local/su',
      '/data/local/bin/su',
      '/data/local/xbin/su',
      '/system/bin/.ext/su',
      '/system/usr/we-need-root/su',
    ];
    for (final p in paths) {
      if (await File(p).exists()) return false;
    }
    // Magisk / busybox
    if (await File('/sbin/.magisk').exists()) return false;
    if (await File('/data/adb/magisk').exists()) return false;
    return true;
  }

  // ── Emulator ───────────────────────────────────────────────────────────

  Future<bool> _checkEmulator() async {
    if (await SecurityNative.isEmulatorNative()) return false;
    // Dart-সাইড ফলব্যাক
    final env = Platform.environment;
    if (env.containsKey('ANDROID_EMULATOR') ||
        env['ANDROID_SERIAL']?.contains('emulator') == true) {
      return false;
    }
    return true;
  }

  // ── Debugger ─────────────────────────────────────────────────────────

  Future<bool> _checkDebugger() async {
    if (kDebugMode) return true;
    try {
      final status = await File('/proc/self/status').readAsString();
      final tracer = RegExp(r'TracerPid:\s+(\d+)').firstMatch(status);
      if (tracer != null) {
        final pid = int.tryParse(tracer.group(1) ?? '0') ?? 0;
        if (pid > 0) return false;
      }
    } catch (_) {}
    return true;
  }

  // ── Frida ────────────────────────────────────────────────────────────

  Future<bool> _checkFrida() async {
    try {
      final maps = await File('/proc/self/maps').readAsString();
      const needles = <String>[
        'frida',
        'gadget',
        'libfrida',
        're.frida.server',
      ];
      final lower = maps.toLowerCase();
      for (final n in needles) {
        if (lower.contains(n)) return false;
      }
    } catch (_) {}

    // ডিফল্ট Frida পোর্ট (লোকাল)
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        27042,
        timeout: const Duration(milliseconds: 120),
      );
      await socket.close();
      return false;
    } catch (_) {}

    return true;
  }

  // ── Xposed / LSPosed ───────────────────────────────────────────────────

  Future<bool> _checkXposed() async {
    const paths = <String>[
      '/system/framework/XposedBridge.jar',
      '/system/lib/libxposed_art.so',
      '/data/data/de.robv.android.xposed.installer',
    ];
    for (final p in paths) {
      if (await File(p).exists()) return false;
    }
    try {
      final maps = await File('/proc/self/maps').readAsString();
      if (maps.toLowerCase().contains('xposed')) return false;
    } catch (_) {}
    return true;
  }

  // ── VPN (ঐচ্ছিক) ──────────────────────────────────────────────────────

  Future<bool> _checkVpn() async {
    if (!Platform.isAndroid) return true;
    final signals = await SecurityNative.collectVpnSecurity();
    if (kDebugMode) {
      debugPrint(
        '[SecurityManager] vpnDetected=${signals.vpnDetected} '
        'interface=${signals.vpnInterface} transport=${signals.vpnTransport} '
        'asnMatched=${signals.asnMatched} reason=${signals.reason}',
      );
    }
    // Pass when no VPN signals (vpnDetected false).
    return !signals.vpnDetected;
  }

  // ── APK Signature ──────────────────────────────────────────────────────

  Future<bool> _checkAppSignature() async {
    final expected = SecurityConfig.expectedApkSignatureSha256.trim();
    if (expected.isEmpty) return true;
    final actual = await SecurityNative.getApkSignatureSha256();
    if (actual == null || actual.isEmpty) return false;
    return actual.replaceAll(':', '').toUpperCase() ==
        expected.replaceAll(':', '').toUpperCase();
  }

  // ── Installer ──────────────────────────────────────────────────────────

  Future<bool> _checkInstallerSource() async {
    final installer = await SecurityNative.getInstallerPackageName();
    if (installer == null || installer.isEmpty) {
      // sideload — অনুমতি নির্ভর করে পলিসির উপর
      return !SecurityConfig.requireKnownInstaller;
    }
    return SecurityConfig.allowedInstallers.contains(installer);
  }

  // ── Proxy / MITM হিউরিস্টিক ───────────────────────────────────────────

  Future<bool> _checkProxyDetection() async {
    final proxy = Platform.environment['http_proxy'] ??
        Platform.environment['HTTP_PROXY'];
    if (proxy != null && proxy.isNotEmpty) return false;
    return true;
  }

  // ── Native integrity (ptrace, checksum) ────────────────────────────────

  Future<bool> _checkNativeIntegrity() async {
    if (!Platform.isAndroid) return true;
    if (!await SecurityNative.isNativeSecurityAvailable()) {
      if (kDebugMode) {
        debugPrint(
          '[SecurityManager] lumio_security native unavailable — skipping nativeIntegrity',
        );
      }
      return true;
    }
    return SecurityNative.nativeIntegrityOk();
  }

  Future<bool> _checkAdbDebugging() async {
    if (kDebugMode) return true;
    final adb = await SecurityNative.isAdbDebuggingEnabled();
    return !adb;
  }

  Future<void> _handleFailure(SecurityFailureMode mode) async {
    switch (mode) {
      case SecurityFailureMode.exitSilently:
        // #region agent log
        AgentDebugLog.log(
          location: 'security_manager.dart:_handleFailure',
          message: 'SecurityManager exit(1) — strict release check failed',
          hypothesisId: 'C',
          data: {
            'sideloadDev': SecurityConfig.sideloadDevBuild,
            'capLocalOnly': SecurityConfig.capLocalOnlyMode,
          },
        );
        // #endregion
        // জেনেরিক বার্তা — রিভার্স ইঞ্জিনিয়ারদের সূত্র দেবেন না
        exit(1);
      case SecurityFailureMode.blockFeatures:
        _lastCheckPassed = false;
    }
  }
}

/// স্ট্রিম/API ব্লক — UI তে "Network Error" দেখান
class SecurityBlockedException implements Exception {
  final String message;
  const SecurityBlockedException(this.message);

  @override
  String toString() => message;
}
