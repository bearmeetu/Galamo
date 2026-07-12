package com.example.overtime.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.app.PendingIntent
import android.widget.RemoteViews
import com.example.overtime.MainActivity
import com.example.overtime.R

/**
 * 加班统计桌面小组件基类：从 Flutter 写入的 FlutterSharedPreferences 读取
 * 预聚合好的图表数据（JSON），绘制成 Bitmap 交给 ImageView 显示。
 *
 * 数据由 Flutter 端 StorageService 在数据变化时写入，并通过
 * [ACTION_REFRESH] 广播通知重绘；同时按系统周期（updatePeriodMillis）兜底刷新。
 */
abstract class OvertimeWidgetProvider : AppWidgetProvider() {

    /** "daily" 或 "monthly"，决定读取哪个 SharedPreferences 键与绘制哪种图表。 */
    abstract fun kind(): String

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { updateWidget(context, appWidgetManager, it) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle?,
    ) {
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_REFRESH) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, this.javaClass))
            ids.forEach { updateWidget(context, mgr, it) }
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val maxW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0)
        val minW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        var widthDp = (if (maxW > 0) maxW else if (minW > 0) minW else 400).toFloat()
        if (widthDp <= 0) widthDp = 400f
        val maxH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
        val minH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        var heightDp = (if (maxH > 0) maxH else if (minH > 0) minH else 0).toFloat()
        if (heightDp <= 0) heightDp = widthDp * 0.5f

        val prefs: SharedPreferences =
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val key = when (kind()) {
            "daily" -> "flutter.overtime_widget_daily"
            "monthly" -> "flutter.overtime_widget_monthly"
            else -> "flutter.overtime_widget_reason"
        }
        val json = prefs.getString(key, null)

        val bitmap = when (kind()) {
            "daily" -> WidgetChartPainter.drawDaily(context, widthDp, heightDp, json)
            "monthly" -> WidgetChartPainter.drawMonthly(context, widthDp, heightDp, json)
            else -> WidgetChartPainter.drawReasonDonut(context, widthDp, heightDp, json)
        }

        val views = RemoteViews(context.packageName, R.layout.widget_chart)
        views.setImageViewBitmap(R.id.widget_chart, bitmap)

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val launch = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            },
            flags,
        )
        views.setOnClickPendingIntent(R.id.widget_root, launch)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    companion object {
        const val ACTION_REFRESH = "com.example.overtime.ACTION_WIDGET_REFRESH"
    }
}
