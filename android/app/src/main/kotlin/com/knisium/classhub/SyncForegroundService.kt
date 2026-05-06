package com.knisium.classhub

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class SyncForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "sync_service_channel"
        const val NOTIFICATION_ID = 1
        const val ACTION_START = "start"
        const val ACTION_UPDATE = "update"
        const val ACTION_STOP = "stop"
        const val EXTRA_SOURCE_NAME = "source_name"
        const val EXTRA_PERCENT = "percent"
        const val EXTRA_CURRENT_FILE = "current_file"
        const val EXTRA_COMPLETED = "completed"
        const val EXTRA_TOTAL = "total"
    }

    private var sourceName: String = ""
    private var percent: Int = 0
    private var currentFile: String = ""
    private var completed: Int = 0
    private var total: Int = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                sourceName = intent.getStringExtra(EXTRA_SOURCE_NAME) ?: "Source"
                total = intent.getIntExtra(EXTRA_TOTAL, 0)
                createNotificationChannel()
                val notification = buildNotification()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
            }
            ACTION_UPDATE -> {
                percent = intent.getIntExtra(EXTRA_PERCENT, 0)
                currentFile = intent.getStringExtra(EXTRA_CURRENT_FILE) ?: ""
                completed = intent.getIntExtra(EXTRA_COMPLETED, 0)
                total = intent.getIntExtra(EXTRA_TOTAL, total)
                updateNotification()
            }
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Sync Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows sync progress"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("ClassHub")
            .setContentText("Syncing $sourceName...")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(100, 0, false)
            .build()
    }

    private fun updateNotification() {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val subtitle = if (currentFile.isNotEmpty()) {
            "$currentFile ($completed/$total)"
        } else {
            "$completed/$total files"
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("ClassHub")
            .setContentText("Syncing $sourceName...")
            .setSubText(subtitle)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(100, percent, false)
            .build()

        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, notification)
    }
}
