package com.knisium.classhub

import android.content.Intent
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.knisium.classhub/sync_service"
    private val STORAGE_CHANNEL = "com.knisium.classhub/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getExternalStorageDirectory" -> {
                    result.success(Environment.getExternalStorageDirectory()?.absolutePath)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val sourceName = call.argument<String>("sourceName") ?: "Source"
                    val total = call.argument<Int>("total") ?: 0
                    val intent = Intent(this, SyncForegroundService::class.java).apply {
                        action = SyncForegroundService.ACTION_START
                        putExtra(SyncForegroundService.EXTRA_SOURCE_NAME, sourceName)
                        putExtra(SyncForegroundService.EXTRA_TOTAL, total)
                    }
                    startForegroundService(intent)
                    result.success(null)
                }
                "update" -> {
                    val percent = call.argument<Int>("percent") ?: 0
                    val currentFile = call.argument<String>("currentFile") ?: ""
                    val completed = call.argument<Int>("completed") ?: 0
                    val total = call.argument<Int>("total") ?: 0
                    val intent = Intent(this, SyncForegroundService::class.java).apply {
                        action = SyncForegroundService.ACTION_UPDATE
                        putExtra(SyncForegroundService.EXTRA_PERCENT, percent)
                        putExtra(SyncForegroundService.EXTRA_CURRENT_FILE, currentFile)
                        putExtra(SyncForegroundService.EXTRA_COMPLETED, completed)
                        putExtra(SyncForegroundService.EXTRA_TOTAL, total)
                    }
                    startService(intent)
                    result.success(null)
                }
                "stop" -> {
                    val intent = Intent(this, SyncForegroundService::class.java).apply {
                        action = SyncForegroundService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
