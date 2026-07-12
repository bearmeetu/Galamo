package com.example.overtime.widget

/** 桌面小组件：当年「每月加班时长」柱状图（横轴月份，纵轴时长）。 */
class MonthlyOvertimeWidget : OvertimeWidgetProvider() {
    override fun kind(): String = "monthly"
}
