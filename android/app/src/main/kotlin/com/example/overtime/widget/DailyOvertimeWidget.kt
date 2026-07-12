package com.example.overtime.widget

/** 桌面小组件：当前月「每日加班时长」柱状图（横轴日期，纵轴时长）。 */
class DailyOvertimeWidget : OvertimeWidgetProvider() {
    override fun kind(): String = "daily"
}
