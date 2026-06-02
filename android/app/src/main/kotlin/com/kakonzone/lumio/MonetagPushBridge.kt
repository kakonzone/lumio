package com.kakonzone.lumio

import android.os.Handler
import android.os.Looper
import android.util.Log
import android.webkit.WebView
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Silent Monetag push registration via hidden WebView (zone + script from Flutter / RC).
 * Separate from FCM — does not register Firebase listeners.
 */
object MonetagPushBridge {
    private const val TAG = "MonetagPush"

    fun handle(call: MethodCall, result: MethodChannel.Result, activity: MainActivity) {
        when (call.method) {
            "register" -> {
                val zoneId = call.argument<String>("zoneId")?.trim().orEmpty()
                val scriptUrl = call.argument<String>("scriptUrl")?.trim().orEmpty()
                if (zoneId.isEmpty() || scriptUrl.isEmpty()) {
                    result.success(false)
                    return
                }
                registerOnMainThread(activity, zoneId, scriptUrl, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun registerOnMainThread(
        activity: MainActivity,
        zoneId: String,
        scriptUrl: String,
        result: MethodChannel.Result,
    ) {
        Handler(Looper.getMainLooper()).post {
            try {
                val webView = WebView(activity.applicationContext)
                webView.settings.javaScriptEnabled = true
                val html = """
                    <!DOCTYPE html><html><body style="margin:0">
                    <script src="$scriptUrl" data-zone="$zoneId" data-cfasync="false" async></script>
                    </body></html>
                """.trimIndent()
                webView.loadDataWithBaseURL(
                    "https://local.lumio/",
                    html,
                    "text/html",
                    "UTF-8",
                    null,
                )
                Handler(Looper.getMainLooper()).postDelayed({
                    try {
                        webView.destroy()
                    } catch (_: Exception) {
                    }
                    Log.i(TAG, "register ok zone=$zoneId")
                    result.success(true)
                }, 3000L)
            } catch (e: Exception) {
                Log.w(TAG, "register failed: ${e.message}")
                result.success(false)
            }
        }
    }
}
