import 'package:flutter/material.dart';

/// 《加了么》统一设计规范
/// 颜色常量、圆角常量、阴影样式、文字样式全部在此封装，禁止业务层硬编码。
class AppTheme {
  AppTheme._();

  // ---------- 主色板 ----------
  static const Color primaryOrange = Color(0xFFF98C53); // 暖橙 Primary
  static const Color primaryOrangeDeep = Color(0xFFE8743A); // 暖橙加深（警告/强调）
  static const Color secondaryGreen = Color(0xFFD2E0AA); // 浅豆绿 Secondary
  static const Color accentBlue = Color(0xFFABD7FB); // 浅天蓝 Accent
  static const Color warmNeutral = Color(0xFFFCCEB4); // 裸杏色 插画底色
  static const Color bgLight = Color(0xFFF9F2EF); // 米白 页面背景

  // ---------- 中性色 ----------
  static const Color textPrimary = Color(0xFF3A3A3A); // 正文深色（非纯黑）
  static const Color textSecondary = Color(0xFF757575); // 次级文字
  static const Color textHint = Color(0xFFAAAAAA); // 占位/提示
  static const Color divider = Color(0xFFEAE3E0); // 分割线

  // ---------- 衍生插画色（色系内柔和衍生） ----------
  static const Color skySoft = Color(0xFFFBE3D6);
  static const Color greenSoft = Color(0xFFE7EFD2);
  static const Color blueSoft = Color(0xFFE2F1FD);
  static const Color mountainWarm = Color(0xFFF6B894);
  static const Color mountainDeep = Color(0xFFF3A77C);

  // ---------- 圆角（统一曲率） ----------
  static const double rSmall = 12; // 小控件、标签、搜索框
  static const double rCard = 16; // 内容卡片、列表项
  static const double rLarge = 20; // 大图卡片、底部弹窗、底部导航
  static const double rTop = 24; // 全屏弹窗顶部圆角

  static const BorderRadius smallRadius = BorderRadius.all(Radius.circular(rSmall));
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(rCard));
  static const BorderRadius largeRadius = BorderRadius.all(Radius.circular(rLarge));
  static const BorderRadius topRadius = BorderRadius.vertical(top: Radius.circular(rTop));

  // ---------- 阴影（轻薄弥散软阴影，单层） ----------
  static const BoxShadow softShadow = BoxShadow(
    color: Color(0x1A000000), // 黑色 10%
    blurRadius: 12,
    offset: Offset(0, 4),
    spreadRadius: 0,
  );

  static const List<BoxShadow> cardShadow = [softShadow];

  // ---------- 文字样式 ----------
  static const TextStyle pageHeader = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    height: 1.2,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    height: 1.2,
  );

  static const TextStyle bodyText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.4,
  );

  static const TextStyle captionText = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.4,
  );

  static const TextStyle tagText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.4,
  );

  // ---------- 通用边距 ----------
  static const double padH = 16; // 页面水平安全边距
  static const double gapV = 20; // 模块垂直间距
}
