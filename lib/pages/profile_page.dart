import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:overtime/models/overtime_record.dart';
import 'package:overtime/pages/settings_page.dart';
import 'package:overtime/services/storage_service.dart';
import 'package:overtime/theme/app_theme.dart';
import 'package:overtime/widgets/common_card.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<MonthSalary> _salaries = [];
  String _username = StorageService.cachedUsername;
  String? _avatar = StorageService.cachedAvatar;
  String _appVersion = '';

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
    final info = await PackageInfo.fromPlatform();
    sals.sort((a, b) => '${b.year}${b.month}'.compareTo('${a.year}${a.month}'));
    if (!mounted) return;
    setState(() {
      _salaries = sals;
      _username = name;
      _avatar = avatar;
      _appVersion = info.version;
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
              _actionItem(Icons.system_update_rounded, '检查更新', '当前 v$_appVersion', AppTheme.accentBlue, () => _checkUpdate(context)),
              _actionItem(Icons.info_outline_rounded, '关于加了么', 'v$_appVersion', AppTheme.secondaryGreen, () => _showInfo(context, '关于加了么', '《加了么》帮助你记录加班、按公司规则计算可申报加班费，并在每月 36h 上限内给出最优申报方案。')),
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

  Future<void> _checkUpdate(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
    );
    try {
      final client = HttpClient();
      client.badCertificateCallback = (_, __, ___) => true;
      final req = await client.getUrl(Uri.parse('https://api.github.com/repos/bearmeetu/Galamo/releases/latest'));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      client.close();
      if (res.statusCode != 200) throw Exception('请求失败');
      final json = jsonDecode(body) as Map<String, dynamic>;
      final remoteTag = (json['tag_name'] as String? ?? '').replaceFirst('v', '');
      final releaseBody = (json['body'] as String? ?? '').trim();
      final assets = json['assets'] as List<dynamic>? ?? [];
      String? downloadUrl;
      if (assets.isNotEmpty) {
        downloadUrl = assets[0]['browser_download_url'] as String?;
      }
      if (!mounted) return;
      Navigator.pop(context); // 关闭 loading
      final currentVersion = _appVersion;
      if (_compareVersion(remoteTag, currentVersion) > 0) {
        _showUpdateDialog(context, remoteTag, releaseBody, downloadUrl);
      } else {
        _showInfo(context, '检查更新', '当前已是最新版本 v$currentVersion');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showInfo(context, '检查更新', '检查失败，请稍后重试');
    }
  }

  int _compareVersion(String a, String b) {
    final pa = a.split('.').map(int.tryParse).toList();
    final pb = b.split('.').map(int.tryParse).toList();
    for (var i = 0; i < 3; i++) {
      final va = (i < pa.length ? pa[i] : 0) ?? 0;
      final vb = (i < pb.length ? pb[i] : 0) ?? 0;
      if (va != vb) return va > vb ? 1 : -1;
    }
    return 0;
  }

  void _showUpdateDialog(BuildContext context, String version, String body, String? downloadUrl) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.largeRadius),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.primaryOrange.withValues(alpha: 0.15), borderRadius: AppTheme.smallRadius),
              child: const Icon(Icons.system_update_rounded, color: AppTheme.primaryOrange, size: 22),
            ),
            const SizedBox(width: 12),
            Text('发现新版本 v$version', style: AppTheme.cardTitle),
          ],
        ),
        content: body.isEmpty
            ? const Text('有新版本可用，建议立即更新。', style: AppTheme.bodyText)
            : SingleChildScrollView(child: Text(body, style: AppTheme.bodyText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('取消', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(c);
              if (downloadUrl != null) {
                final uri = Uri.parse(downloadUrl);
                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppTheme.smallRadius),
            ),
            child: const Text('去更新'),
          ),
        ],
      ),
    );
  }
}
