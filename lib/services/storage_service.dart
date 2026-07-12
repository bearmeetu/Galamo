import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:overtime/models/overtime_record.dart';
import 'package:overtime/services/widget_data_service.dart';

/// 本地持久化：打卡记录 + 每月基础工资 + 用户名
class StorageService {
  StorageService._();

  static const String _recordsKey = 'overtime_records';
  static const String _salaryKey = 'overtime_salaries';
  static const String _userKey = 'overtime_username';
  static const String _avatarKey = 'overtime_avatar';

  // 用户名缓存：首次加载后常驻，避免切换页面反复读取/闪烁
  static String? _cachedUsername;
  static String? _cachedAvatar;
  static List<OvertimeRecord>? _cachedRecords;
  static List<MonthSalary>? _cachedSalaries;

  /// 数据版本号：任何持久化写入后自增，页面监听它即可在“数据真正变化”时刷新，
  /// 而不必在每次切换标签页时重新加载（解决统计页次次刷新问题）。
  static final ValueNotifier<int> dataVersion = ValueNotifier(0);
  static void _bump() {
    dataVersion.value++;
    // 任何数据变化后同步刷新桌面小组件缓存并通知原生重绘
    unawaited(WidgetDataService.refresh());
  }

  static List<OvertimeRecord> get cachedRecords => _cachedRecords ?? const [];
  static List<MonthSalary> get cachedSalaries => _cachedSalaries ?? const [];

  static Future<List<OvertimeRecord>> loadRecords() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_recordsKey) ?? [];
    _cachedRecords = raw.map((e) => OvertimeRecord.fromJson(jsonDecode(e) as Map<String, dynamic>)).toList();
    return _cachedRecords!;
  }

  static Future<void> saveRecords(List<OvertimeRecord> records) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_recordsKey, records.map((r) => jsonEncode(r.toJson())).toList());
    _cachedRecords = List.of(records);
    _bump();
  }

  static Future<List<MonthSalary>> loadSalaries() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_salaryKey) ?? [];
    _cachedSalaries = raw.map((e) => MonthSalary.fromJson(jsonDecode(e) as Map<String, dynamic>)).toList();
    return _cachedSalaries!;
  }

  static Future<void> saveSalaries(List<MonthSalary> salaries) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_salaryKey, salaries.map((s) => jsonEncode(s.toJson())).toList());
    _cachedSalaries = List.of(salaries);
    _bump();
  }

  static Future<String> loadUsername() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_userKey) ?? '打工人小加';
    _cachedUsername = v;
    return v;
  }

  /// 同步读取已缓存的用户名（无则返回默认），避免界面初始渲染闪烁
  static String get cachedUsername => _cachedUsername ?? '打工人小加';

  static Future<void> saveUsername(String name) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_userKey, name);
    _cachedUsername = name;
    _bump();
  }

  static Future<String?> loadAvatar() async {
    final p = await SharedPreferences.getInstance();
    _cachedAvatar = p.getString(_avatarKey);
    return _cachedAvatar;
  }

  static String? get cachedAvatar => _cachedAvatar;

  static Future<void> saveAvatar(String path) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_avatarKey, path);
    _cachedAvatar = path;
    _bump();
  }

  /// 导出全部数据为 Map（用于本地/WebDAV 备份）
  static Future<Map<String, dynamic>> exportAll() async {
    await loadRecords();
    await loadSalaries();
    await loadUsername();
    await loadAvatar();
    return {
      'version': 1,
      'username': cachedUsername,
      'avatar': cachedAvatar,
      'records': cachedRecords.map((r) => r.toJson()).toList(),
      'salaries': cachedSalaries.map((s) => s.toJson()).toList(),
    };
  }

  static Future<void> importAll(Map<String, dynamic> data) async {
    if (data['username'] != null) await saveUsername(data['username'] as String);
    if (data['avatar'] != null) await saveAvatar(data['avatar'] as String);
    if (data['records'] != null) {
      final recs = (data['records'] as List).map((e) => OvertimeRecord.fromJson(Map<String, dynamic>.from(e))).toList();
      await saveRecords(recs);
    }
    if (data['salaries'] != null) {
      final sals = (data['salaries'] as List).map((e) => MonthSalary.fromJson(Map<String, dynamic>.from(e))).toList();
      await saveSalaries(sals);
    }
    _bump();
  }
}
