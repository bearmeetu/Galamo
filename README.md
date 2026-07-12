# 加了么（Galamo）

> 一款主打「轻治愈 · 莫兰迪」风格的 Android 加班记录 App：记录上下班打卡、按公司规则计算可申报加班费，并在每月 36 小时上限内给出最优申报方案，还能用 AI 把你的加班数据总结成有趣的「加班称号」。

[![Build & Release APK](https://github.com/bearmeetu/Galamo/actions/workflows/release.yml/badge.svg)](https://github.com/bearmeetu/Galamo/actions/workflows/release.yml)

📥 **[点击下载最新 APK](https://github.com/bearmeetu/Galamo/releases/latest)**

---

## ✨ 功能特性

- **打卡记录**：上下班时间精确到**秒**；自动区分工作日 / 周末 / 节假日（法定节假日内置在 `data/holidays.dart`）；支持「用餐扣 0.5h」「工作日请假不计加班」。
- **加班费计算**：时薪 = 基础工资 ÷ 21.75 ÷ 8；费率 工作日 1.5x、周末 2x、节假日 3x；可申报时长精确到**小数点后两位**，不足 1h 不可申报。
- **月度统计**：每日加班时长柱状图（点击柱子显示两位小数）、GitHub 风格打卡活跃图、36h 申报额度进度条、月加班组成圆环饼图。
- **最优申报方案**：在 36h 上限内按「节假日 > 周末 > 工作日」优先级贪心取满，最大化加班费；超出部分**当月作废，不可顺延**。
- **AI 分析**：调用 OpenAI 格式兼容接口（如智谱 GLM）生成月度报告；根据总时长给出专属「加班称号」（一个月一个，多次生成只保留最后一次），支持把报告**保存为图片**。
- **桌面小组件**：三种桌面 Widget —— 每日加班时长柱状图、每月加班时长柱状图、月加班组成圆环饼图，数据实时同步。
- **检查更新**：从 GitHub Release 自动检测新版本，一键跳转下载更新。
- **每日提醒打卡**：精确闹钟提醒（失败时退化为非精确），开关可关。
- **加班预警**：连续加班达到阈值时提示休息。
- **数据备份**：本地 JSON 导出/导入，以及 WebDAV 云端备份。
- **我的**：修改用户名、头像、查看各月基础工资。

---

## 🧱 技术栈

| 领域 | 方案 |
| --- | --- |
| 框架 | Flutter 3.x（Dart 3.12+） |
| 状态/数据 | `shared_preferences`（本地持久化） |
| 通知 | `flutter_local_notifications` + `timezone` / `flutter_timezone` |
| 文件选择 | `file_picker`、`path_provider`、`image_picker` |
| 桌面小组件 | Android 原生 `AppWidgetProvider` + Canvas Bitmap 绘制 |
| 版本更新 | `package_info_plus` + GitHub Releases API |
| 图标生成 | `flutter_launcher_icons`（dev） |
| AI 接口 | 原生 `HttpClient` 调 OpenAI Chat Completions 格式 |

> 注：早期版本依赖 `geolocator`（打卡地点/GPS），现已**移除**，相关字段与权限一并删除。

---

## 📁 目录结构

```
lib/
├── main.dart                 # 入口：初始化通知、重新挂提醒、启动 App
├── models/
│   └── overtime_record.dart  # 打卡记录 / 月基础工资模型
├── data/
│   └── holidays.dart         # 2025–2026 法定节假日（工作日/周末/节假日判定）
├── logic/
│   └── overtime_calculator.dart  # 时长/金额计算 + 36h 内最优申报方案
├── services/
│   ├── storage_service.dart  # 本地持久化（记录/工资/用户名/头像）
│   ├── notification_service.dart # 每日提醒/预警 + 清遗留定时（修复白屏）
│   ├── ai_service.dart       # OpenAI 兼容调用 + 提示词 + 称号解析/存储
│   ├── webdav_service.dart   # WebDAV 备份
│   └── widget_data_service.dart # 桌面小组件数据桥接
├── pages/
│   ├── home_page.dart        # 首页（hero 背景图 + 最近打卡）
│   ├── record_page.dart      # 打卡（秒级时间选择）
│   ├── stats_page.dart       # 统计（柱状图/活跃图/申报方案/圆环饼图）
│   ├── analysis_page.dart    # 分析（AI 报告 + 称号展示）
│   ├── settings_page.dart    # 提醒与备份
│   └── profile_page.dart     # 我的（检查更新/关于）
├── theme/app_theme.dart      # 莫兰迪色板 / 圆角 / 阴影 / 文字样式
└── widgets/
    ├── common_card.dart      # 通用卡片 / 标签 / 按钮
    └── illustrations.dart    # 扁平插画（已改为小猫主题，UI 仍可复用）

android/app/src/main/kotlin/.../widget/
├── OvertimeWidgetProvider.kt  # 小组件基类（读取 SharedPreferences）
├── DailyOvertimeWidget.kt     # 每日加班时长柱状图
├── MonthlyOvertimeWidget.kt   # 每月加班时长柱状图
├── ReasonOvertimeWidget.kt    # 月加班组成圆环饼图
└── WidgetChartPainter.kt      # Canvas Bitmap 绘制引擎
```

资源文件（项目根目录，已注册到 `pubspec.yaml` 的 `assets`）：
- `jialeme.png`：应用图标源图，同时用作每条打卡记录的小图标（512×512）。
- `wusaqi.jpg`：首页与分析页 hero 背景图（1080×675）。
- `prompts.md`：AI 分析提示词（与 `ai_service.dart` 中 `kAnalysisPrompt` 需保持一致）。

---

## 🚀 快速开始

### 环境要求
- Flutter SDK ≥ 3.12（与 `pubspec.yaml` 中 `sdk: ^3.12.2` 匹配）
- Android SDK（已配置 `ANDROID_SDK_ROOT`）
- 一台 Android 设备 / 模拟器

### 运行
```bash
flutter pub get
flutter run
```

### 构建 Release APK
```bash
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```
> Release 构建已开启 R8 混淆并应用 `android/app/proguard-rules.pro`。**该规则必须保留**：`flutter_local_notifications` 在 release 下反序列化已存储的定时通知会因泛型签名被抹除而抛 `Missing type parameter` 崩溃，keep 规则可修复。

### CI/CD
推送 `main` 分支后，GitHub Actions 自动构建 APK 并发布到 [Releases](https://github.com/bearmeetu/Galamo/releases/latest)。

---

## 🤖 AI 分析配置

在「分析」页右上角 ⚙️ 中填写：
- **模型名称**：如 `glm-4`
- **API 地址**：OpenAI 格式兼容地址，如 `https://open.bigmodel.cn/api/paas/v4`（代码会自动补全 `/chat/completions`）
- **API Key**

点击「生成分析报告」后，App 会把当月打卡数据整理成文本，连同 `prompts.md` 的提示词一起发给模型，返回报告并解析出「加班称号」。

**提示词同步说明**：运行时读取的是 `lib/services/ai_service.dart` 里内嵌的 `kAnalysisPrompt` 常量（release 包无法访问工程内 `prompts.md` 文件）。修改 `prompts.md` 后请同步更新该常量。

---

## 💾 数据存储

所有数据保存在 Android `SharedPreferences`：
- `overtime_records`：打卡记录
- `overtime_salaries`：各月基础工资
- `overtime_username` / `overtime_avatar`：用户名 / 头像路径
- `ai_config`：AI 模型/地址/Key
- `overtime_titles`：已获得的加班称号（按 年-月 唯一）

---

## ⚠️ 已知限制

- AI 接口需用户自备兼容服务与 Key，未配置时生成会引导填写设置。
- WebDAV 导入按**固定文件名** `jiale_backup.json` 拉取，不支持在 App 内选择多个备份文件。
- 法定节假日数据内置至 2026 年，之后需手动更新 `data/holidays.dart`。
- 分析页插画已改为小猫主题；如需换回场景插画可复用 `widgets/illustrations.dart`。

---

## 📄 许可证

本项目仅供学习与个人使用。
