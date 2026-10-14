package com.fixnow.fixnow_mobile

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val NAVIGATION_CHANNEL = "com.fixnow.mobile/navigation"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Navigation Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openNavigation") {
                val lat = call.argument<Double>("latitude")
                val lng = call.argument<Double>("longitude")
                val label = call.argument<String>("label") ?: "Customer Location"

                if (lat != null && lng != null) {
                    try {
                        val gmmIntentUri = Uri.parse("google.navigation:q=$lat,$lng&mode=d")
                        val mapIntent = Intent(Intent.ACTION_VIEW, gmmIntentUri)
                        mapIntent.setPackage("com.google.android.apps.maps")
                        if (mapIntent.resolveActivity(packageManager) != null) {
                            startActivity(mapIntent)
                            result.success(true)
                        } else {
                            val geoUri = Uri.parse("geo:$lat,$lng?q=$lat,$lng($label)")
                            val fallbackIntent = Intent(Intent.ACTION_VIEW, geoUri)
                            startActivity(fallbackIntent)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("NAVIGATION_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_COORDINATES", "Latitude and Longitude cannot be null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
