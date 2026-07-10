import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:overtime/services/notification_service.dart';
import 'package:overtime/services/storage_service.dart';
import 'package:overtime/services/webdav_service.dart';
import 'package:overtime/theme/app_theme.dart';
import 'package:overtime/widgets/common_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _remindOn = false;
  String _remindTime = '19:00';
  bool _warnOn = false;
  int _warnDays = 3;

  final _urlCtl = TextEditingController();
  final _userCtl = TextEditingController();
  final _passCtl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlCtl.dispose();
    _userCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _remindOn = p.getBool('remind_on') ?? false;
      _remindTime = p.getString('remind_time') ?? '19:00';
      _warnOn = p.getBool('warn_on') ?? false;
      _warnDays = p.getInt('warn_days') ?? 3;
      _urlCtl.text = p.getString('webdav_url') ?? '';
      _userCtl.text = p.getString('webdav_user') ?? '';
      _passCtl.text = p.getString('webdav_pass') ?? '';
    });
  }

  Future<void> _set(String k, dynamic v) async {
    final p = await SharedPreferences.getInstance();
    if (v is bool) await p.setBool(k, v);
    if (v is String) await p.setString(k, v);
    if (v is int) await p.setInt(k, v);
  }

  /// 启用/停用每日提醒：请求权限并按需调度或取消定时通知
  Future<void> _applyReminder(bool on) async {
    if (on) {
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        if (mounted) _showMsg('未授予通知权限，无法提醒');
        return;
      }
      try {
        await NotificationService.scheduleDailyReminder(_remindTime);
        if (mounted) {
          setState(() => _remindOn = true);
          await _set('remind_on', true);
          _showMsg('已开启每天 $_remindTime 的打卡提醒');
        }
      } catch (e) {
        if (mounted) _showErr(e);
      }
    } else {
      try {
        await NotificationService.cancelReminder();
      } catch (_) {
        // 取消失败也不阻塞关闭开关
      }
      if (mounted) {
        setState(() => _remindOn = false);
        await _set('remind_on', false);
      }
    }
  }

  Future<void> _pickTime() async {
    final parts = _remindTime.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      builder: (c, child) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: AppTheme.primaryOrange)), child: child!),
    );
    if (t != null) {
      final s = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      setState(() => _remindTime = s);
      _set('remind_time', s);
      if (_remindOn) await NotificationService.scheduleDailyReminder(s);
    }
  }

  void _showMsg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  void _showErr(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败：$e')));

  Future<void> _exportLocal() async {
    try {
      final json = jsonEncode(await StorageService.exportAll());
      final stamp = '${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '导出备份',
        fileName: 'jiale_backup_$stamp.json',
        bytes: utf8.encode(json),
      );
      if (path != null) _showMsg('已导出到：$path');
    } catch (e) {
      _showErr(e);
    }
  }

  Future<void> _importLocal() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (res == null || res.files.single.bytes == null) return;
      final data = jsonDecode(utf8.decode(res.files.single.bytes!)) as Map<String, dynamic>;
      await StorageService.importAll(data);
      _showMsg('已从本地导入，数据已更新');
    } catch (e) {
      _showErr(e);
    }
  }

  Future<void> _exportWebdav() async {
    await _persistWebdav();
    if (!_checkWebdav()) return;
    await _run(() async {
      await WebDavService.exportTo(_urlCtl.text, _userCtl.text, _passCtl.text);
      _showMsg('已导出到 WebDAV');
    });
  }

  Future<void> _importWebdav() async {
    await _persistWebdav();
    if (!_checkWebdav()) return;
    await _run(() async {
      await WebDavService.importFrom(_urlCtl.text, _userCtl.text, _passCtl.text);
      _showMsg('已从 WebDAV 导入，数据已更新');
    });
  }

  bool _checkWebdav() {
    if (_urlCtl.text.trim().isEmpty) {
      _showMsg('请先填写 WebDAV 地址');
      return false;
    }
    return true;
  }

  Future<void> _persistWebdav() async {
    await _set('webdav_url', _urlCtl.text.trim());
    await _set('webdav_user', _userCtl.text.trim());
    await _set('webdav_pass', _passCtl.text);
  }

  Future<void> _run(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      _showErr(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(backgroundColor: AppTheme.bgLight, elevation: 0, centerTitle: true, title: const Text('提醒与备份', style: AppTheme.pageHeader)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.padH, vertical: AppTheme.gapV),
          children: [
            CommonCard(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('每日提醒打卡', style: AppTheme.bodyText),
                subtitle: Text('每天 $_remindTime 提醒', style: AppTheme.tagText),
                value: _remindOn,
                activeThumbColor: AppTheme.primaryOrange,
                onChanged: (v) => _applyReminder(v),
              ),
            ),
            const SizedBox(height: 12),
            if (_remindOn)
              CommonCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('提醒时间', style: AppTheme.bodyText),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Text(_remindTime, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)), const Icon(Icons.chevron_right_rounded, color: AppTheme.textHint)],
                  ),
                  onTap: _pickTime,
                ),
              ),
            const SizedBox(height: 12),
            CommonCard(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('加班预警', style: AppTheme.bodyText),
                subtitle: Text('连续加班 $_warnDays 天提醒休息', style: AppTheme.tagText),
                value: _warnOn,
                activeThumbColor: AppTheme.primaryOrange,
                onChanged: (v) async {
                  if (v) {
                    final granted = await NotificationService.requestPermission();
                    if (!granted) {
                      if (mounted) _showMsg('未授予通知权限，无法预警');
                      return;
                    }
                  }
                  if (mounted) setState(() => _warnOn = v);
                  await _set('warn_on', v);
                },
              ),
            ),
            const SizedBox(height: 12),
            if (_warnOn)
              CommonCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('连续天数阈值', style: AppTheme.bodyText),
                    Row(
                      children: [
                        IconButton(onPressed: _warnDays > 1 ? () => _setDays(_warnDays - 1) : null, icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primaryOrange)),
                        Text('$_warnDays', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                        IconButton(onPressed: _warnDays < 30 ? () => _setDays(_warnDays + 1) : null, icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryOrange)),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppTheme.gapV),
            _backupCard(),
          ],
        ),
      ),
    );
  }

  Widget _backupCard() {
    return CommonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('数据备份与恢复', style: AppTheme.cardTitle),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: _exportLocal, icon: const Icon(Icons.upload_outlined), label: const Text('导出到本地'), style: _outlineStyle)),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(onPressed: _importLocal, icon: const Icon(Icons.download_outlined), label: const Text('从本地导入'), style: _outlineStyle)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: 16),
          const Text('云端备份', style: AppTheme.bodyText),
          const SizedBox(height: 12),
          _backupField('云端地址（含 http(s)://）', _urlCtl),
          _backupField('账号', _userCtl),
          _backupField('密码', _passCtl, obscure: true),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _exportWebdav, icon: const Icon(Icons.cloud_upload_outlined), label: const Text('导出到云端'), style: _outlineStyle)),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _importWebdav, icon: const Icon(Icons.cloud_download_outlined), label: const Text('从云端导入'), style: _outlineStyle)),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 12),
            const Row(children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryOrange)), SizedBox(width: 8), Text('处理中…', style: AppTheme.tagText)]),
          ],
        ],
      ),
    );
  }

  Widget _backupField(String label, TextEditingController ctl, {bool obscure = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
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
        ),
      );
  ButtonStyle get _outlineStyle => OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryOrange,
        side: const BorderSide(color: AppTheme.primaryOrange),
        shape: RoundedRectangleBorder(borderRadius: AppTheme.smallRadius),
      );

  void _setDays(int v) {
    setState(() => _warnDays = v);
    _set('warn_days', v);
  }
}
