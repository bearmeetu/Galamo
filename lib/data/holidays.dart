// 法定节假日数据（固定，按年内置，无需用户修改）
// 数据来源：timor.tech 公开节假日 API（wage: 3=节假日, 2=周末/休息日, 1=工作日/补班）
// 不在表中的日期按 周六日=周末(2x)、工作日=工作日(1.5x) 判定。

enum DayType { holiday, weekend, workday }

class HolidayCalendar {
  HolidayCalendar._();

  static const Map<int, Map<String, int>> _data = {
    2025: {
      '01-01': 3,
      '01-26': 1,
      '01-28': 2,
      '01-29': 3,
      '01-30': 3,
      '01-31': 3,
      '02-01': 2,
      '02-02': 2,
      '02-03': 2,
      '02-04': 2,
      '02-08': 1,
      '04-04': 3,
      '04-05': 2,
      '04-06': 2,
      '04-27': 1,
      '05-01': 3,
      '05-02': 3,
      '05-03': 3,
      '05-04': 2,
      '05-05': 2,
      '05-31': 3,
      '06-01': 2,
      '06-02': 2,
      '09-28': 1,
      '10-01': 3,
      '10-02': 3,
      '10-03': 3,
      '10-04': 2,
      '10-05': 2,
      '10-06': 2,
      '10-07': 2,
      '10-08': 2,
      '10-11': 1,
    },
    2026: {
      '01-01': 3,
      '01-02': 2,
      '01-03': 2,
      '01-04': 1,
      '02-14': 1,
      '02-15': 2,
      '02-16': 3,
      '02-17': 3,
      '02-18': 3,
      '02-19': 3,
      '02-20': 2,
      '02-21': 2,
      '02-22': 2,
      '02-23': 2,
      '02-28': 1,
      '04-04': 2,
      '04-05': 3,
      '04-06': 2,
      '05-01': 3,
      '05-02': 3,
      '05-03': 2,
      '05-04': 2,
      '05-05': 2,
      '05-09': 1,
      '06-19': 3,
      '06-20': 2,
      '06-21': 2,
      '09-20': 1,
      '09-25': 3,
      '09-26': 2,
      '09-27': 2,
      '10-01': 3,
      '10-02': 3,
      '10-03': 3,
      '10-04': 2,
      '10-05': 2,
      '10-06': 2,
      '10-07': 2,
      '10-10': 1,
    },
  };

  static int? _wageFor(DateTime date) {
    final mmdd = '${_two(date.month)}-${_two(date.day)}';
    return _data[date.year]?[mmdd];
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static DayType classify(DateTime date) {
    final w = _wageFor(date);
    if (w != null) {
      if (w == 3) return DayType.holiday;
      if (w == 2) return DayType.weekend;
      return DayType.workday;
    }
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return DayType.weekend;
    }
    return DayType.workday;
  }
}

