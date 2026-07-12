import 'dart:async';

import 'package:flutter/material.dart';
import 'package:overtime/pages/home_page.dart';
import 'package:overtime/pages/record_page.dart';
import 'package:overtime/pages/stats_page.dart';
import 'package:overtime/pages/analysis_page.dart';
import 'package:overtime/pages/profile_page.dart';
import 'package:overtime/services/notification_service.dart';
import 'package:overtime/services/storage_service.dart';
import 'package:overtime/services/widget_data_service.dart';
import 'package:overtime/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 通知相关初始化/调度若失败，绝不能阻塞首屏，否则会白屏
  try {
    await NotificationService.init();
    await NotificationService.requestPermission();
    await NotificationService.rescheduleIfEnabled();
    await NotificationService.checkOvertimeWarning();
  } catch (e) {
    debugPrint('Notification setup skipped due to error: $e');
  }
  // 进入首屏前先聚合一次桌面小组件所需数据（含历史导入/WebDAV 恢复）
  unawaited(StorageService.loadRecords()
      .then((_) => StorageService.loadSalaries())
      .then((_) => WidgetDataService.refresh()));
  runApp(const JiaLeMeApp());
}

class JiaLeMeApp extends StatelessWidget {
  const JiaLeMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '加了么',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppTheme.bgLight,
        fontFamily: 'Inter',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.primaryOrange,
          surface: Colors.white,
          onSurface: AppTheme.bgLight,
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(onGoTo: _setIndex),
      const RecordPage(),
      const StatsPage(),
      const AnalysisPage(),
      const ProfilePage(),
    ];
  }

  void _setIndex(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: AppTheme.cardShadow,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.rLarge)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.rLarge)),
          child: BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: AppTheme.primaryOrange,
            unselectedItemColor: AppTheme.textHint,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: '首页'),
              BottomNavigationBarItem(icon: Icon(Icons.access_time_outlined), activeIcon: Icon(Icons.access_time_filled), label: '打卡'),
              BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart_rounded), label: '统计'),
              BottomNavigationBarItem(icon: Icon(Icons.insights_outlined), activeIcon: Icon(Icons.insights_rounded), label: '分析'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person_rounded), label: '我的'),
            ],
          ),
        ),
      ),
    );
  }
}
