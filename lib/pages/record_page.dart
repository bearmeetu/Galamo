import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:overtime/data/holidays.dart';
import 'package:overtime/logic/overtime_calculator.dart';
import 'package:overtime/models/overtime_record.dart';
import 'package:overtime/services/storage_service.dart';
import 'package:overtime/theme/app_theme.dart';
import 'package:overtime/widgets/common_card.dart';

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  DateTime _date = DateTime.now();
  int? _onSeconds;
  int _offSeconds = 22 * 3600; // 默认 22:00:00
  bool _hadMeal = false;
  bool _leave = false;
  String? _reason;
  double? _baseSalary;
  List<OvertimeRecord> _monthRecords = [];

  @override
  void initState() {
    super.initState();
    StorageService.dataVersion.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    StorageService.dataVersion.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final recs = await StorageService.loadRecords();
    final sals = await StorageService.loadSalaries();
    final sal = _salaryFor(sals, _date);
    setState(() {
      _monthRecords = recs;
      _baseSalary = sal?.baseSalary;
    });
  }

  MonthSalary? _salaryFor(List<MonthSalary> sals, DateTime d) {
    for (final s in sals) {
      if (s.year == d.year && s.month == d.month) return s;
    }
    return null;
  }

  DayType get _dayType => HolidayCalendar.classify(_date);

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2025),
      lastDate: DateTime(2027, 12, 31),
      builder: (c, child) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: AppTheme.primaryOrange)), child: child!),
    );
    if (d != null) {
      setState(() => _date = d);
      _load();
    }
  }

  Future<void> _pickTime(bool isOn) async {
    final initial = isOn ? (_onSeconds ?? 9 * 3600) : _offSeconds;
    final picked = await _showSecondPicker(initial);
    if (picked != null) {
      setState(() {
        if (isOn) {
          _onSeconds = picked;
        } else {
          _offSeconds = picked;
        }
      });
    }
  }

  /// 精确到秒的时间选择（原生 TimePicker 只到分钟，这里用三列滚轮自定义）
  Future<int?> _showSecondPicker(int initial) async {
    var h = initial ~/ 3600;
    var m = (initial % 3600) ~/ 60;
    var s = initial % 60;
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.rTop))),
      builder: (c) => SizedBox(
        height: 280,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消', style: TextStyle(color: AppTheme.textSecondary))),
                  Text('选择时间', style: AppTheme.cardTitle),
                  TextButton(
                    onPressed: () => Navigator.pop(c, h * 3600 + m * 60 + s),
                    child: const Text('确定', style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.divider),
            Expanded(
              child: CupertinoTheme(
                data: const CupertinoThemeData(),
                child: Row(
                  children: [
                    _wheel(0, 23, h, (v) => h = v),
                    const Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                    _wheel(0, 59, m, (v) => m = v),
                    const Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                    _wheel(0, 59, s, (v) => s = v),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  Widget _wheel(int min, int max, int value, void Function(int) onChanged) => Expanded(
        child: CupertinoPicker(
          scrollController: FixedExtentScrollController(initialItem: value),
          itemExtent: 36,
          onSelectedItemChanged: onChanged,
          children: [for (var i = min; i <= max; i++) Center(child: Text(i.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 18, color: AppTheme.textPrimary)))],
        ),
      );

  OvertimeResult? get _preview {
    if (_baseSalary == null) return null;
    final rec = _buildRecord();
    return OvertimeCalculator.compute(rec, _baseSalary!);
  }

  OvertimeRecord _buildRecord() => OvertimeRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: _date,
        onSeconds: _onSeconds,
        offSeconds: _offSeconds,
        hadMeal: _hadMeal,
        leave: _leave,
        reason: _reason,
      );

  void _pickReason() {
    showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.rTop))),
      builder: (c) => SizedBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消', style: TextStyle(color: AppTheme.textSecondary))),
                  Text('加班原因（可选）', style: AppTheme.cardTitle),
                  TextButton(
                    onPressed: () => Navigator.pop(c, ''),
                    child: const Text('清空', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.divider),
            ...OvertimeRecord.reasons.map(
              (r) => ListTile(
                title: Text(r, style: AppTheme.bodyText),
                trailing: _reason == r ? const Icon(Icons.check_rounded, color: AppTheme.primaryOrange) : null,
                onTap: () => Navigator.pop(c, r),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).then((v) {
      if (v != null) setState(() => _reason = v.isEmpty ? null : v);
    });
  }

  Future<void> _save() async {
    var sals = await StorageService.loadSalaries();
    if (_salaryFor(sals, _date) == null) {
      final entered = await _askSalary();
      if (entered == null) return;
      sals = [...sals, MonthSalary(year: _date.year, month: _date.month, baseSalary: entered)];
      await StorageService.saveSalaries(sals);
    }
    final recs = await StorageService.loadRecords();
    await StorageService.saveRecords([...recs, _buildRecord()]);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('打卡已保存')));
      _load();
    }
  }

  Future<void> _confirmDelete(OvertimeRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.largeRadius),
        title: const Text('删除这条打卡？', style: AppTheme.cardTitle),
        content: Text('${r.date.month}/${r.date.day}', style: AppTheme.captionText),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrangeDeep, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: AppTheme.smallRadius)),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final recs = await StorageService.loadRecords();
      recs.removeWhere((x) => x.id == r.id);
      await StorageService.saveRecords(recs);
      _load();
    }
  }

  Future<double?> _askSalary() async {
    final ctl = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.largeRadius),
        title: Text('填写 ${_date.year}年${_date.month}月 基础工资', style: AppTheme.cardTitle),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            hintText: '如 10000',
            hintStyle: AppTheme.tagText,
            filled: true,
            fillColor: AppTheme.bgLight,
            border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: AppTheme.smallRadius),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(ctl.text);
              Navigator.pop(c, v);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: AppTheme.smallRadius)),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(backgroundColor: AppTheme.bgLight, elevation: 0, centerTitle: true, title: const Text('加班打卡', style: AppTheme.pageHeader)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.padH, vertical: 8),
          children: [
            _typeBanner(),
            const SizedBox(height: AppTheme.gapV),
            _formCard(),
            const SizedBox(height: AppTheme.gapV),
            if (preview != null) _previewCard(preview),
            const SizedBox(height: AppTheme.gapV),
            PrimaryButton(label: '保存打卡', onPressed: _save, icon: Icons.save_outlined),
            const SizedBox(height: AppTheme.gapV),
            _monthList(),
          ],
        ),
      ),
    );
  }

  Widget _typeBanner() {
    final color = _dayType == DayType.holiday
        ? AppTheme.primaryOrange
        : _dayType == DayType.weekend
            ? AppTheme.accentBlue
            : AppTheme.secondaryGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: color, borderRadius: AppTheme.largeRadius),
      child: Row(
        children: [
          const Icon(Icons.event_note_rounded, color: AppTheme.textPrimary),
          const SizedBox(width: 10),
          Expanded(child: Text('${_date.year}-${_date.month}-${_date.day} · ${_dayTypeLabel()}', style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary))),
        ],
      ),
    );
  }

  String _dayTypeLabel() => _dayType == DayType.holiday ? '节假日（3倍）' : _dayType == DayType.weekend ? '周末（2倍）' : '工作日（1.5倍）';

  Widget _formCard() {
    return CommonCard(
      child: Column(
        children: [
          _row('日期', _dateLabel, onTap: _pickDate),
          const Divider(color: AppTheme.divider, height: 1),
          _row('上班时间', _onSeconds == null ? '（工作日无需）' : OvertimeRecord.fmt(_onSeconds!), onTap: () => _pickTime(true)),
          const Divider(color: AppTheme.divider, height: 1),
          _row('下班时间', OvertimeRecord.fmt(_offSeconds), onTap: () => _pickTime(false)),
          const Divider(color: AppTheme.divider, height: 1),
          _row('加班原因', _reason ?? '（可选）', onTap: _pickReason),
          const Divider(color: AppTheme.divider, height: 1),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('有用餐（扣 0.5h）', style: AppTheme.bodyText),
            value: _hadMeal,
            activeThumbColor: AppTheme.primaryOrange,
            onChanged: (v) => setState(() => _hadMeal = v),
          ),
          const Divider(color: AppTheme.divider, height: 1),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('工作日请假（不计加班）', style: AppTheme.bodyText),
            subtitle: _dayType == DayType.workday ? null : const Text('仅工作日可标记', style: AppTheme.tagText),
            value: _leave,
            activeThumbColor: AppTheme.primaryOrange,
            onChanged: _dayType == DayType.workday ? (v) => setState(() => _leave = v) : null,
          ),
        ],
      ),
    );
  }

  String get _dateLabel => '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Widget _row(String label, String value, {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: AppTheme.bodyText),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)), const Icon(Icons.chevron_right_rounded, color: AppTheme.textHint)],
      ),
      onTap: onTap,
    );
  }

  Widget _previewCard(OvertimeResult r) {
    final color = r.dayType == DayType.holiday ? AppTheme.primaryOrange : r.dayType == DayType.weekend ? AppTheme.accentBlue : AppTheme.secondaryGreen;
    return CommonCard(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('预估', style: AppTheme.captionText),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: r.pay.toStringAsFixed(2), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                const TextSpan(text: ' 元', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('可申报时长 ${r.claimableHours.toStringAsFixed(2)}h · 费率 ${r.rate}x · 时薪 ${r.hourlyWage.toStringAsFixed(2)}',
              style: AppTheme.captionText),
          if (!r.claimable) const Text('不足 1 小时，本月不可申报', style: TextStyle(fontSize: 13, color: AppTheme.primaryOrangeDeep)),
        ],
      ),
    );
  }

  Widget _monthList() {
    final mine = _monthRecords.where((r) => r.date.year == _date.year && r.date.month == _date.month).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('本月打卡（${mine.length}）', style: AppTheme.cardTitle),
        const SizedBox(height: 12),
        if (mine.isEmpty) const Text('还没有记录，保存一条吧', style: AppTheme.captionText),
        ...mine.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CommonCard(
              child: Row(
                children: [
                    ClipRRect(
                      borderRadius: AppTheme.smallRadius,
                      child: SizedBox(width: 56, height: 56, child: Image.asset('jialeme.png', fit: BoxFit.cover)),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${r.date.month}/${r.date.day} · ${r.dayTypeLabel}', style: AppTheme.cardTitle.copyWith(fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('下班 ${r.offLabel}${r.hadMeal ? ' · 用餐' : ''}${r.leave ? ' · 请假' : ''}${r.reason != null ? ' · ${r.reason}' : ''}', style: AppTheme.captionText),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.textHint),
                    onPressed: () => _confirmDelete(r),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
