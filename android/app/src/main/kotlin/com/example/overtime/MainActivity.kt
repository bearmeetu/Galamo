package com.example.overtime

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.overtime.widget.DailyOvertimeWidget
import com.example.overtime.widget.MonthlyOvertimeWidget
import com.example.overtime.widget.OvertimeWidgetProvider
import com.example.overtime.widget.ReasonOvertimeWidget

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.example.overtime/cleanup"
        private const val WIDGET_CHANNEL = "com.example.overtime/widget"
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "clearScheduledNotifications" -> {
                    try {
                        // 清空 flutter_local_notifications 自己维护的定时通知存储，
                        // 仅清这一份偏好，不影响用户其它数据（打卡记录 / 工资等）。
                        val prefs: SharedPreferences =
                            getSharedPreferences("scheduled_notifications", Context.MODE_PRIVATE)
                        prefs.edit().clear().apply()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CLEAR_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "refresh" -> {
                    try {
                        // 数据已写入 FlutterSharedPreferences，通知两个小组件重绘
                        sendBroadcast(
                            Intent(this, DailyOvertimeWidget::class.java).apply {
                                action = OvertimeWidgetProvider.ACTION_REFRESH
                            },
                        )
                        sendBroadcast(
                            Intent(this, MonthlyOvertimeWidget::class.java).apply {
                                action = OvertimeWidgetProvider.ACTION_REFRESH
                            },
                        )
                        sendBroadcast(
                            Intent(this, ReasonOvertimeWidget::class.java).apply {
                                action = OvertimeWidgetProvider.ACTION_REFRESH
                            },
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WIDGET_REFRESH_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
