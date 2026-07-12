import 'dart:math';
import 'package:flutter/material.dart';
import 'package:overtime/logic/overtime_calculator.dart';
import 'package:overtime/models/overtime_record.dart';
import 'package:overtime/services/storage_service.dart';
import 'package:overtime/theme/app_theme.dart';
import 'package:overtime/widgets/common_card.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<OvertimeRecord> _records = StorageService.cachedRecords;
  List<MonthSalary> _salaries = StorageService.cachedSalaries;
  int? _tappedDay;

  @override
  void initState() {
    super.initState();
    StorageService.dataVersion.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    StorageService.dataVersion.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final recs = await StorageService.loadRecords();
    final sals = await StorageService.loadSalaries();
    setState(() {
      _records = recs;
      _salaries = sals;
    });
  }

  MonthSalary? _salaryFor(DateTime d) {
    for (final s in _salaries) {
      if (s.year == d.year && s.month == d.month) return s;
    }
    return null;
  }

  List<OvertimeRecord> get _monthRecords =>
      _records.where((r) => r.date.year == _month.year && r.date.month == _month.month).toList();

  @override
  Widget build(BuildContext context) {
    final sal = _salaryFor(_month);
    final plan = sal != null ? OvertimeCalculator.plan(_monthRecords, sal.baseSalary) : null;
    final dayHours = sal != null ? _dayHoursMap(sal.baseSalary) : const <int, double>{};
    final allHours = _allDayHours();

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(backgroundColor: AppTheme.bgLight, elevation: 0, centerTitle: true, title: const Text('加班统计', style: AppTheme.pageHeader)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.padH, vertical: 8),
          children: [
            _monthSwitcher(),
            const SizedBox(height: AppTheme.gapV),
            if (sal == null) _noSalary() else ...[
              _topCards(plan!),
              const SizedBox(height: AppTheme.gapV),
              _progress(plan),
              const SizedBox(height: AppTheme.gapV),
              _breakdown(plan, sal.baseSalary),
              const SizedBox(height: AppTheme.gapV),
              _declarationPlan(plan),
              const SizedBox(height: AppTheme.gapV),
              _contributionCard(allHours),
              const SizedBox(height: AppTheme.gapV),
              _barChartCard(dayHours),
              const SizedBox(height: AppTheme.gapV),
              _donutChartCard(),
              const SizedBox(height: AppTheme.gapV),
              _planList(plan),
            ],
          ],
        ),
      ),
    );
  }

  Widget _monthSwitcher() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)), icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.textSecondary)),
        Text('${_month.year}年${_month.month}月', style: AppTheme.cardTitle),
        IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)), icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary)),
      ],
    );
  }

  Map<int, double> _dayHoursMap(double baseSalary) {
    final map = <int, double>{};
    for (final r in _monthRecords) {
      final h = OvertimeCalculator.compute(r, baseSalary).claimableHours;
      map[r.date.day] = (map[r.date.day] ?? 0) + h;
    }
    return map;
  }

  /// 全部记录按「日期」聚合可申报时长，用于跨多个月的打卡活跃图
  Map<DateTime, double> _allDayHours() {
    final map = <DateTime, double>{};
    for (final r in _records) {
      final sal = _salaryFor(r.date);
      final h = sal == null ? 0 : OvertimeCalculator.compute(r, sal.baseSalary).claimableHours;
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      map[d] = (map[d] ?? 0) + h;
    }
    return map;
  }

  Color _intensity(double h) {
    if (h <= 0) return AppTheme.bgLight;
    if (h < 1) return AppTheme.greenSoft;
    if (h < 2) return AppTheme.secondaryGreen.withValues(alpha: 0.55);
    if (h < 3) return AppTheme.secondaryGreen.withValues(alpha: 0.82);
    return AppTheme.primaryOrange;
  }

  /// GitHub 风格打卡活跃图（多个月、按周分列，颜色深浅表示当天可申报时长）
  /// 方格大小不变，按可用宽度铺满白框，顶部显示月份间隔。
  Widget _contributionCard(Map<DateTime, double> hoursByDate) {
    final now = DateTime.now();
    final media = MediaQuery.of(context);
    // 白框内部可用宽度 = 屏宽 - 页面边距 - 卡片内边距
    final inner = media.size.width - AppTheme.padH * 2 - 28;
    const double cell = 16, m = 2, colGap = 4;
    const double colW = cell + m * 2 + colGap; // 每列（含间隔）占用宽度
    final cols = max(1, (inner / colW).floor());
    final lastMonday = _mondayOf(DateTime(now.year, now.month, now.day));
    final firstMonday = lastMonday.subtract(Duration(days: (cols - 1) * 7));

    final weekCols = <Widget>[];
    final labelSlots = <Widget>[];
    int? lastLabelMonth;
    for (var c = 0; c < cols; c++) {
      final monday = firstMonday.add(Duration(days: c * 7));
      final cells = <Widget>[];
      for (var r = 0; r < 7; r++) {
        final d = monday.add(Duration(days: r));
        final key = DateTime(d.year, d.month, d.day);
        cells.add(_square(_intensity(hoursByDate[key] ?? 0)));
      }
      weekCols.add(Column(children: cells));
      String? label;
      if (c == 0 || monday.month != lastLabelMonth) {
        label = '${monday.month}月';
        lastLabelMonth = monday.month;
      }
      labelSlots.add(
        SizedBox(
          width: colW,
          child: Align(
            alignment: Alignment.centerLeft,
            child: label == null ? null : Text(label, style: AppTheme.tagText),
          ),
        ),
      );
    }
    return CommonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('打卡活跃图', style: AppTheme.cardTitle),
          const SizedBox(height: 6),
          const Text('颜色越深，当天可申报加班越久', style: AppTheme.tagText),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: labelSlots),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: weekCols.map((col) => Padding(padding: EdgeInsets.only(right: colGap), child: col)).toList()),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _square(AppTheme.bgLight),
              _square(AppTheme.greenSoft),
              _square(AppTheme.secondaryGreen.withValues(alpha: 0.55)),
              _square(AppTheme.secondaryGreen.withValues(alpha: 0.82)),
              _square(AppTheme.primaryOrange),
              const SizedBox(width: 6),
              const Text('少 → 多', style: AppTheme.tagText),
            ],
          ),
        ],
      ),
    );
  }

  DateTime _mondayOf(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

  Widget _square(Color c) => Container(
        width: 16,
        height: 16,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
      );

  /// 当月每日加班时长柱状图（横轴日期，纵轴时长）
  /// 柱顶默认不显示数字，点击该柱才显示；标题为「每日加班时长」。
  Widget _barChartCard(Map<int, double> dayHours) {
    final y = _month.year;
    final m = _month.month;
    final days = DateTime(y, m + 1, 0).day;
    final maxH = dayHours.values.fold(0.0, (a, b) => a > b ? a : b);
    final scale = maxH <= 0 ? 1.0 : maxH;
    return CommonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('每日加班时长', style: AppTheme.cardTitle),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: 22,
                  child: _barGridLines(scale, maxH),
                ),
                ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: days,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final day = i + 1;
                    final h = dayHours[day] ?? 0;
                    final showNum = _tappedDay == day && h > 0;
                    return GestureDetector(
                      onTap: () => setState(() => _tappedDay = _tappedDay == day ? null : day),
                      child: SizedBox(
                        width: 18,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                        if (showNum)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${h.toStringAsFixed(2)}h',
                              maxLines: 1,
                              softWrap: false,
                              style: AppTheme.tagText.copyWith(color: AppTheme.textPrimary),
                            ),
                          ),
                        if (showNum) const SizedBox(height: 2),
                            Container(
                              height: (h / scale) * 130,
                              width: 12,
                              decoration: BoxDecoration(color: _intensity(h), borderRadius: BorderRadius.circular(4)),
                            ),
                            const SizedBox(height: 4),
                            Text('$day', style: AppTheme.tagText),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 柱状图背景网格线（按整小时刻度）
  Widget _barGridLines(double scale, double maxH) {
    final levels = max(1, maxH.ceil());
    return CustomPaint(painter: _BarGridPainter(levels: levels, scale: scale, color: AppTheme.divider, barMax: 130));
  }

  /// 当月各「加班原因」的可申报时长聚合（未选择原因归为「未填写」）
  Map<String, double> _reasonHoursMap(double baseSalary) {
    final map = <String, double>{};
    for (final r in _monthRecords) {
      final h = OvertimeCalculator.compute(r, baseSalary).claimableHours;
      final key = r.reason ?? '未填写';
      map[key] = (map[key] ?? 0) + h;
    }
    return map;
  }

  Color _reasonColor(String reason) {
    switch (reason) {
      case 'Jira跟踪':
        return AppTheme.primaryOrange;
      case 'Case开发':
        return AppTheme.accentBlue;
      case '会议对齐':
        return AppTheme.secondaryGreen;
      case 'Fail分析':
        return AppTheme.warmNeutral;
      case '知识分享':
        return AppTheme.blueSoft;
      default:
        return AppTheme.divider;
    }
  }

  /// 月加班组成：圆环饼图 + 图例，展示各加班原因时长占比。
  Widget _donutChartCard() {
    final sal = _salaryFor(_month);
    if (sal == null) return const SizedBox.shrink();
    final map = _reasonHoursMap(sal.baseSalary);
    final total = map.values.fold(0.0, (a, b) => a + b);
    final ordered = [...OvertimeRecord.reasons, '未填写'];
    final segments = ordered
        .where((k) => (map[k] ?? 0) > 0)
        .map((k) => _Segment(k, map[k]!, _reasonColor(k)))
        .toList();
    return CommonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('月加班组成', style: AppTheme.cardTitle),
          const SizedBox(height: 8),
          if (total <= 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('本月暂无加班记录', style: AppTheme.captionText)),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(120, 120),
                        painter: _DonutPainter(segments: segments, strokeWidth: 18),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(total.toStringAsFixed(1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                          const Text('小时', style: AppTheme.tagText),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: segments.map((s) => _legendRow(s, total)).toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _legendRow(_Segment s, double total) {
    final pct = total > 0 ? (s.value / total * 100) : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(s.label, style: AppTheme.captionText)),
          Text('${s.value.toStringAsFixed(1)}h · ${pct.toStringAsFixed(0)}%', style: AppTheme.captionText),
        ],
      ),
    );
  }

  Widget _noSalary() => CommonCard(
        color: AppTheme.warmNeutral,
        child: const Column(
          children: [
            Text('本月尚未填写基础工资', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
            SizedBox(height: 6),
            Text('请到「打卡」页保存一条本月记录时填写，即可计算加班费', style: AppTheme.captionText),
          ],
        ),
      );

  Widget _topCards(OptimalPlan plan) {
    return Row(
      children: [
        Expanded(
          child: CommonCard(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              children: [
                const Text('本月最大加班费', style: AppTheme.tagText),
                const SizedBox(height: 6),
                Text('¥${plan.maxPay.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: AppTheme.primaryOrange)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CommonCard(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              children: [
                const Text('已用申报时长', style: AppTheme.tagText),
                const SizedBox(height: 6),
                Text('${plan.usedHours.toStringAsFixed(1)}/36h', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _progress(OptimalPlan plan) {
    final ratio = (plan.usedHours / 36).clamp(0.0, 1.0);
    final full = plan.totalClaimableHours > 36;
    return CommonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('36h 申报额度', style: AppTheme.bodyText),
              Text(full ? '已封顶' : '剩余 ${(36 - plan.usedHours).toStringAsFixed(1)}h', style: AppTheme.tagText.copyWith(color: AppTheme.primaryOrange)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: AppTheme.smallRadius,
            child: LinearProgressIndicator(value: ratio, minHeight: 10, backgroundColor: AppTheme.bgLight, valueColor: const AlwaysStoppedAnimation(AppTheme.primaryOrange)),
          ),
          if (full) ...[
            const SizedBox(height: 8),
            Text('本月可申报 ${plan.totalClaimableHours.toStringAsFixed(1)}h，超出 ${plan.discardedHours.toStringAsFixed(2)}h 已作废，不可顺延至下月（已优先保留高费率天数）。', style: AppTheme.tagText.copyWith(color: AppTheme.primaryOrangeDeep)),
          ],
        ],
      ),
    );
  }

  /// 具体申报方案：按「节假日 > 周末 > 工作日」优先级，列出应申报的
  /// 每一天的具体时间段（精确到秒），让用户直接照此申报以拿到最多加班费。
  Widget _declarationPlan(OptimalPlan plan) {
    Color colorOf(double rate) => rate >= 3 ? AppTheme.primaryOrange : rate >= 2 ? AppTheme.accentBlue : AppTheme.secondaryGreen;
    return CommonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('最优申报方案', style: AppTheme.cardTitle),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppTheme.warmNeutral, borderRadius: AppTheme.smallRadius), child: const Text('按优先级', style: AppTheme.tagText)),
            ],
          ),
          const SizedBox(height: 4),
          Text('照此申报可拿到最多加班费（共 ${plan.usedHours.toStringAsFixed(2)}h）', style: AppTheme.tagText),
          const SizedBox(height: 12),
          if (plan.items.isEmpty)
            const Text('本月暂无可申报加班', style: AppTheme.captionText)
          else
            ...plan.items.map((i) {
              final r = i.record;
              final range = '${OvertimeRecord.fmt(i.startSec)} – ${OvertimeRecord.fmt(i.endSec)}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(width: 4, height: 38, decoration: BoxDecoration(color: colorOf(i.rate), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r.date.month}月${r.date.day}日 · ${r.dayTypeLabel}', style: AppTheme.bodyText),
                          const SizedBox(height: 2),
                          Text('申报 $range · ${i.hours.toStringAsFixed(2)}h', style: AppTheme.captionText),
                        ],
                      ),
                    ),
                    Text('¥${i.pay.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _breakdown(OptimalPlan plan, double baseSalary) {
    final groups = <double, double>{};
    for (final i in plan.items) {
      groups[i.rate] = (groups[i.rate] ?? 0) + i.hours;
    }
    final rows = [
      (3.0, AppTheme.primaryOrange, '节假日 3x'),
      (2.0, AppTheme.accentBlue, '周末 2x'),
      (1.5, AppTheme.secondaryGreen, '工作日 1.5x'),
    ];
    return CommonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('最优申报构成', style: AppTheme.cardTitle),
          const SizedBox(height: 12),
          ...rows.map((r) {
            final h = groups[r.$1] ?? 0.0;
            final pay = h * r.$1 * OvertimeCalculator.hourlyWage(baseSalary);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: r.$2, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(r.$3, style: AppTheme.bodyText),
                      const Spacer(),
                      Text('${h.toStringAsFixed(1)}h · ¥${pay.toStringAsFixed(0)}', style: AppTheme.captionText),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: AppTheme.smallRadius,
                    child: LinearProgressIndicator(value: (h / 36).clamp(0, 1), minHeight: 6, backgroundColor: AppTheme.bgLight, valueColor: AlwaysStoppedAnimation(r.$2)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _planList(OptimalPlan plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('计入方案（${plan.items.length} 条）', style: AppTheme.cardTitle),
        const SizedBox(height: 12),
        if (plan.items.isEmpty) const Text('本月暂无可申报加班', style: AppTheme.captionText),
        ...plan.items.map(
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CommonCard(
              color: i.rate == 3 ? AppTheme.warmNeutral : i.rate == 2 ? AppTheme.blueSoft : AppTheme.greenSoft,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${i.record.date.month}/${i.record.date.day} · ${i.record.dayTypeLabel}', style: AppTheme.cardTitle.copyWith(fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('申报 ${OvertimeRecord.fmt(i.startSec)}–${OvertimeRecord.fmt(i.endSec)} · ${i.hours.toStringAsFixed(2)}h · ${i.rate}x', style: AppTheme.captionText),
                      ],
                    ),
                  ),
                  Text('¥${i.pay.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 柱状图网格线绘制（横轴按整小时刻度画水平虚线）
class _BarGridPainter extends CustomPainter {
  _BarGridPainter({required this.levels, required this.scale, required this.color, this.barMax = 130});

  final int levels;
  final double scale;
  final Color color;
  final double barMax;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (var v = 1; v <= levels; v++) {
      final y = size.height - (v / scale) * barMax;
      final path = Path();
      var x = 0.0;
      const dash = 4.0;
      const gap = 3.0;
      while (x < size.width) {
        path.moveTo(x, y);
        path.lineTo(min(x + dash, size.width), y);
        x += dash + gap;
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarGridPainter old) => old.levels != levels || old.scale != scale;
}

class _Segment {
  const _Segment(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

/// 圆环饼图绘制（按各段占比绘制描边扇形）
class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.segments, required this.strokeWidth});

  final List<_Segment> segments;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;
    final total = segments.fold(0.0, (a, s) => a + s.value);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    if (total <= 0) {
      paint.color = AppTheme.divider;
      canvas.drawCircle(center, radius, paint);
      return;
    }
    var start = -pi / 2;
    for (final s in segments) {
      final sweep = (s.value / total) * 2 * pi;
      paint.color = s.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.segments != segments;
}
