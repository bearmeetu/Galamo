import 'package:overtime/data/holidays.dart';

/// 一个时间段（进出公司的一对时间）
class TimePeriod {
  TimePeriod({required this.startSeconds, required this.endSeconds});

  final int startSeconds; // 进入时间（秒）
  final int endSeconds; // 离开时间（秒）

  double get durationHours => (endSeconds - startSeconds) / 3600;

  Map<String, dynamic> toJson() => {
        'start': startSeconds,
        'end': endSeconds,
      };

  factory TimePeriod.fromJson(Map<String, dynamic> json) => TimePeriod(
        startSeconds: json['start'] ?? 0,
        endSeconds: json['end'] ?? 0,
      );
}

/// 一条加班打卡记录
class OvertimeRecord {
  OvertimeRecord({
    required this.id,
    required this.date,
    this.onSeconds,
    required this.offSeconds,
    required this.hadMeal,
    required this.leave,
    this.reason,
    this.periods,
  });

  final String id;
  final DateTime date;
  final int? onSeconds; // 上班时间（秒，周末/节假日需要）；工作日可空
  final int offSeconds; // 下班时间（秒）
  final bool hadMeal; // 是否用餐（扣 0.5h）
  final bool leave; // 工作日是否请假（请假则不计加班）
  final String? reason; // 加班原因（可选）
  final List<TimePeriod>? periods; // 多次进出时间段（支持同一天多次进出）

  static const List<String> reasons = ['Jira跟踪', 'Case开发', '会议对齐', 'Fail分析', '知识分享'];

  DayType get dayType => HolidayCalendar.classify(date);

  String get dayTypeLabel {
    switch (dayType) {
      case DayType.holiday:
        return '节假日 3x';
      case DayType.weekend:
        return '周末 2x';
      case DayType.workday:
        return '工作日 1.5x';
    }
  }

  static String fmt(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get offLabel => fmt(offSeconds);
  String get onLabel => onSeconds == null ? '--:--:--' : fmt(onSeconds!);

  /// 获取所有时间段（如果 periods 为空，则返回主 on/off 对）
  List<TimePeriod> get allPeriods {
    if (periods != null && periods!.isNotEmpty) {
      return periods!;
    }
    // 兼容旧数据：使用主 on/off 对
    // 工作日不需要 onSeconds，使用0作为起始时间（compute 函数会从 17:30 开始计算）
    final start = onSeconds ?? 0;
    return [TimePeriod(startSeconds: start, endSeconds: offSeconds)];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'onSeconds': onSeconds,
        'offSeconds': offSeconds,
        'hadMeal': hadMeal,
        'leave': leave,
        'reason': reason,
        'periods': periods?.map((p) => p.toJson()).toList(),
      };

  factory OvertimeRecord.fromJson(Map<String, dynamic> json) {
    final parts = (json['date'] as String).split('-');
    final periodsRaw = json['periods'] as List?;
    return OvertimeRecord(
      id: json['id'],
      date: DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
      onSeconds: json['onSeconds'],
      offSeconds: json['offSeconds'] ?? 0,
      hadMeal: json['hadMeal'] ?? false,
      leave: json['leave'] ?? false,
      reason: json['reason'] as String?,
      periods: periodsRaw?.map((p) => TimePeriod.fromJson(p as Map<String, dynamic>)).toList(),
    );
  }
}

/// 某月基础工资（每月首次打卡填写，支持调薪）
class MonthSalary {
  MonthSalary({required this.year, required this.month, required this.baseSalary});

  final int year;
  final int month;
  final double baseSalary;

  String get key => '$year-${month.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {'year': year, 'month': month, 'baseSalary': baseSalary};

  factory MonthSalary.fromJson(Map<String, dynamic> json) =>
      MonthSalary(year: json['year'], month: json['month'], baseSalary: json['baseSalary']);
}
