package com.kakonzone.lumio

import android.content.pm.PackageManager
import android.content.res.AssetManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.telephony.TelephonyManager
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.net.NetworkInterface

/**
 * VPN signals for fraud routing — tun/ppp scan, TRANSPORT_VPN, DNS heuristic,
 * known VPN app install check. ASN list is enforced server-side; [asnMatched] is false here.
 */
object VpnDetectionBridge {

    private const val TAG = "VpnDetection"

    private val vpnInterfacePatterns = listOf(
        "tun", "tap", "ppp", "ipsec", "wg", "utun",
    )

    private val knownVpnDns = setOf(
        "10.0.0.243",
        "10.8.0.1",
        "10.64.0.1",
        "172.16.0.1",
        "192.168.1.1",
    )

    private val publicDns = setOf(
        "8.8.8.8",
        "8.8.4.4",
        "1.1.1.1",
        "1.0.0.1",
        "9.9.9.9",
        "208.67.222.222",
        "208.67.220.220",
    )

    private val knownVpnPackages = listOf(
        "com.nordvpn.android",
        "com.expressvpn.vpn",
        "net.openvpn.openvpn",
        "de.blinkt.openvpn",
        "com.surfshark.vpnclient.android",
        "com.privateinternetaccess.android",
        "ch.protonvpn.android",
        "com.hotspotshield.vpn",
        "com.tunnelbear.android",
        "com.cyberghost.android",
        "com.ipvanish",
        "com.windscribe.vpn",
        "com.cloudflare.onedotonedotonedotone",
    )

    fun collect(activity: MainActivity): Map<String, Any> {
        val vpnInterface = detectVpnTunInterface()
        val vpnTransport = detectVpnTransport(activity)
        val dnsSuspicious = detectDnsLeakSuspicious(activity, vpnInterface, vpnTransport)
        val vpnAppInstalled = detectKnownVpnAppInstalled(activity)
        val asnMatched = detectAsnProxySignal(activity, vpnAppInstalled)
        val simCountry = readSimCountryIso(activity)
        val networkCountry = readNetworkCountryIso(activity)
        val vpnDetected = vpnInterface || vpnTransport || asnMatched
        val reason = buildReason(vpnInterface, vpnTransport, asnMatched, vpnAppInstalled)
        Log.i(
            TAG,
            "vpnDetected=$vpnDetected interface=$vpnInterface transport=$vpnTransport " +
                "asnMatched=$asnMatched app=$vpnAppInstalled sim=$simCountry net=$networkCountry " +
                "reason=$reason",
        )
        return mapOf(
            "vpnInterface" to vpnInterface,
            "vpnTransport" to vpnTransport,
            "dnsSuspicious" to dnsSuspicious,
            "vpnAppInstalled" to vpnAppInstalled,
            "asnMatched" to asnMatched,
            "vpnDetected" to vpnDetected,
            "reason" to reason,
            "simCountry" to (simCountry ?: ""),
            "networkCountry" to (networkCountry ?: ""),
        )
    }

    private fun readSimCountryIso(activity: MainActivity): String? {
        return try {
            val tm =
                activity.getSystemService(TelephonyManager::class.java) ?: return null
            tm.simCountryIso?.uppercase()?.takeIf { it.isNotEmpty() }
        } catch (_: Exception) {
            null
        }
    }

    private fun readNetworkCountryIso(activity: MainActivity): String? {
        return try {
            val tm =
                activity.getSystemService(TelephonyManager::class.java) ?: return null
            tm.networkCountryIso?.uppercase()?.takeIf { it.isNotEmpty() }
        } catch (_: Exception) {
            null
        }
    }

    private fun buildReason(
        vpnInterface: Boolean,
        vpnTransport: Boolean,
        asnMatched: Boolean,
        vpnAppInstalled: Boolean,
    ): String {
        val parts = mutableListOf<String>()
        if (vpnInterface) parts.add("vpn_interface")
        if (vpnTransport) parts.add("vpn_transport")
        if (asnMatched) parts.add("asn_catalog_proxy")
        if (vpnAppInstalled) parts.add("vpn_app_installed")
        return if (parts.isEmpty()) "" else parts.joinToString(",")
    }

    /**
     * On-device ASN from IP is unavailable without a network API; when a known VPN app is
     * installed we treat it as a proxy match against [assets/data/vpn_asn_catalog.json].
     */
    private fun detectAsnProxySignal(activity: MainActivity, vpnAppInstalled: Boolean): Boolean {
        if (!vpnAppInstalled) return false
        return loadAsnCatalog(activity.assets).isNotEmpty()
    }

    private fun loadAsnCatalog(assets: AssetManager): Set<Int> {
        return try {
            assets.open("flutter_assets/assets/data/vpn_asn_catalog.json").use { stream ->
                val json = JSONObject(stream.bufferedReader().readText())
                val arr = json.getJSONArray("asns")
                val out = mutableSetOf<Int>()
                for (i in 0 until arr.length()) {
                    out.add(arr.getInt(i))
                }
                out
            }
        } catch (e: Exception) {
            try {
                assets.open("assets/data/vpn_asn_catalog.json").use { stream ->
                    val json = JSONObject(stream.bufferedReader().readText())
                    val arr = json.getJSONArray("asns")
                    val out = mutableSetOf<Int>()
                    for (i in 0 until arr.length()) {
                        out.add(arr.getInt(i))
                    }
                    out
                }
            } catch (_: Exception) {
                Log.w(TAG, "vpn_asn_catalog.json missing or unreadable")
                emptySet()
            }
        }
    }

    fun detectVpnTunInterface(): Boolean {
        return try {
            val interfaces = NetworkInterface.getNetworkInterfaces() ?: return false
            for (ni in interfaces) {
                if (!ni.isUp || ni.isLoopback) continue
                val name = ni.name.lowercase()
                if (vpnInterfacePatterns.any { name.startsWith(it) }) {
                    return true
                }
            }
            false
        } catch (_: Exception) {
            false
        }
    }

    private fun detectVpnTransport(activity: MainActivity): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        return try {
            val cm =
                activity.getSystemService(ConnectivityManager::class.java) ?: return false
            val network = cm.activeNetwork ?: return false
            val caps = cm.getNetworkCapabilities(network) ?: return false
            caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Heuristic: VPN tunnel up but resolver uses only well-known public DNS (possible leak / split).
     */
    private fun detectDnsLeakSuspicious(
        activity: MainActivity,
        vpnInterface: Boolean,
        vpnTransport: Boolean,
    ): Boolean {
        if (!vpnInterface && !vpnTransport) return false
        val servers = activeDnsServers(activity)
        if (servers.isEmpty()) return false
        if (servers.any { it in knownVpnDns }) return false
        return vpnInterface && servers.all { it in publicDns }
    }

    private fun activeDnsServers(activity: MainActivity): List<String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return emptyList()
        return try {
            val cm =
                activity.getSystemService(ConnectivityManager::class.java) ?: return emptyList()
            val network = cm.activeNetwork ?: return emptyList()
            val lp = cm.getLinkProperties(network) ?: return emptyList()
            lp.dnsServers.mapNotNull { addr ->
                addr?.hostAddress?.takeIf { it.isNotEmpty() }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun detectKnownVpnAppInstalled(activity: MainActivity): Boolean {
        val pm = activity.packageManager
        for (pkg in knownVpnPackages) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    pm.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(0))
                } else {
                    @Suppress("DEPRECATION")
                    pm.getPackageInfo(pkg, 0)
                }
                return true
            } catch (_: PackageManager.NameNotFoundException) {
                // continue
            } catch (_: Exception) {
                // continue
            }
        }
        return false
    }
}
