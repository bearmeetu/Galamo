import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:overtime/models/overtime_record.dart';
import 'package:overtime/pages/settings_page.dart';
import 'package:overtime/services/storage_service.dart';
import 'package:overtime/theme/app_theme.dart';
import 'package:overtime/widgets/common_card.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<MonthSalary> _salaries = [];
  String _username = StorageService.cachedUsername;
  String? _avatar = StorageService.cachedAvatar;

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
    final sals = await StorageService.loadSalaries();
    final name = await StorageService.loadUsername();
    final avatar = await StorageService.loadAvatar();
    sals.sort((a, b) => '${b.year}${b.month}'.compareTo('${a.year}${a.month}'));
    if (!mounted) return;
    setState(() {
      _salaries = sals;
      _username = name;
      _avatar = avatar;
    });
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, maxWidth: 256, maxHeight: 256);
    if (x != null) {
      await StorageService.saveAvatar(x.path);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.padH, vertical: AppTheme.gapV),
          children: [
            _header(),
            const SizedBox(height: AppTheme.gapV),
            _salarySection(),
            const SizedBox(height: AppTheme.gapV),
            _menuSection([
              _actionItem(Icons.access_time_rounded, '每日提醒', '设置提醒打卡', AppTheme.primaryOrange, () => _openSettings(context)),
              _actionItem(Icons.notifications_none_rounded, '加班预警', '连续加班提醒休息', AppTheme.secondaryGreen, () => _openSettings(context)),
              _actionItem(Icons.backup_outlined, '数据备份', '本地 / WebDAV 导入导出', AppTheme.accentBlue, () => _openSettings(context)),
            ]),
            const SizedBox(height: AppTheme.gapV),
            _menuSection([
              _actionItem(Icons.palette_outlined, '主题外观', '轻治愈 · 莫兰迪', AppTheme.primaryOrange, () => _showInfo(context, '主题外观', '当前主题为「轻治愈 · 莫兰迪」，后续可在设置中扩展更多配色。')),
              _actionItem(Icons.info_outline_rounded, '关于加了么', 'v1.0.0', AppTheme.secondaryGreen, () => _showInfo(context, '关于加了么', '《加了么》帮助你记录加班、按公司规则计算可申报加班费，并在每月 36h 上限内给出最优申报方案。')),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return CommonCard(
      radius: AppTheme.largeRadius,
      onTap: _editUsername,
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickAvatar,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: AppTheme.warmNeutral, borderRadius: AppTheme.smallRadius),
              child: _avatar != null
                  ? ClipRRect(
                      borderRadius: AppTheme.smallRadius,
                      child: Image.file(File(_avatar!), width: 60, height: 60, fit: BoxFit.cover),
                    )
                  : const Center(child: Text('加', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500, color: AppTheme.primaryOrange))),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_username, style: AppTheme.cardTitle),
                const SizedBox(height: 4),
                const Text('修改个人资料', style: AppTheme.captionText),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textHint),
        ],
      ),
    );
  }

  Future<void> _editUsername() async {
    final ctl = TextEditingController(text: _username);
    final v = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.largeRadius),
        title: const Text('修改用户名', style: AppTheme.cardTitle),
        content: TextField(
          controller: ctl,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            hintText: '输入用户名',
            hintStyle: AppTheme.tagText,
            filled: true,
            fillColor: AppTheme.bgLight,
            border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: AppTheme.smallRadius),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, ctl.text.trim().isEmpty ? null : ctl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: AppTheme.smallRadius)),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (v != null) {
      await StorageService.saveUsername(v);
      _load();
    }
  }

  Widget _salarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('基础工资记录', style: AppTheme.cardTitle),
        const SizedBox(height: 12),
        if (_salaries.isEmpty)
          const Text('暂无记录，打卡时会自动提示填写', style: AppTheme.captionText)
        else
          CommonCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: _salaries
                  .map(
                    (s) => Column(
                      children: [
                        ListTile(
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(color: AppTheme.warmNeutral, borderRadius: AppTheme.smallRadius),
                            child: const Icon(Icons.payments_outlined, color: AppTheme.primaryOrange, size: 20),
                          ),
                          title: Text('${s.year}年${s.month}月', style: AppTheme.bodyText),
                          trailing: Text('¥${s.baseSalary.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        ),
                        if (s != _salaries.last) const Divider(color: AppTheme.divider, height: 1),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _menuSection(List<Widget> items) {
    return CommonCard(padding: EdgeInsets.zero, child: Column(children: items));
  }

  Widget _actionItem(IconData icon, String title, String sub, Color accent, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: accent.withValues(alpha: 0.25), borderRadius: AppTheme.smallRadius),
        child: Icon(icon, color: AppTheme.textPrimary, size: 20),
      ),
      title: Text(title, style: AppTheme.bodyText),
      subtitle: Text(sub, style: AppTheme.tagText),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textHint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      onTap: onTap,
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
  }

  void _showInfo(BuildContext context, String title, String body) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.largeRadius),
        title: Text(title, style: AppTheme.cardTitle),
        content: Text(body, style: AppTheme.bodyText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('知道了', style: TextStyle(color: AppTheme.primaryOrange)),
          ),
        ],
      ),
    );
  }
}
