import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:overtime/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 本地通知：每日打卡提醒 + 连续加班预警
class NotificationService {
  NotificationService._();

  static const String _channelId = 'overtime_reminder';
  static const String _channelName = '打卡提醒';
  static const int _reminderId = 1;
  static const int _warnId = 2;

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const MethodChannel _cleanupChannel = MethodChannel('com.example.overtime/cleanup');

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // 失败时回退到 UTC，提醒时间可能偏移
    }
    // 清理插件历史遗留的定时通知存储，避免旧数据触发 GSON 反序列化崩溃
    try {
      await _cleanupChannel.invokeMethod<bool>('clearScheduledNotifications');
    } catch (_) {
      // 清理失败不影响初始化
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
  }

  /// 请求通知权限（Android 13+ 需要）；返回是否授予
  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  /// 按计划每天在指定时间提醒打卡（time 形如 19:00）
  /// 优先用「精确闹钟」保证准点提醒；若系统不支持/无权限则退化为「非精确」，仍能提醒只是可能略延迟。
  static Future<void> scheduleDailyReminder(String time) async {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));

    Future<void> doSchedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
      _reminderId,
      '该打卡啦 🌿',
      '记得记录今天的加班，别让加班费溜走～',
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '每日提醒打卡',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    try {
      await doSchedule(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      // 精确闹钟不可用（系统限制或缺少权限），退化为非精确
      await doSchedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  /// 进入 App 时若曾开启提醒，则重新挂上每日定时（保证开关状态持久且提醒不丢）
  static Future<void> rescheduleIfEnabled() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getBool('remind_on') ?? false) {
        await scheduleDailyReminder(p.getString('remind_time') ?? '19:00');
      }
    } catch (e) {
      debugPrint('rescheduleIfEnabled skipped: $e');
    }
  }

  static Future<void> cancelReminder() async {
    await _plugin.cancel(_reminderId);
  }

  static Future<void> showImmediate(String title, String body) async {
    await _plugin.show(
      _warnId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '每日提醒打卡',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// 连续加班预警：若最近连续打卡天数达到阈值，则当天提示一次
  static Future<void> checkOvertimeWarning() async {
    final p = await SharedPreferences.getInstance();
    final warnOn = p.getBool('warn_on') ?? false;
    if (!warnOn) return;
    final threshold = p.getInt('warn_days') ?? 3;

    final lastWarned = p.getString('warn_last_date');
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    if (lastWarned == todayStr) return; // 当天已提醒过

    final recs = await StorageService.loadRecords();
    if (recs.isEmpty) return;

    // 从今天往前统计连续有打卡记录的天数
    final days = recs.map((r) => DateTime(r.date.year, r.date.month, r.date.day)).toSet();
    var streak = 0;
    var cursor = DateTime(today.year, today.month, today.day);
    // 若今天还没打卡，则从昨天起算
    if (!days.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    if (streak >= threshold) {
      await showImmediate('注意休息哦 💤', '已连续加班 $streak 天，记得按时下班、照顾好自己～');
      await p.setString('warn_last_date', todayStr);
    }
  }
}
