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
        final off = rec.offSeconds.toDouble();
        if (off <= _workdayStartSec) {
          raw = 0.0;
        } else {
          raw = (off - _workdayStartSec) / 3600 - (rec.hadMeal ? _mealDeduction : 0);
        }
      }
    } else {
      // 周末 / 节假日：下班 - 上班 - 用餐
      if (rec.onSeconds == null) {
        raw = 0.0;
      } else {
        final diff = (rec.offSeconds - rec.onSeconds!) / 3600;
        raw = diff - (rec.hadMeal ? _mealDeduction : 0);
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
      final startSec = e.key.dayType == DayType.workday ? _workdayStartSec : (e.key.onSeconds ?? _workdayStartSec);
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
