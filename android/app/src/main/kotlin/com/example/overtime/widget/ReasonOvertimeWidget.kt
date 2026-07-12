package com.example.overtime.widget

/** 桌面小组件：当月「加班原因组成」圆环饼图（各原因可申报时长占比）。 */
class ReasonOvertimeWidget : OvertimeWidgetProvider() {
    override fun kind(): String = "reason"
}
