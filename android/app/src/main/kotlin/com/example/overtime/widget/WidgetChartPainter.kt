package com.example.overtime.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import org.json.JSONArray
import org.json.JSONObject

/**
 * 把柱状图直接绘制成 Bitmap，交给 RemoteViews 的 ImageView 显示。
 * 桌面小组件（RemoteViews）不支持自定义 Canvas 绘制，用 Bitmap 兜底，
 * 从而完整还原《加了么》的轻治愈莫兰迪风格。
 *
 * 配色严格取自 UI 设计规范（.opencode/skills/UI-Design/SKILL.md）：
 *  - 米白底 #F9F2EF
 *  - 暖橙 #F98C53（主强调）
 *  - 浅豆绿 #D2E0AA / 浅绿 #E7EFD2（次强调）
 *  - 正文深色 #3A3A3A、次级文字 #757575、分割线 #EAE3E0
 *  - 全部容器圆角，轻薄阴影/无阴影，最多 3 种彩色（橙+绿）。
 *
 * 字体：与 App 内「一言」同源的 Inter（App 的 fontFamily 即 Inter）。
 * 卡片背景铺满整个小组件，带圆角（统一圆角曲率，符合设计规范）；
 * 配合 ImageView 的 fitXY，卡片边缘与小组件边界重合，长按选择框即对齐。
 */
object WidgetChartPainter {

    private const val COLOR_BG = 0xFFF9F2EF.toInt()
    private const val COLOR_ORANGE = 0xFFF98C53.toInt()
    private const val COLOR_GREEN = 0xFFD2E0AA.toInt()
    private const val COLOR_GREEN_SOFT = 0xFFE7EFD2.toInt()
    private const val COLOR_TEXT = 0xFF3A3A3A.toInt()
    private const val COLOR_SUB = 0xFF757575.toInt()
    private const val COLOR_DIV = 0xFFEAE3E0.toInt()

    private data class Bar(val label: String, val value: Double)

    /** 加班原因组成的一段（圆环饼图的一个扇区）。 */
    private data class ReasonSlice(val label: String, val value: Double, val idx: Int)

    /** 与 Flutter 端 _reasonColor / WidgetDataService._reasonIdx 对应的配色。 */
    private val REASON_COLORS = intArrayOf(
        0xFFF98C53.toInt(), // 0 Jira跟踪 暖橙
        0xFFABD7FB.toInt(), // 1 Case开发 浅天蓝
        0xFFD2E0AA.toInt(), // 2 会议对齐 浅豆绿
        0xFFFCCEB4.toInt(), // 3 Fail分析 暖桃
        0xFFE2F1FD.toInt(), // 4 知识分享 浅蓝
        0xFFEAE3E0.toInt(), // 5 未填写 灰
    )

    private fun reasonColor(idx: Int): Int =
        if (idx in REASON_COLORS.indices) REASON_COLORS[idx] else 0xFFEAE3E0.toInt()

    /** 与 App 内「一言」同源的 Inter 字体。从 assets 加载并缓存，失败时回退系统默认字体。 */
    private var cachedTypeface: Typeface? = null
    private fun typeface(ctx: Context): Typeface {
        if (cachedTypeface == null) {
            cachedTypeface = try {
                Typeface.createFromAsset(ctx.assets, "fonts/Inter-Variable.ttf")
            } catch (_: Exception) {
                Typeface.DEFAULT
            }
        }
        return cachedTypeface!!
    }

    /** 与统计页一致的「时长→颜色」映射：越久越橙。无数据则不画。 */
    private fun intensityColor(h: Double): Int? {
        if (h <= 0) return null
        if (h < 1) return COLOR_GREEN_SOFT
        if (h < 2) return 0x8CD2E0AA.toInt() // 豆绿 55%
        if (h < 3) return 0xD1D2E0AA.toInt() // 豆绿 82%
        return COLOR_ORANGE
    }

    fun drawDaily(ctx: Context, widthDp: Float, heightDp: Float, json: String?): Bitmap {
        val bars = ArrayList<Bar>()
        var year = 0
        var month = 0
        var total = 0.0
        if (json != null) {
            try {
                val o = JSONObject(json)
                year = o.optInt("year")
                month = o.optInt("month")
                val arr = o.optJSONArray("hours")
                if (arr != null) {
                    for (i in 0 until arr.length()) {
                        val v = arr.optDouble(i, 0.0)
                        bars.add(Bar("${i + 1}", v))
                        total += v
                    }
                }
            } catch (_: Exception) {
                // 解析失败则退化为空图表
            }
        }
        val title = "每日加班时长"
        val sub = if (year > 0) "${year}年${month}月 · 共 ${fmt(total)}h" else "每日加班时长"
        return draw(ctx, widthDp, heightDp, title, sub, bars, yStep = 2.0, forceAllLabels = false)
    }

    fun drawMonthly(ctx: Context, widthDp: Float, heightDp: Float, json: String?): Bitmap {
        val bars = ArrayList<Bar>()
        var year = 0
        var total = 0.0
        if (json != null) {
            try {
                val o = JSONObject(json)
                year = o.optInt("year")
                val arr = o.optJSONArray("hours")
                if (arr != null) {
                    for (i in 0 until arr.length()) {
                        val v = arr.optDouble(i, 0.0)
                        bars.add(Bar("${i + 1}", v))
                        total += v
                    }
                }
            } catch (_: Exception) {
                // ignore
            }
        }
        val title = "每月加班时长"
        val sub = if (year > 0) "${year}年 · 共 ${fmt(total)}h" else "每月加班时长"
        // 横轴固定 1..12 月全部显示
        return draw(ctx, widthDp, heightDp, title, sub, bars, yStep = 10.0, forceAllLabels = true)
    }

    fun drawReasonDonut(ctx: Context, widthDp: Float, heightDp: Float, json: String?): Bitmap {
        val slices = ArrayList<ReasonSlice>()
        var year = 0
        var month = 0
        var total = 0.0
        if (json != null) {
            try {
                val o = JSONObject(json)
                year = o.optInt("year")
                month = o.optInt("month")
                val arr = o.optJSONArray("slices")
                if (arr != null) {
                    for (i in 0 until arr.length()) {
                        val s = arr.optJSONObject(i)
                        val label = s.optString("label")
                        val value = s.optDouble("value", 0.0)
                        val idx = s.optInt("idx")
                        slices.add(ReasonSlice(label, value, idx))
                        total += value
                    }
                }
            } catch (_: Exception) {
                // ignore
            }
        }
        val title = "月加班组成"
        val sub = if (year > 0) "${year}年${month}月 · 共 ${fmt(total)}h" else "月加班组成"
        // 仅展示时长不为 0 的原因，避免图例出现 “0h 0%”
        slices.removeAll { it.value <= 0 }
        return drawDonut(ctx, widthDp, heightDp, title, sub, slices, total)
    }

    private fun drawDonut(
        ctx: Context,
        widthDp: Float,
        heightDp: Float,
        title: String,
        sub: String,
        slices: List<ReasonSlice>,
        total: Double,
    ): Bitmap {
        val d = ctx.resources.displayMetrics.density
        val w = maxOf(1, (widthDp * d).toInt())
        val h = maxOf(1, (heightDp * d).toInt())
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)

        val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        bgPaint.color = COLOR_BG
        c.drawRect(0f, 0f, w.toFloat(), h.toFloat(), bgPaint)

        val pad = 14f * d
        val titleSize = 11f * d
        val subSize = 10f * d

        val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG)
        titlePaint.color = COLOR_TEXT
        titlePaint.textSize = titleSize
        titlePaint.typeface = typeface(ctx)

        val subPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        subPaint.color = COLOR_SUB
        subPaint.textSize = subSize
        subPaint.textAlign = Paint.Align.RIGHT
        subPaint.typeface = typeface(ctx)

        c.drawText(title, pad, pad + titleSize, titlePaint)
        c.drawText(sub, w - pad, pad + titleSize, subPaint)

        if (slices.isEmpty() || total <= 0) {
            val msg = "暂无加班记录"
            val mp = Paint(Paint.ANTI_ALIAS_FLAG)
            mp.color = COLOR_SUB
            mp.textSize = 14f * d
            mp.textAlign = Paint.Align.CENTER
            mp.typeface = typeface(ctx)
            c.drawText(msg, w / 2f, h / 2f + 8f * d, mp)
            return bmp
        }

        val top = pad + titleSize + 10f * d
        val bottom = h - pad
        val contentH = maxOf(1f, bottom - top)
        // 圆环区域固定占左侧约 42% 宽，圆心在左侧区域水平靠左、垂直居中；
        // 半径取「内容高度一半」与「左侧区域可容纳半径」的较小值，保证任何盒子比例下都是正圆且不被裁切。
        val leftRegionW = w * 0.42f
        val donutR = minOf(contentH / 2f - 2f * d, (leftRegionW - pad) / 2f)
        val stroke = donutR * 0.30f
        val cx = pad + donutR + 2f * d
        val cy = top + contentH / 2f

        val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        ringPaint.style = Paint.Style.STROKE
        ringPaint.strokeWidth = stroke
        // 背景底环
        ringPaint.color = COLOR_DIV
        c.drawCircle(cx, cy, donutR - stroke / 2f, ringPaint)
        // 各扇区
        var start = -90f
        for (s in slices) {
            val sweep = (s.value / total * 360.0).toFloat()
            ringPaint.color = reasonColor(s.idx)
            val rr = donutR - stroke / 2f
            c.drawArc(RectF(cx - rr, cy - rr, cx + rr, cy + rr), start, sweep, false, ringPaint)
            start += sweep
        }

        // 圆心：总时长
        val centerPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        centerPaint.color = COLOR_TEXT
        centerPaint.textAlign = Paint.Align.CENTER
        centerPaint.typeface = typeface(ctx)
        centerPaint.textSize = donutR * 0.42f
        c.drawText(fmt(total), cx, cy + donutR * 0.12f, centerPaint)
        val unitPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        unitPaint.color = COLOR_SUB
        unitPaint.textAlign = Paint.Align.CENTER
        unitPaint.typeface = typeface(ctx)
        unitPaint.textSize = 9f * d
        c.drawText("小时", cx, cy + donutR * 0.42f, unitPaint)

        // 右侧图例（垂直居中排列）
        val legendX = cx + donutR + 14f * d
        val rowH = contentH / maxOf(1, slices.size)
        val dot = 6f * d
        val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        labelPaint.color = COLOR_TEXT
        labelPaint.typeface = typeface(ctx)
        labelPaint.textSize = 10f * d
        val valPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        valPaint.color = COLOR_SUB
        valPaint.typeface = typeface(ctx)
        valPaint.textSize = 10f * d
        for (i in slices.indices) {
            val s = slices[i]
            val ry = top + i * rowH + rowH / 2f
            val dp = Paint(Paint.ANTI_ALIAS_FLAG)
            dp.color = reasonColor(s.idx)
            dp.style = Paint.Style.FILL
            c.drawCircle(legendX + dot / 2f, ry, dot / 2f, dp)
            val labelX = legendX + dot + 6f * d
            c.drawText(s.label, labelX, ry + labelPaint.textSize * 0.35f, labelPaint)
            val pct = if (total > 0) (s.value / total * 100).toInt() else 0
            val valText = "${fmt(s.value)}h · ${pct}%"
            val valX = labelX + labelPaint.measureText(s.label) + 8f * d
            c.drawText(valText, valX, ry + valPaint.textSize * 0.35f, valPaint)
        }
        return bmp
    }

    private fun draw(
        ctx: Context,
        widthDp: Float,
        heightDp: Float,
        title: String,
        sub: String,
        bars: List<Bar>,
        yStep: Double,
        forceAllLabels: Boolean,
    ): Bitmap {
        val d = ctx.resources.displayMetrics.density
        val w = maxOf(1, (widthDp * d).toInt())
        val h = maxOf(1, (heightDp * d).toInt())
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)

        // 卡片背景铺满整个小组件。
        val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        bgPaint.color = COLOR_BG
        c.drawRect(0f, 0f, w.toFloat(), h.toFloat(), bgPaint)

        val pad = 14f * d
        val titleSize = 10f * d
        val subSize = 10f * d
        val labelSize = 10f * d
        val axisSize = 10f * d

        // 空状态
        if (bars.isEmpty() || bars.all { it.value <= 0 }) {
            val msg = "暂无加班记录"
            val mp = Paint(Paint.ANTI_ALIAS_FLAG)
            mp.color = COLOR_SUB
            mp.textSize = 14f * d
            mp.textAlign = Paint.Align.CENTER
            mp.typeface = typeface(ctx)
            c.drawText(msg, w / 2f, h / 2f + 5f * d, mp)
            return bmp
        }

        val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG)
        titlePaint.color = COLOR_TEXT
        titlePaint.textSize = titleSize
        titlePaint.typeface = typeface(ctx)

        val subPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        subPaint.color = COLOR_SUB
        subPaint.textSize = subSize
        subPaint.typeface = typeface(ctx)

        c.drawText(title, pad, pad + titleSize, titlePaint)
        // 副标题与标题同一行，靠右对齐
        val subRightPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        subRightPaint.color = COLOR_SUB
        subRightPaint.textSize = subSize
        subRightPaint.textAlign = Paint.Align.RIGHT
        subRightPaint.typeface = typeface(ctx)
        c.drawText(sub, w - pad, pad + titleSize, subRightPaint)

        // 纵轴左侧留白（放刻度数值）
        val axisW = 20f * d
        val left = pad + axisW
        val top = pad + titleSize + 12f * d
        val labelH = labelSize + 3f * d
        val bottom = h - pad - labelH
        val chartH = maxOf(1f, bottom - top)
        val areaW = maxOf(1f, w - left - pad)
        val n = bars.size

        // 纵轴上界：取大于最高柱、且为 yStep 整数倍的「整齐」值
        val maxVal = bars.maxOf { it.value }
        val yCount = (Math.floor(maxVal / yStep).toInt() + 1)
        val niceMax = maxOf(1, yCount) * yStep

        val divPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        divPaint.color = COLOR_DIV
        divPaint.strokeWidth = 1f * d
        divPaint.style = Paint.Style.STROKE

        val axisLabelPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        axisLabelPaint.color = COLOR_SUB
        axisLabelPaint.textSize = axisSize
        axisLabelPaint.textAlign = Paint.Align.RIGHT
        axisLabelPaint.typeface = typeface(ctx)

        // 横向网格线 + 纵轴刻度数值
        for (i in 0..yCount) {
            val value = i * yStep
            val y = bottom - (value / niceMax).toFloat() * chartH
            drawDashed(c, left, y, w - pad, y, divPaint, 4f * d, 3f * d)
            c.drawText("${value.toInt()}", left - 4f * d, y + axisSize * 0.35f, axisLabelPaint)
        }
        // 左/下轴
        c.drawLine(left, top, left, bottom, divPaint)
        c.drawLine(left, bottom, w - pad, bottom, divPaint)

        val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        labelPaint.color = COLOR_SUB
        labelPaint.textSize = labelSize
        labelPaint.textAlign = Paint.Align.CENTER
        labelPaint.typeface = typeface(ctx)

        val gap = if (n > 20) 3f * d else 6f * d
        val barW = maxOf(2f, (areaW - (n - 1) * gap) / n)
        val realGap = if (n > 1) (areaW - n * barW) / (n - 1) else 0f

        val barPaint = Paint(Paint.ANTI_ALIAS_FLAG)

        val step = if (forceAllLabels) 1 else when {
            n > 20 -> 5
            n > 10 -> 2
            else -> 1
        }

        for (i in bars.indices) {
            val b = bars[i]
            val x = left + i * (barW + realGap)
            val color = intensityColor(b.value)
            if (color != null) {
                val barH = (b.value / niceMax * chartH).toFloat()
                val bt = bottom - barH
                val r = minOf(4f * d, barW / 2f)
                barPaint.color = color
                c.drawRoundRect(x, bt, x + barW, bottom, r, r, barPaint)
            }
            if (i % step == 0 || i == n - 1) {
                c.drawText(b.label, x + barW / 2f, bottom + labelSize + 2f * d, labelPaint)
            }
        }
        return bmp
    }

    private fun drawDashed(
        c: Canvas,
        x0: Float,
        y0: Float,
        x1: Float,
        y1: Float,
        p: Paint,
        dash: Float,
        gap: Float,
    ) {
        var x = x0
        while (x < x1) {
            val xe = minOf(x + dash, x1)
            c.drawLine(x, y0, xe, y1, p)
            x = xe + gap
        }
    }

    private fun fmt(v: Double): String {
        val i = v.toInt()
        return if (v == i.toDouble()) i.toString() else String.format("%.1f", v)
    }
}
