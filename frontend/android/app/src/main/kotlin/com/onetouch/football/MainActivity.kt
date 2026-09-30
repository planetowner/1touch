package com.onetouch.football

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val deviceRegionChannel = "com.onetouch.football/device_region"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deviceRegionChannel,
        ).setMethodCallHandler { call, result ->
            if (call.method == "getRegionCode") {
                val locale = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    resources.configuration.locales[0]
                } else {
                    @Suppress("DEPRECATION")
                    resources.configuration.locale
                }
                val countryCode = locale.country
                    .ifBlank { Locale.getDefault().country }
                    .uppercase(Locale.US)
                result.success(countryCode.ifBlank { null })
            } else {
                result.notImplemented()
            }
        }
    }
}
