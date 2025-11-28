package com.example.focusflow

import android.app.NotificationManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.focusflow/notifications"
    private var originalInterruptionFilter: Int = NotificationManager.INTERRUPTION_FILTER_ALL

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "blockNotifications" -> {
                    blockNotifications()
                    result.success(null)
                }
                "enableNotifications" -> {
                    enableNotifications()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun blockNotifications() {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // Save current filter
                originalInterruptionFilter = notificationManager.currentInterruptionFilter
                // Set to priority only (Do Not Disturb mode)
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun enableNotifications() {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // Restore original filter
                notificationManager.setInterruptionFilter(originalInterruptionFilter)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
