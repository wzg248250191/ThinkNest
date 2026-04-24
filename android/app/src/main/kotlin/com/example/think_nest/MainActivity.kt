package com.example.think_nest

import android.content.Context
import android.net.ConnectivityManager
import java.net.Inet4Address
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val networkChannelName = "think_nest/network"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, networkChannelName)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "getLocalIpv4Prefixes" -> {
                        result.success(getLocalIpv4Prefixes())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// 获取当前设备可见网络上的 IPv4 与前缀长度列表
    ///
    /// 说明：
    /// - 使用系统 LinkProperties 提供的 linkAddresses，避免依赖 shell/proc 在不同 ROM 上不稳定的问题
    /// - 仅返回 IPv4，供 Dart 侧换算成子网掩码做同网段判断
    private fun getLocalIpv4Prefixes(): List<Map<String, Any>> {
        val connectivityManager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val out = mutableListOf<Map<String, Any>>()
        val dedup = HashSet<String>()

        for (network in connectivityManager.allNetworks) {
            val linkProperties = connectivityManager.getLinkProperties(network) ?: continue
            for (linkAddress in linkProperties.linkAddresses) {
                val addr = linkAddress.address
                if (addr !is Inet4Address) {
                    continue
                }
                if (addr.isLoopbackAddress || addr.isLinkLocalAddress) {
                    continue
                }
                val ip = addr.hostAddress ?: continue
                val prefix = linkAddress.prefixLength
                // 关键逻辑：同一 IP 可能在多个 network 视图里重复出现，按 ip/prefix 去重避免污染判断。
                val key = "$ip/$prefix"
                if (!dedup.add(key)) {
                    continue
                }
                out.add(
                    mapOf(
                        "ip" to ip,
                        "prefixLength" to prefix,
                        "interfaceName" to (linkProperties.interfaceName ?: ""),
                    ),
                )
            }
        }
        return out
    }
}
