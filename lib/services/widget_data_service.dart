import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:overtime/logic/overtime_calculator.dart';
import 'package:overtime/models/overtime_record.dart';
import 'package:overtime/services/storage_service.dart';

/// 桌面小组件数据桥接：
/// 把「当前月每日可申报加班时长」「当年每月可申报加班时长」聚合后写入
/// SharedPreferences（与 Flutter 共用同一份 FlutterSharedPreferences），
/// 再通知原生 AppWidgetProvider 重绘。
/// 计算复用 OvertimeCalculator，保证与 App 内统计完全一致。
class WidgetDataService {
  WidgetDataService._();

  static const String _dailyKey = 'overtime_widget_daily';
  static const String _monthlyKey = 'overtime_widget_monthly';
  static const String _reasonKey = 'overtime_widget_reason';

  /// 加班原因 → 配色索引（与原生 WidgetChartPainter.REASON_COLORS 保持一致）
  static const Map<String, int> _reasonIdx = {
    'Jira跟踪': 0,
    'Case开发': 1,
    '会议对齐': 2,
    'Fail分析': 3,
    '知识分享': 4,
    '未填写': 5,
  };

  static const MethodChannel _channel =
      MethodChannel('com.example.overtime/widget');

  /// 重新聚合最新数据并刷新所有桌面小组件。
  /// 失败必须静默，绝不能影响主流程（否则会导致白屏/卡顿）。
  static Future<void> refresh() async {
    final recs = StorageService.cachedRecords;
    final sals = StorageService.cachedSalaries;
    final now = DateTime.now();

    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daily = List<double>.filled(daysInMonth, 0.0);
    final monthly = List<double>.filled(12, 0.0);
    final reasonMap = <String, double>{};

    for (final r in recs) {
      MonthSalary? sal;
      for (final s in sals) {
        if (s.year == r.date.year && s.month == r.date.month) {
          sal = s;
          break;
        }
      }
      if (sal == null) continue;
      final h = OvertimeCalculator.compute(r, sal.baseSalary).claimableHours;
      if (r.date.year == now.year) {
        monthly[r.date.month - 1] += h;
        if (r.date.month == now.month) {
          daily[r.date.day - 1] += h;
          final key = r.reason ?? '未填写';
          reasonMap[key] = (reasonMap[key] ?? 0) + h;
        }
      }
    }

    final dailyR = daily.map((e) => double.parse(e.toStringAsFixed(2))).toList();
    final monthlyR =
        monthly.map((e) => double.parse(e.toStringAsFixed(2))).toList();

    final p = await SharedPreferences.getInstance();
    await p.setString(
      _dailyKey,
      jsonEncode({'year': now.year, 'month': now.month, 'hours': dailyR}),
    );
    await p.setString(
      _monthlyKey,
      jsonEncode({'year': now.year, 'hours': monthlyR}),
    );

    final slices = OvertimeRecord.reasons
        .map((reason) => {
              'label': reason,
              'value': double.parse((reasonMap[reason] ?? 0).toStringAsFixed(2)),
              'idx': _reasonIdx[reason]!,
            })
        .toList();
    if ((reasonMap['未填写'] ?? 0) > 0) {
      slices.add({
        'label': '未填写',
        'value': double.parse(reasonMap['未填写']!.toStringAsFixed(2)),
        'idx': _reasonIdx['未填写']!,
      });
    }
    await p.setString(
      _reasonKey,
      jsonEncode({'year': now.year, 'month': now.month, 'slices': slices}),
    );

    // 通知原生小组件重绘（不等待、不抛错）
    unawaited(_channel
        .invokeMethod<void>('refresh')
        .catchError((_) => null));
  }
}
