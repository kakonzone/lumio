package com.kakonzone.lumio

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.res.Configuration
import android.content.pm.PackageManager
import android.net.Uri
import android.app.ActivityManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.webkit.WebView
import android.view.WindowManager
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.security.MessageDigest

class MainActivity : AudioServiceActivity() {

    private var pendingDeepLink: String? = null

    companion object {
        private const val CHANNEL = "com.lumio.security/native"
        private const val ADS_CHANNEL = "com.kakonzone.lumio/ads"
        private const val DEEPLINK_CHANNEL = "com.kakonzone.lumio/deeplink"
        private const val STORAGE_CHANNEL = "com.kakonzone.lumio/storage"
        private const val MONETAG_PUSH_CHANNEL = "com.kakonzone.lumio/monetag_push"
        private const val ENCRYPTED_INSTALL_PREFS = "lumio_encrypted_install"
        private const val ENCRYPTED_INSTALL_KEY = "lumio_install_id"

        @JvmStatic
        var nativeLibraryLoaded: Boolean = false
            private set

        init {
            try {
                System.loadLibrary("lumio_security")
                nativeLibraryLoaded = true
            } catch (e: UnsatisfiedLinkError) {
                nativeLibraryLoaded = false
                val abis = Build.SUPPORTED_ABIS.joinToString(",")
                Log.e(
                    "LumioNative",
                    "loadLibrary lumio_security failed abis=[$abis] err=${e.message}",
                )
            }
        }

        @JvmStatic
        private external fun nativeIntegrityOk(): Boolean

        @JvmStatic
        private external fun nativeGetSecret(key: String): String
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingDeepLink = intent?.data?.toString()
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingDeepLink = intent.data?.toString()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ADS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "detectVpnInterface" -> result.success(VpnDetectionBridge.detectVpnTunInterface())
                    "collectVpnSignals" -> result.success(VpnDetectionBridge.collect(this))
                    "openUrlInBrowser" -> {
                        val url = call.argument<String>("url") ?: ""
                        try {
                            result.success(openUrlInBrowser(url))
                        } catch (e: Exception) {
                            Log.e("LumioAds", "openUrlInBrowser channel error: ${e.message}")
                            result.success(false)
                        }
                    }
                    "setWindowSecure" -> {
                        val secure = call.argument<Boolean>("secure") ?: true
                        if (secure) {
                            window.setFlags(
                                WindowManager.LayoutParams.FLAG_SECURE,
                                WindowManager.LayoutParams.FLAG_SECURE,
                            )
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAppDataBytes" -> result.success(getDirectorySizeBytes(filesDir))
                    "getCacheBytes" -> result.success(getDirectorySizeBytes(cacheDir))
                    "clearWebViewCache" -> {
                        clearWebViewDiskCache()
                        result.success(null)
                    }
                    "trimCacheDir" -> {
                        val maxBytes = call.argument<Number>("maxBytes")?.toLong()
                            ?: (32L * 1024L * 1024L)
                        trimDirectory(cacheDir, maxBytes)
                        result.success(null)
                    }
                    "trimAppDataDir" -> {
                        val maxBytes = call.argument<Number>("maxBytes")?.toLong()
                            ?: (22L * 1024L * 1024L)
                        trimDirectory(filesDir, maxBytes)
                        result.success(null)
                    }
                    "getDeviceProfile" -> result.success(readDeviceProfile())
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MONETAG_PUSH_CHANNEL)
            .setMethodCallHandler { call, result ->
                MonetagPushBridge.handle(call, result, this)
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEPLINK_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialLink" -> {
                        val link = pendingDeepLink ?: intent?.data?.toString()
                        pendingDeepLink = null
                        result.success(link)
                    }
                    "pollPendingLink" -> {
                        val link = pendingDeepLink
                        pendingDeepLink = null
                        result.success(link)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getApkSignatureSha256" -> result.success(getApkSignatureSha256())
                    "getNativeSecret" -> {
                        val key = call.argument<String>("key") ?: ""
                        result.success(safeNativeSecret(key))
                    }
                    "nativeIntegrityOk" -> result.success(safeNativeIntegrity())
                    "isEmulator" -> result.success(isEmulator())
                    "isAdbDebuggingEnabled" -> result.success(isAdbDebuggingEnabled())
                    "getInstallerPackageName" -> result.success(getInstallerPackageName())
                    "collectVpnSecurity" -> result.success(VpnDetectionBridge.collect(this))
                    "isNativeSecurityAvailable" -> result.success(nativeLibraryLoaded)
                    "readEncryptedInstallId" -> result.success(readEncryptedInstallId())
                    "writeEncryptedInstallId" -> {
                        val id = call.argument<String>("installId") ?: ""
                        writeEncryptedInstallId(id)
                        result.success(null)
                    }
                    "findBlockedAppLabels" -> {
                        val labels = BlockedAppDetector.findInstalled(this)
                            .map { it.label }
                        result.success(labels)
                    }
                    "openFirstBlockedAppUninstall" -> {
                        val pkg = BlockedAppDetector.firstInstalledPackage(this)
                        result.success(openBlockedAppUninstall(pkg))
                    }
                    // Play Integrity temporarily disabled due to missing plugin dependency
                    // "initializePlayIntegrity" -> {
                    //     PlayIntegrityBridge.initialize(this)
                    //     result.success(null)
                    // }
                    // "requestIntegrityToken" -> {
                    //     val cloudProjectNumber = call.argument<Number>("cloudProjectNumber")?.toLong() ?: 0L
                    //     CoroutineScope(Dispatchers.Main).launch {
                    //         try {
                    //             val tokenResult = PlayIntegrityBridge.requestIntegrityToken(cloudProjectNumber)
                    //             tokenResult.fold(
                    //                 onSuccess = { result.success(it) },
                    //                 onFailure = { result.error("INTEGRITY_ERROR", it.message, null) }
                    //             )
                    //         } catch (e: Exception) {
                    //             result.error("INTEGRITY_ERROR", e.message, null)
                    //         }
                    //     }
                    // }
                    "getPackageName" -> result.success(packageName)
                    else -> result.notImplemented()
                }
            }
    }

    private fun safeNativeIntegrity(): Boolean {
        if (!nativeLibraryLoaded) return true
        return try {
            nativeIntegrityOk()
        } catch (_: UnsatisfiedLinkError) {
            Log.w("LumioNative", "nativeIntegrityOk UnsatisfiedLinkError — dart fallback")
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun safeNativeSecret(key: String): String {
        if (!nativeLibraryLoaded) return ""
        return try {
            nativeGetSecret(key)
        } catch (_: UnsatisfiedLinkError) {
            Log.w("LumioNative", "nativeGetSecret UnsatisfiedLinkError key=$key")
            ""
        } catch (_: Exception) {
            ""
        }
    }

    private fun getApkSignatureSha256(): String {
        return try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES,
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
            }
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                packageInfo.signatures
            }
            val cert = signatures?.firstOrNull()?.toByteArray() ?: return ""
            val digest = MessageDigest.getInstance("SHA-256").digest(cert)
            digest.joinToString("") { "%02X".format(it) }
        } catch (_: Exception) {
            ""
        }
    }

    private fun isEmulator(): Boolean {
        val fingerprint = Build.FINGERPRINT.lowercase()
        val model = Build.MODEL.lowercase()
        val brand = Build.BRAND.lowercase()
        val device = Build.DEVICE.lowercase()
        val product = Build.PRODUCT.lowercase()
        val hardware = Build.HARDWARE.lowercase()
        return fingerprint.contains("generic") ||
            fingerprint.contains("unknown") ||
            model.contains("google_sdk") ||
            model.contains("emulator") ||
            model.contains("android sdk built for x86") ||
            brand.startsWith("generic") ||
            device.contains("generic") ||
            product.contains("sdk") ||
            product.contains("sdk_google") ||
            product.contains("vbox") ||
            product.contains("emulator") ||
            hardware.contains("goldfish") ||
            hardware.contains("ranchu")
    }

    private fun isAdbDebuggingEnabled(): Boolean {
        return try {
            Settings.Global.getInt(contentResolver, Settings.Global.ADB_ENABLED, 0) == 1
        } catch (_: Exception) {
            false
        }
    }

    private fun encryptedInstallPrefs() =
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            // Android 5.0–5.1 (API 21–22): EncryptedSharedPreferences needs API 23+.
            null
        } else {
            try {
                val masterKey = MasterKey.Builder(this)
                    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                    .build()
                EncryptedSharedPreferences.create(
                    this,
                    ENCRYPTED_INSTALL_PREFS,
                    masterKey,
                    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
                )
            } catch (_: Exception) {
                null
            }
        }

    private fun readEncryptedInstallId(): String? {
        return try {
            encryptedInstallPrefs()?.getString(ENCRYPTED_INSTALL_KEY, null)
        } catch (_: Exception) {
            null
        }
    }

    private fun writeEncryptedInstallId(installId: String) {
        if (installId.length < 32) return
        try {
            encryptedInstallPrefs()?.edit()?.putString(ENCRYPTED_INSTALL_KEY, installId)?.apply()
        } catch (_: Exception) {
            // Dart falls back to SharedPreferences only.
        }
    }

    /** Adsterra direct link — external browser (MIUI / Redmi safe). */
    private fun openUrlInBrowser(url: String): Boolean {
        if (url.isBlank()) return false
        val uri = try {
            Uri.parse(url)
        } catch (e: Exception) {
            Log.e("LumioAds", "bad url: ${e.message}")
            return false
        }
        val view = Intent(Intent.ACTION_VIEW, uri).apply {
            addCategory(Intent.CATEGORY_BROWSABLE)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        if (launchViewIntent(view, "default")) return true

        val chooser = Intent.createChooser(
            Intent(Intent.ACTION_VIEW, uri).apply {
                addCategory(Intent.CATEGORY_BROWSABLE)
            },
            null,
        ).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        if (launchViewIntent(chooser, "chooser", requireResolve = false)) return true

        val packages = listOf(
            "com.android.chrome",
            "com.mi.globalbrowser",
            "com.android.browser",
            "com.brave.browser",
        )
        for (pkg in packages) {
            val targeted = Intent(Intent.ACTION_VIEW, uri).apply {
                addCategory(Intent.CATEGORY_BROWSABLE)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                setPackage(pkg)
            }
            if (launchViewIntent(targeted, pkg)) return true
        }
        Log.w("LumioAds", "openUrlInBrowser failed for host=${uri.host}")
        return false
    }

    private fun launchViewIntent(
        intent: Intent,
        label: String,
        requireResolve: Boolean = true,
    ): Boolean {
        if (requireResolve && intent.resolveActivity(packageManager) == null) {
            Log.w("LumioAds", "no handler for $label")
            return false
        }
        return try {
            startActivity(intent)
            Log.i("LumioAds", "openUrlInBrowser ok via $label")
            true
        } catch (e: ActivityNotFoundException) {
            try {
                applicationContext.startActivity(intent)
                Log.i("LumioAds", "openUrlInBrowser ok via appContext $label")
                true
            } catch (e2: Exception) {
                Log.w("LumioAds", "launchViewIntent $label err=${e2.message}")
                false
            }
        } catch (e: Exception) {
            Log.w("LumioAds", "launchViewIntent $label err=${e.message}")
            false
        }
    }

    private fun clearWebViewDiskCache() {
        try {
            WebView(applicationContext).apply {
                clearCache(true)
                clearHistory()
                destroy()
            }
        } catch (e: Exception) {
            Log.w("LumioStorage", "clearWebViewDiskCache: ${e.message}")
        }
    }

    /** RAM tier for Flutter — smaller image/player buffers on low-memory devices. */
    private fun readDeviceProfile(): Map<String, Any> {
        val am = getSystemService(ACTIVITY_SERVICE) as ActivityManager
        val info = ActivityManager.MemoryInfo()
        am.getMemoryInfo(info)
        val totalMb = (info.totalMem / (1024L * 1024L)).toInt().coerceAtLeast(1)
        val availMb = (info.availMem / (1024L * 1024L)).toInt().coerceAtLeast(0)
        val lowRam = info.lowMemory || totalMb < 2800
        return mapOf(
            "totalRamMb" to totalMb,
            "availRamMb" to availMb,
            "lowMemoryDevice" to lowRam,
            "sdkInt" to Build.VERSION.SDK_INT,
        )
    }

    private fun getDirectorySizeBytes(dir: java.io.File?): Long {
        if (dir == null || !dir.exists()) return 0L
        var total = 0L
        dir.walkTopDown().forEach { file ->
            if (file.isFile) total += file.length()
        }
        return total
    }

    /** Deletes oldest files in [dir] until total size is under [maxBytes]. */
    private fun trimDirectory(dir: java.io.File?, maxBytes: Long) {
        if (dir == null || !dir.exists() || maxBytes <= 0L) return
        val files = dir.walkTopDown().filter { it.isFile }.toList()
        var total = files.sumOf { it.length() }
        if (total <= maxBytes) return
        val sorted = files.sortedBy { it.lastModified() }
        for (file in sorted) {
            if (total <= maxBytes) break
            val len = file.length()
            if (file.delete()) total -= len
        }
        Log.i("LumioStorage", "trimCacheDir → ${total / 1024}KB (max=${maxBytes / 1024}KB)")
    }

    /** Opens system app details so the user can uninstall a conflicting app. */
    private fun openBlockedAppUninstall(packageName: String?): Boolean {
        if (packageName.isNullOrBlank()) return false
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: Exception) {
            false
        }
    }

    private fun getInstallerPackageName(): String? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                packageManager.getInstallSourceInfo(packageName).installingPackageName
            } else {
                @Suppress("DEPRECATION")
                packageManager.getInstallerPackageName(packageName)
            }
        } catch (_: Exception) {
            null
        }
    }
}
