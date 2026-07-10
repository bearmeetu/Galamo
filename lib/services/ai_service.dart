import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// AI 分析报告配置（OpenAI 格式兼容，如智谱 GLM）
class AiConfig {
  AiConfig({required this.model, required this.apiUrl, required this.apiKey});

  final String model;
  final String apiUrl;
  final String apiKey;

  Map<String, String> toJson() => {'model': model, 'apiUrl': apiUrl, 'apiKey': apiKey};

  factory AiConfig.fromJson(Map<String, dynamic> j) =>
      AiConfig(model: j['model'] ?? '', apiUrl: j['apiUrl'] ?? '', apiKey: j['apiKey'] ?? '');

  bool get isValid => model.trim().isNotEmpty && apiUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;
}

/// 用户获得的加班称号（按 年-月 唯一，重复生成只保留最后一次）
class EarnedTitle {
  EarnedTitle({required this.year, required this.month, required this.title});

  final int year;
  final int month;
  final String title;

  String get key => '$year-${month.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {'year': year, 'month': month, 'title': title};

  factory EarnedTitle.fromJson(Map<String, dynamic> j) =>
      EarnedTitle(year: j['year'], month: j['month'], title: j['title']);
}

/// AI 分析服务：调用 OpenAI 格式兼容的聊天补全接口，并管理称号存储。
class AiService {
  AiService._();

  static const String _cfgKey = 'ai_config';
  static const String _titlesKey = 'overtime_titles';

  /// prompts.md 中的提示词（运行时无法读取工程文件，故内嵌）
  static const String kAnalysisPrompt = '''
你是职场月度加班总结分析师。
## 硬性规则
1. 所有分析严格基于提供的月度加班原始数据，结论不能脱离事实，禁止编造信息；统计维度覆盖：加班总时长、加班天数、休息日加班情况、最晚下班时间、加班集中时段。
2. 总时长区间完整覆盖 0～100h（适配月内任意节点统计，月初时长偏低、月末上限100h），每5小时划分一档，所有加班称号≤6个字，区间划分与加班称号如下：
0h～5h：准时下班锦鲤本鲤
5h～10h：卡点撤退专业选手
10h～15h：佛系躺平打工人
15h～20h：职场加班新手
20h～25h：应急临时救火员
25h～30h：琐事日常兜底人
30h～35h：被迫加班受害者
35h～40h：暮色晚间留守员
40h～45h：工位半常驻选手
45h～50h：黄昏加班爱好者
50h～55h：夜班奋斗预备役
55h～60h：深夜公司守夜人
60h～65h：持续熬夜攻坚员
65h～70h：内卷起步初级卷王
70h～75h：稳步进阶卷王
75h～80h：实力资深卷王
80h～85h：耐力拉满续航达人
85h～90h：灯火不眠夜间标兵
90h～95h：全力冲刺硬核卷王
95h～100h：突破上限奋斗者
> 附加规则：若休息日加班占当月总加班40%以上，称号后缀追加【周末献祭版】
3. 输出开头第一句固定格式：【用户名】，你是一名「加班称号」。
4. 内容分为两大块：【数据概况】+【趣味点评】
5. 全文控制200～360字，合理换行分段，适当在文中插入 emoji，排版宽松适配手机阅读，不要密集大段文字。
6. 禁止单纯罗列数字，需要提炼归纳行为规律；点评风格：抽象玩梗、搞笑、轻度扎心微冒犯，仅吐槽加班作息状态，严禁攻击智商、工作能力、人身辱骂。
✅允许轻度阴阳调侃；❌禁止负面人身攻击
7. 语言口语化，摒弃公文书面腔调。
## 强制输出模板
【用户名】，你是一名「加班称号」。
📊本月加班概况
精简汇总核心指标，提炼关键加班特征，不要堆砌全部明细
💡月度总结点评
基于数据规律进行趣味扎心点评，可以玩梗、适度抽象吐槽
''';

  static Future<AiConfig> loadConfig() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cfgKey);
    if (raw == null) return AiConfig(model: '', apiUrl: '', apiKey: '');
    return AiConfig.fromJson(jsonDecode(raw));
  }

  static Future<void> saveConfig(AiConfig c) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cfgKey, jsonEncode(c.toJson()));
  }

  static Future<List<EarnedTitle>> loadTitles() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_titlesKey) ?? [];
    final list = raw.map((e) => EarnedTitle.fromJson(jsonDecode(e) as Map<String, dynamic>)).toList();
    list.sort((a, b) => '${b.year}${b.month}'.compareTo('${a.year}${a.month}'));
    return list;
  }

  /// 保存某年月的称号：同月重复生成只保留最后一次
  static Future<List<EarnedTitle>> saveTitleForMonth(int year, int month, String title) async {
    final titles = await loadTitles();
    titles.removeWhere((t) => t.year == year && t.month == month);
    titles.add(EarnedTitle(year: year, month: month, title: title));
    titles.sort((a, b) => '${b.year}${b.month}'.compareTo('${a.year}${a.month}'));
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_titlesKey, titles.map((t) => jsonEncode(t.toJson())).toList());
    return titles;
  }

  /// 调用 OpenAI 格式兼容接口生成分析报告
  static Future<String> analyze({
    required AiConfig cfg,
    required String username,
    required String dataSummary,
  }) async {
    final uri = Uri.parse(_resolveUrl(cfg.apiUrl));
    final body = jsonEncode({
      'model': cfg.model,
      'messages': [
        {'role': 'system', 'content': kAnalysisPrompt},
        {'role': 'user', 'content': '用户名：$username\n\n$dataSummary'},
      ],
      'temperature': 0.8,
    });

    final client = HttpClient();
    final req = await client.postUrl(uri)
      ..headers.contentType = ContentType.json
      ..headers.add('Authorization', 'Bearer ${cfg.apiKey}');
    req.write(body);
    final resp = await req.close();
    final text = await resp.transform(utf8.decoder).join();
    if (resp.statusCode != 200) {
      client.close();
      throw Exception('AI 接口返回 ${resp.statusCode}：$text');
    }
    client.close();
    final data = jsonDecode(text) as Map<String, dynamic>;
    final content = data['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.trim().isEmpty) throw Exception('AI 返回内容为空');
    return content.trim();
  }

  /// 从报告文本中提取称号（取开头第一句「...」内的内容）
  static String parseTitle(String report) {
    final start = report.indexOf('「');
    if (start == -1) return '';
    final end = report.indexOf('」', start);
    if (end == -1) return '';
    return report.substring(start + 1, end).trim();
  }

  /// 兼容用户填写 base URL 或完整 endpoint
  static String _resolveUrl(String url) {
    var u = url.trim();
    if (u.isEmpty) return u;
    if (!u.endsWith('/chat/completions')) {
      if (!u.endsWith('/')) u += '/';
      u += 'chat/completions';
    }
    return u;
  }
}
