import 'package:overtime/data/holidays.dart';

/// 一条加班打卡记录
class OvertimeRecord {
  OvertimeRecord({
    required this.id,
    required this.date,
    this.onSeconds,
    required this.offSeconds,
    required this.hadMeal,
    required this.leave,
  });

  final String id;
  final DateTime date;
  final int? onSeconds; // 上班时间（秒，周末/节假日需要）；工作日可空
  final int offSeconds; // 下班时间（秒）
  final bool hadMeal; // 是否用餐（扣 0.5h）
  final bool leave; // 工作日是否请假（请假则不计加班）

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'onSeconds': onSeconds,
        'offSeconds': offSeconds,
        'hadMeal': hadMeal,
        'leave': leave,
      };

  factory OvertimeRecord.fromJson(Map<String, dynamic> json) {
    final parts = (json['date'] as String).split('-');
    return OvertimeRecord(
      id: json['id'],
      date: DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
      onSeconds: json['onSeconds'],
      offSeconds: json['offSeconds'] ?? 0,
      hadMeal: json['hadMeal'] ?? false,
      leave: json['leave'] ?? false,
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
