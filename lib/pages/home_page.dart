import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:overtime/logic/overtime_calculator.dart';
import 'package:overtime/models/overtime_record.dart';
import 'package:overtime/services/storage_service.dart';
import 'package:overtime/theme/app_theme.dart';
import 'package:overtime/widgets/common_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onGoTo});

  final void Function(int) onGoTo;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<OvertimeRecord> _records = StorageService.cachedRecords;
  List<MonthSalary> _salaries = StorageService.cachedSalaries;
  String _username = StorageService.cachedUsername;
  String _quote = '今天也要好好爱护自己';
  final DateTime _now = DateTime.now();
  Timer? _quoteTimer;

  @override
  void initState() {
    super.initState();
    StorageService.dataVersion.addListener(_onDataChanged);
    _load();
    _loadQuote();
    _quoteTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadQuote());
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    StorageService.dataVersion.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final recs = await StorageService.loadRecords();
    final sals = await StorageService.loadSalaries();
    final name = await StorageService.loadUsername();
    if (!mounted) return;
    setState(() {
      _records = recs;
      _salaries = sals;
      _username = name;
    });
  }

  Future<void> _loadQuote() async {
    try {
      final req = await HttpClient().getUrl(Uri.parse('https://v1.hitokoto.cn/')).timeout(const Duration(seconds: 6));
      req.headers.set('User-Agent', 'overtime');
      final resp = await req.close().timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final s = data['hitokoto'];
        if (s != null && mounted) setState(() => _quote = s);
      }
    } catch (_) {
      // 失败时保留默认欢迎语
    }
  }

  double? get _monthMaxPay {
    final sal = _salaries.where((s) => s.year == _now.year && s.month == _now.month).firstOrNull;
    if (sal == null) return null;
    final recs = _records.where((r) => r.date.year == _now.year && r.date.month == _now.month).toList();
    return OvertimeCalculator.plan(recs, sal.baseSalary).maxPay;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.padH, vertical: AppTheme.gapV),
          children: [
            _greeting(),
            const SizedBox(height: AppTheme.gapV),
            _heroCard(context),
            const SizedBox(height: AppTheme.gapV),
            _quickStats(),
            const SizedBox(height: AppTheme.gapV),
            _tipsBanner(),
            const SizedBox(height: AppTheme.gapV),
            _recentTitle(),
            const SizedBox(height: 12),
            _recentList(),
          ],
        ),
      ),
    );
  }

  Widget _greeting() {
    final hour = _now.hour;
    final word = hour < 6
        ? '凌晨好'
        : hour < 12
            ? '早上好'
            : hour < 14
                ? '中午好'
                : hour < 18
                    ? '下午好'
                    : '晚上好';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$word，$_username 👋', style: AppTheme.pageHeader.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(_quote, style: AppTheme.captionText),
      ],
    );
  }

  Widget _heroCard(BuildContext context) {
    final pay = _monthMaxPay;
    return CommonCard(
      padding: EdgeInsets.zero,
      radius: AppTheme.largeRadius,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.rLarge)),
            child: Image.asset('wusaqi.jpg', width: double.infinity, height: 150, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('本月最大可申报加班费', style: AppTheme.captionText),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: pay == null ? '—' : '¥${pay.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                                ),
                                const TextSpan(text: ' 元', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const TagChip(label: '最优方案', color: AppTheme.warmNeutral),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => widget.onGoTo(1),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text('去打卡', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: AppTheme.largeRadius),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickStats() {
    final sal = _salaries.where((s) => s.year == _now.year && s.month == _now.month).firstOrNull;
    final recs = _records.where((r) => r.date.year == _now.year && r.date.month == _now.month).toList();
    final plan = sal == null ? null : OvertimeCalculator.plan(recs, sal.baseSalary);
    final used = plan?.usedHours ?? 0;
    return Row(
      children: [
        Expanded(child: _statCard('已用额度', '${used.toStringAsFixed(1)}h', AppTheme.secondaryGreen)),
        const SizedBox(width: 12),
        Expanded(child: _statCard('记录数', '${recs.length}', AppTheme.accentBlue)),
        const SizedBox(width: 12),
        Expanded(child: _statCard('剩余', '${(36 - used).toStringAsFixed(1)}h', AppTheme.warmNeutral)),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return CommonCard(
      color: color,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(label, style: AppTheme.tagText),
        ],
      ),
    );
  }

  Widget _tipsBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppTheme.secondaryGreen, borderRadius: AppTheme.smallRadius),
      child: const Row(
        children: [
          Icon(Icons.local_florist_outlined, color: AppTheme.textPrimary, size: 22),
          SizedBox(width: 10),
          Expanded(child: Text('每月申报上限 36h，优先报高费率天数更划算 🌿', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary))),
          Icon(Icons.chevron_right_rounded, color: AppTheme.textPrimary),
        ],
      ),
    );
  }

  Widget _recentTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('最近打卡', style: AppTheme.cardTitle),
        GestureDetector(
          onTap: () => widget.onGoTo(1),
          child: Text('查看全部', style: AppTheme.tagText.copyWith(color: AppTheme.primaryOrange)),
        ),
      ],
    );
  }

  Widget _recentList() {
    final items = [..._records]..sort((a, b) => b.date.compareTo(a.date));
    final recent = items.take(3).toList();
    if (recent.isEmpty) {
      return const Text('还没有打卡记录', style: AppTheme.captionText);
    }
    return Column(
      children: recent
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CommonCard(
                padding: EdgeInsets.zero,
                onTap: () => widget.onGoTo(1),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: AppTheme.smallRadius,
                      child: SizedBox(width: 72, height: 72, child: Image.asset('jialeme.png', fit: BoxFit.cover)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e.date.month}/${e.date.day} ${e.dayTypeLabel}', style: AppTheme.cardTitle.copyWith(fontSize: 16)),
                          const SizedBox(height: 4),
                           Text('下班 ${e.offLabel}${e.hadMeal ? ' · 用餐' : ''}${e.leave ? ' · 请假' : ''}${e.reason != null ? ' · ${e.reason}' : ''}', style: AppTheme.captionText),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppTheme.textHint),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
