import 'package:overtime/data/holidays.dart';
import 'package:overtime/models/overtime_record.dart';

const int _workdayStartSec = 17 * 3600 + 30 * 60; // 17:30:00
const double _mealDeduction = 0.5; // 小时
const double _monthlyCapHours = 36.0; // 每月申报上限

/// 单条加班计算结果
class OvertimeResult {
  OvertimeResult({
    required this.dayType,
    required this.rawHours,
    required this.claimableHours,
    required this.rate,
    required this.hourlyWage,
    required this.pay,
  });

  final DayType dayType;
  final double rawHours; // 扣用餐后、未做 <1h 判定
  final double claimableHours; // 满足 >=1h 才可申报
  final double rate; // 1.5 / 2 / 3
  final double hourlyWage;
  final double pay;

  bool get claimable => claimableHours > 0;
}

/// 每月最优申报方案
class OptimalPlan {
  OptimalPlan({
    required this.items,
    required this.usedHours,
    required this.maxPay,
    required this.totalClaimableHours,
  });

  final List<PlanItem> items; // 被选中的记录及计入时长
  final double usedHours;
  final double maxPay;
  final double totalClaimableHours;

  /// 超过 36h 上限、只能作废的部分
  double get discardedHours => totalClaimableHours > _monthlyCapHours
      ? double.parse((totalClaimableHours - _monthlyCapHours).toStringAsFixed(2))
      : 0.0;
}

class PlanItem {
  PlanItem({
    required this.record,
    required this.hours,
    required this.rate,
    required this.pay,
    required this.startSec,
    required this.endSec,
  });

  final OvertimeRecord record;
  final double hours;
  final double rate;
  final double pay;
  final int startSec; // 该天申报的起始秒（精确到秒）
  final int endSec; // 该天申报的结束秒（精确到秒）
}

class OvertimeCalculator {
  OvertimeCalculator._();

  /// 保留两位小数
  static double _r2(double x) => double.parse(x.toStringAsFixed(2));

  /// 时薪 = 基础工资 / 21.75 / 8
  static double hourlyWage(double baseSalary) => baseSalary / 21.75 / 8;

  static double _rateOf(DayType t) {
    switch (t) {
      case DayType.holiday:
        return 3;
      case DayType.weekend:
        return 2;
      case DayType.workday:
        return 1.5;
    }
  }

  /// 计算单条记录的加班时长与金额
  static OvertimeResult compute(OvertimeRecord rec, double baseSalary) {
    final h = hourlyWage(baseSalary);
    final rate = _rateOf(rec.dayType);
    double raw;

    if (rec.dayType == DayType.workday) {
      if (rec.leave) {
        raw = 0.0; // 工作日请假，不计加班
      } else {
        // 工作日：只计算 17:30 之后的时间
        final periods = rec.allPeriods;
        if (periods.isEmpty) {
          raw = 0.0;
        } else {
          // 找出最早进入和最晚离开的时间
          int earliestIn = periods.first.startSeconds;
          int latestOut = periods.first.endSeconds;
          for (final p in periods) {
            if (p.startSeconds < earliestIn) earliestIn = p.startSeconds;
            if (p.endSeconds > latestOut) latestOut = p.endSeconds;
          }

          // 计算中间间隔（离开公司的时长）
          double gapHours = 0;
          if (periods.length > 1) {
            // 按开始时间排序
            final sorted = List<TimePeriod>.from(periods)
              ..sort((a, b) => a.startSeconds.compareTo(b.startSeconds));
            // 计算相邻时段之间的间隔
            for (int i = 0; i < sorted.length - 1; i++) {
              final gap = sorted[i + 1].startSeconds - sorted[i].endSeconds;
              if (gap > 0) gapHours += gap / 3600;
            }
          }

          // 只计算 17:30 之后的时间
          if (latestOut <= _workdayStartSec) {
            raw = 0.0;
          } else {
            // 如果最早进入在 17:30 之前，从 17:30 开始算
            final startSec = earliestIn < _workdayStartSec ? _workdayStartSec : earliestIn;
            // 实际加班时长 = 最晚离开 - max(最早进入, 17:30) - 间隔
            raw = (latestOut - startSec) / 3600 - gapHours - (rec.hadMeal ? _mealDeduction : 0);
          }
        }
      }
    } else {
      // 周末 / 节假日：使用多时段支持
      final periods = rec.allPeriods;
      if (periods.isEmpty) {
        raw = 0.0;
      } else {
        // 计算所有时段的总时长
        double totalHours = 0;
        for (final p in periods) {
          totalHours += p.durationHours;
        }
        raw = totalHours - (rec.hadMeal ? _mealDeduction : 0);
      }
    }
    if (raw < 0) raw = 0.0;
    raw = _r2(raw);

    final claimableHours = raw >= 1 ? raw : 0.0;
    final pay = _r2(claimableHours * rate * h);
    return OvertimeResult(
      dayType: rec.dayType,
      rawHours: raw,
      claimableHours: claimableHours,
      rate: rate,
      hourlyWage: h,
      pay: pay,
    );
  }

  /// 在 36h 上限内，按费率降序贪心取满，得到最大加班费方案
  static OptimalPlan plan(List<OvertimeRecord> records, double baseSalary) {
    final h = hourlyWage(baseSalary);
    final results = records.map((r) => MapEntry(r, compute(r, baseSalary))).toList();
    final claimable = results.where((e) => e.value.claimable).toList();

    // 费率降序，同费率内时长降序（更易填满预算）
    claimable.sort((a, b) {
      final rc = b.value.rate.compareTo(a.value.rate);
      if (rc != 0) return rc;
      return b.value.claimableHours.compareTo(a.value.claimableHours);
    });

    double budget = _monthlyCapHours;
    final items = <PlanItem>[];
    for (final e in claimable) {
      if (budget <= 0) break;
      final take = _r2(e.value.claimableHours < budget ? e.value.claimableHours : budget);
      // 该天可申报加班的「自然起点」：工作日从 17:30 起算，周末/节假日用实际上班打卡
      final periods = e.key.allPeriods;
      final startSec = e.key.dayType == DayType.workday
          ? _workdayStartSec
          : (periods.isNotEmpty ? periods.first.startSeconds : (e.key.onSeconds ?? _workdayStartSec));
      // 申报区间 = 起点 + take 小时（精确到秒），被 36h 上限截断时只取前面一段
      final declaredSec = (take * 3600).round();
      final endSec = startSec + declaredSec;
      items.add(PlanItem(
        record: e.key,
        hours: take,
        rate: e.value.rate,
        pay: _r2(take * e.value.rate * h),
        startSec: startSec,
        endSec: endSec,
      ));
      budget = _r2(budget - take);
    }

    final total = _r2(claimable.fold(0.0, (s, e) => s + e.value.claimableHours));
    final usedHours = _r2(_monthlyCapHours - budget);
    return OptimalPlan(
      items: items,
      usedHours: usedHours,
      maxPay: items.fold(0.0, (s, i) => s + i.pay),
      totalClaimableHours: total,
    );
  }
}
