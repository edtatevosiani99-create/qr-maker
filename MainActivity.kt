package com.example.qr_studio

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "qr_studio_notifications"
    private val notificationChannelId = "qr_studio_saved"
    private val notificationPermissionRequest = 1001

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationPermissionRequest)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(notificationChannelId, "QR Studio", NotificationManager.IMPORTANCE_DEFAULT)
            channel.description = "QR Studio saved QR notifications"
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "showSavedNotification") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                    checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                val notificationManager = getSystemService(NotificationManager::class.java)
                val builder = android.app.Notification.Builder(this, notificationChannelId)
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setContentTitle("QR Studio")
                    .setContentText("QR-код сохранён в галерею")
                    .setAutoCancel(true)
                notificationManager.notify(1001, builder.build())
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
