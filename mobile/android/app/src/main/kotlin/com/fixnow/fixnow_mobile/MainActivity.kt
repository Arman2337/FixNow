package com.fixnow.fixnow_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val NAVIGATION_CHANNEL = "com.fixnow.mobile/navigation"
    private val NOTIFICATIONS_CHANNEL = "com.fixnow.mobile/notifications"
    private var notificationChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        turnScreenOnAndKeyguard()
        ensureNotificationChannels()
    }

    private fun turnScreenOnAndKeyguard() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
    }

    private fun ensureNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val soundUri = Uri.parse("android.resource://$packageName/raw/incoming_alert")
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .build()

            val incomingChannel = NotificationChannel(
                "incoming_requests_channel",
                "Incoming Job Requests",
                NotificationManager.IMPORTANCE_MAX
            ).apply {
                description = "High priority full-screen alerts and ringtones for incoming service requests"
                setSound(soundUri, audioAttributes)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 1000, 500, 1000, 500, 1000)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    setBypassDnd(true)
                }
            }

            val defaultChannel = NotificationChannel(
                "fixnow_default_channel",
                "FixNow Updates",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Booking status and service updates"
                enableVibration(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }

            manager.createNotificationChannel(incomingChannel)
            manager.createNotificationChannel(defaultChannel)
        }
    }

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

        // Notifications Channel
        notificationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATIONS_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "cancelIncomingNotification" -> {
                        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        manager.cancel(2001)
                        result.success(true)
                    }
                    "getInitialIncomingRequest" -> {
                        val data = extractIntentData(intent)
                        result.success(data)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // If activity was launched from a notification intent, deliver data to Flutter
        val initialData = extractIntentData(intent)
        if (initialData != null) {
            notificationChannel?.invokeMethod("onIncomingRequest", initialData)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        turnScreenOnAndKeyguard()
        val data = extractIntentData(intent)
        if (data != null) {
            notificationChannel?.invokeMethod("onIncomingRequest", data)
        }
    }

    private fun extractIntentData(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        val extras = intent.extras ?: return null
        val type = extras.getString("type")
        if (type == "booking:provider:REQUESTED" || intent.action == "ACTION_INCOMING_REQUEST") {
            val map = HashMap<String, Any?>()
            for (key in extras.keySet()) {
                map[key] = extras.get(key)
            }
            return map
        }
        return null
    }
}
