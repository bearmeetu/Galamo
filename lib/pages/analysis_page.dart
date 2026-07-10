import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:overtime/data/holidays.dart';
import 'package:overtime/logic/overtime_calculator.dart';
import 'package:overtime/models/overtime_record.dart';
import 'package:overtime/services/ai_service.dart';
import 'package:overtime/services/storage_service.dart';
import 'package:overtime/theme/app_theme.dart';
import 'package:overtime/widgets/common_card.dart';

/// 加班分析页：AI 生成月度报告 + 加班称号展示。
class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  List<OvertimeRecord> _records = StorageService.cachedRecords;
  List<MonthSalary> _salaries = StorageService.cachedSalaries;
  List<EarnedTitle> _titles = [];
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = false;
  int _pageIndex = 0;
  final PageController _pageController = PageController();
  final GlobalKey _reportKey = GlobalKey();

  /// 去掉「周末献祭版」后缀，只保留前面的称号
  static String _stripSuffix(String title) => title.replaceAll('【周末献祭版】', '').trim();

  static const List<Color> _titleColors = [
    AppTheme.warmNeutral,
    AppTheme.greenSoft,
    AppTheme.blueSoft,
    AppTheme.secondaryGreen,
    AppTheme.accentBlue,
    AppTheme.skySoft,
  ];

  @override
  void initState() {
    super.initState();
    StorageService.dataVersion.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    StorageService.dataVersion.removeListener(_onDataChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final recs = await StorageService.loadRecords();
    final sals = await StorageService.loadSalaries();
    final titles = await AiService.loadTitles();
    if (!mounted) return;
    setState(() {
      _records = recs;
      _salaries = sals;
      _titles = titles;
    });
  }

  MonthSalary? _salaryFor(DateTime d) {
    for (final s in _salaries) {
      if (s.year == d.year && s.month == d.month) return s;
    }
    return null;
  }

  List<OvertimeRecord> get _monthRecords =>
      _records.where((r) => r.date.year == _month.year && r.date.month == _month.month).toList();

  _MonthSummary get _summary {
    final sal = _salaryFor(_month);
    final recs = _monthRecords;
    final days = recs.map((r) => DateTime(r.date.year, r.date.month, r.date.day)).toSet();
    double totalHours = 0;
    if (sal != null) {
      for (final r in recs) {
        totalHours += OvertimeCalculator.compute(r, sal.baseSalary).claimableHours;
      }
    }
    final avg = days.isEmpty ? 0.0 : totalHours / days.length;
    return _MonthSummary(days: days.length, totalHours: totalHours, avgHours: avg, streak: _longestStreak());
  }

  int _longestStreak() {
    if (_records.isEmpty) return 0;
    final days = _records.map((r) => DateTime(r.date.year, r.date.month, r.date.day)).toSet().toList()
      ..sort((a, b) => a.compareTo(b));
    var best = 1;
    var cur = 1;
    for (var i = 1; i < days.length; i++) {
      if (days[i].difference(days[i - 1]).inDays == 1) {
        cur++;
        best = cur > best ? cur : best;
      } else if (days[i].difference(days[i - 1]).inDays > 1) {
        cur = 1;
      }
    }
    return best;
  }

  String _buildDataSummary() {
    final sal = _salaryFor(_month);
    final recs = _monthRecords;
    final buf = StringBuffer();
    buf.writeln('统计月份：${_month.year}年${_month.month}月');
    if (sal != null) buf.writeln('基础工资：¥${sal.baseSalary.toStringAsFixed(0)}');
    buf.writeln('打卡天数：${recs.length} 天');
    double total = 0;
    double rest = 0;
    int latestSec = -1;
    String latestOff = '--';
    for (final r in recs) {
      final h = sal != null ? OvertimeCalculator.compute(r, sal.baseSalary).claimableHours : 0.0;
      total += h;
      if (r.dayType != DayType.workday) rest += h;
      if (r.offSeconds > latestSec) {
        latestSec = r.offSeconds;
        latestOff = OvertimeRecord.fmt(r.offSeconds);
      }
    }
    final restPct = total > 0 ? (rest / total * 100).toStringAsFixed(0) : '0';
    buf.writeln('可申报加班总时长：${total.toStringAsFixed(2)} 小时');
    buf.writeln('休息日（周末/节假日）加班时长：${rest.toStringAsFixed(2)} 小时（占比 $restPct%）');
    buf.writeln('最晚下班时间：$latestOff');
    buf.writeln('每日明细：');
    for (final r in recs) {
      final range = r.onSeconds == null ? '下班 ${r.offLabel}' : '${r.onLabel}–${r.offLabel}';
      buf.writeln('${r.date.month}/${r.date.day} ${r.dayTypeLabel} $range${r.hadMeal ? ' 用餐' : ''}${r.leave ? ' 请假' : ''}');
    }
    return buf.toString();
  }

  Future<void> _generate() async {
    if (_loading) return;
    final cfg = await AiService.loadConfig();
    if (!cfg.isValid) {
      if (mounted) _openConfigDialog();
      return;
    }
    setState(() => _loading = true);
    try {
      final summary = _buildDataSummary();
      final report = await AiService.analyze(
        cfg: cfg,
        username: StorageService.cachedUsername,
        dataSummary: summary,
      );
      final title = AiService.parseTitle(report);
      if (title.isNotEmpty) {
        final titles = await AiService.saveTitleForMonth(_month.year, _month.month, title);
        if (mounted) setState(() => _titles = titles);
      }
      if (mounted) _showReport(report, title);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('生成失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showReport(String report, String title) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.largeRadius),
        child: RepaintBoundary(
          key: _reportKey,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.92,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: AppTheme.largeRadius),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TagChip(label: '本月称号：${_stripSuffix(title)}', color: AppTheme.warmNeutral),
                  ),
                Text(report, style: AppTheme.bodyText),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saveReportImage,
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text('保存图片', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryOrange,
                          side: const BorderSide(color: AppTheme.primaryOrange),
                          shape: RoundedRectangleBorder(borderRadius: AppTheme.smallRadius),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(c),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOrange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: AppTheme.largeRadius),
                        ),
                        child: const Text('知道了', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveReportImage() async {
    try {
      final boundary = _reportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final png = bytes.buffer.asUint8List();
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '保存分析报告',
        fileName: '加班分析报告_${_month.year}${_month.month.toString().padLeft(2, '0')}.png',
        bytes: png,
        type: FileType.custom,
        allowedExtensions: ['png'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(path != null ? '已保存为图片' : '已取消保存')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  Future<void> _openConfigDialog() async {
    final c = await AiService.loadConfig();
    if (!mounted) return;
    final modelCtl = TextEditingController(text: c.model);
    final urlCtl = TextEditingController(text: c.apiUrl);
    final keyCtl = TextEditingController(text: c.apiKey);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: AppTheme.largeRadius),
          title: const Text('AI 分析设置', style: AppTheme.cardTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field('模型名称（如 glm-4）', modelCtl),
                const SizedBox(height: 12),
                _field('API 地址（OpenAI 兼容，如 https://open.bigmodel.cn/api/paas/v4）', urlCtl),
                const SizedBox(height: 12),
                _field('API Key', keyCtl, obscure: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('取消', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(d);
                await AiService.saveConfig(AiConfig(
                  model: modelCtl.text.trim(),
                  apiUrl: urlCtl.text.trim(),
                  apiKey: keyCtl.text.trim(),
                ));
                if (mounted) nav.pop();
                if (mounted) messenger.showSnackBar(const SnackBar(content: Text('已保存 AI 配置')));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: AppTheme.smallRadius),
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      );
  }

  Widget _field(String label, TextEditingController ctl, {bool obscure = false}) => TextField(
        controller: ctl,
        obscureText: obscure,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTheme.tagText,
          hintStyle: AppTheme.tagText,
          filled: true,
          fillColor: AppTheme.bgLight,
          border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: AppTheme.smallRadius),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final sum = _summary;
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: AppTheme.bgLight,
        elevation: 0,
        centerTitle: true,
        title: const Text('加班分析', style: AppTheme.pageHeader),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary),
            onPressed: _openConfigDialog,
            tooltip: 'AI 分析设置',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.padH, vertical: 8),
          children: [
            _heroCard(),
            const SizedBox(height: AppTheme.gapV),
            _monthSwitcher(),
            const SizedBox(height: 12),
            _overviewRow(sum),
            const SizedBox(height: AppTheme.gapV),
            _titlesSection(),
          ],
        ),
      ),
    );
  }

  Widget _monthSwitcher() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)), icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.textSecondary)),
        Text('${_month.year}年${_month.month}月', style: AppTheme.cardTitle),
        IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)), icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _heroCard() {
    return CommonCard(
      padding: EdgeInsets.zero,
      radius: AppTheme.largeRadius,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.rLarge)),
            child: Image.asset('wusaqi.jpg', width: double.infinity, height: 140, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI 智能分析', style: AppTheme.cardTitle),
                const SizedBox(height: 6),
                const Text('你是卷王，还是水王？', style: AppTheme.captionText),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
                      : ElevatedButton.icon(
                          onPressed: _generate,
                          icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                          label: const Text('生成分析报告', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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

  Widget _overviewRow(_MonthSummary s) {
    return Row(
      children: [
        Expanded(child: _statCard('打卡天数', '${s.days}', AppTheme.secondaryGreen)),
        const SizedBox(width: 12),
        Expanded(child: _statCard('平均每日', '${s.avgHours.toStringAsFixed(2)}h', AppTheme.accentBlue)),
        const SizedBox(width: 12),
        Expanded(child: _statCard('最长连续', '${s.streak}天', AppTheme.warmNeutral)),
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

  Widget _titlesSection() {
    final pages = _titles.isEmpty ? 1 : (_titles.length / 6).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('我的加班称号', style: AppTheme.cardTitle),
            Text('${_titles.length} 个', style: AppTheme.tagText),
          ],
        ),
        const SizedBox(height: 12),
        if (_titles.isEmpty)
          CommonCard(
            child: const Text('还没有称号，点上方「生成分析报告」获取你的第一个加班称号吧～', style: AppTheme.captionText),
          )
        else
          SizedBox(
            height: 210,
            child: PageView.builder(
              controller: _pageController,
              itemCount: pages,
              onPageChanged: (i) => setState(() => _pageIndex = i),
              itemBuilder: (_, pi) {
                final start = pi * 6;
                final end = (start + 6).clamp(0, _titles.length);
                final slice = _titles.sublist(start, end);
                return GridView.count(
                  crossAxisCount: 3,
                  childAspectRatio: 1.05,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: slice.map(_titleCard).toList(),
                );
              },
            ),
          ),
        if (_titles.isNotEmpty && pages > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < pages; i++)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _pageIndex ? AppTheme.primaryOrange : AppTheme.divider,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _titleCard(EarnedTitle t) {
    final idx = _titles.indexOf(t);
    final color = _titleColors[idx % _titleColors.length];
    return CommonCard(
      color: color,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Text(
                _stripSuffix(t.title),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('${t.year}.${t.month.toString().padLeft(2, '0')}', style: AppTheme.tagText),
        ],
      ),
    );
  }
}

class _MonthSummary {
  _MonthSummary({required this.days, required this.totalHours, required this.avgHours, required this.streak});
  final int days;
  final double totalHours;
  final double avgHours;
  final int streak;
}
