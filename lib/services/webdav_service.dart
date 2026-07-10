import 'dart:convert';
import 'dart:io';
import 'package:overtime/services/storage_service.dart';

/// WebDAV 备份：将全部数据以 JSON 形式 PUT 到服务器，或 GET 回来导入。
/// 使用 dart:io HttpClient 直接发请求，无需额外依赖。
class WebDavService {
  WebDavService._();

  static const String _fileName = 'jiale_backup.json';

  static String _join(String url) {
    var u = url.trim();
    if (!u.endsWith('/')) u += '/';
    return '$u$_fileName';
  }

  static Map<String, String> _authHeader(String user, String pass) {
    final token = base64Encode(utf8.encode('$user:$pass'));
    return {'Authorization': 'Basic $token'};
  }

  /// 导出到 WebDAV（PUT）
  static Future<void> exportTo(String url, String user, String pass) async {
    final data = await StorageService.exportAll();
    final body = utf8.encode(jsonEncode(data));
    final uri = Uri.parse(_join(url));
    final req = await HttpClient().putUrl(uri);
    req.headers.set('Authorization', _authHeader(user, pass)['Authorization']!);
    req.headers.set('Content-Type', 'application/json');
    req.add(body);
    final resp = await req.close();
    if (resp.statusCode != 200 && resp.statusCode != 201 && resp.statusCode != 204) {
      final msg = await resp.transform(utf8.decoder).join();
      throw Exception('WebDAV 返回 ${resp.statusCode}：$msg');
    }
  }

  /// 从 WebDAV 导入（GET）
  static Future<void> importFrom(String url, String user, String pass) async {
    final uri = Uri.parse(_join(url));
    final req = await HttpClient().getUrl(uri);
    req.headers.set('Authorization', _authHeader(user, pass)['Authorization']!);
    final resp = await req.close();
    if (resp.statusCode != 200) {
      throw Exception('WebDAV 返回 ${resp.statusCode}，文件可能不存在或无权限');
    }
    final raw = await resp.transform(utf8.decoder).join();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    await StorageService.importAll(data);
  }
}
