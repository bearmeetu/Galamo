import 'package:flutter/material.dart';
import 'package:overtime/theme/app_theme.dart';

/// 扁平插画场景：无描边、无渐变、纯色块层次。
/// 全部改为「可爱小猫」主题，遵循 .opencode/skills/UI-Design 莫兰迪扁平规范。
class FlatScene extends StatelessWidget {
  const FlatScene({super.key, required this.variant, this.fit = BoxFit.cover});

  final SceneVariant variant;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final painter = switch (variant) {
      SceneVariant.sunset => const _SunsetPainter(),
      SceneVariant.night => const _NightPainter(),
      SceneVariant.spring => const _SpringPainter(),
      SceneVariant.winter => const _WinterPainter(),
    };
    return CustomPaint(painter: painter, child: const SizedBox.expand());
  }
}

enum SceneVariant { sunset, night, spring, winter }

/// 公共小工具
void _tri(Canvas c, Paint p, double x1, double y1, double x2, double y2, double x3, double y3) {
  final path = Path()..moveTo(x1, y1)..lineTo(x2, y2)..lineTo(x3, y3)..close();
  c.drawPath(path, p);
}

void _hill(Canvas canvas, double w, double h, double top, Color color, double shift) {
  final paint = Paint()..color = color;
  final path = Path();
  path.moveTo(0, h);
  path.lineTo(0, top);
  path.quadraticBezierTo(w * 0.5, top - h * 0.12 + shift * h, w, top + h * 0.04);
  path.lineTo(w, h);
  path.close();
  canvas.drawPath(path, paint);
}

/// 一只坐姿小猫：圆头、三角耳、椭圆身子、卷尾，无描边，扁平色块。
void _cat(
  Canvas c,
  Size size,
  double cx,
  double groundY,
  double s,
  Color body,
  Color inner,
  Color nose, {
  Color? scarf,
}) {
  final b = Paint()..color = body;

  // 尾巴
  final tail = Paint()
    ..color = body
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5 * s
    ..strokeCap = StrokeCap.round;
  final tp = Path();
  tp.moveTo(cx + 12 * s, groundY - 4 * s);
  tp.quadraticBezierTo(cx + 27 * s, groundY - 9 * s, cx + 20 * s, groundY - 27 * s);
  c.drawPath(tp, tail);

  // 身体（蛋形）
  c.drawOval(Rect.fromCenter(center: Offset(cx, groundY - 13 * s), width: 28 * s, height: 30 * s), b);

  // 头
  final hy = groundY - 30 * s;
  c.drawCircle(Offset(cx, hy), 12 * s, b);

  // 耳朵
  _tri(c, b, cx - 11 * s, hy - 5 * s, cx - 2 * s, hy - 5 * s, cx - 6.5 * s, hy - 17 * s);
  _tri(c, b, cx + 11 * s, hy - 5 * s, cx + 2 * s, hy - 5 * s, cx + 6.5 * s, hy - 17 * s);

  // 耳朵内侧
  final ip = Paint()..color = inner;
  _tri(c, ip, cx - 9 * s, hy - 7 * s, cx - 4 * s, hy - 7 * s, cx - 6.5 * s, hy - 14 * s);
  _tri(c, ip, cx + 9 * s, hy - 7 * s, cx + 4 * s, hy - 7 * s, cx + 6.5 * s, hy - 14 * s);

  // 围巾（仅冬季）
  if (scarf != null) {
    final sp = Paint()..color = scarf;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, hy + 11 * s), width: 22 * s, height: 6 * s),
        Radius.circular(3 * s),
      ),
      sp,
    );
  }

  // 眼睛
  final ep = Paint()..color = AppTheme.textPrimary;
  c.drawCircle(Offset(cx - 4.5 * s, hy), 1.8 * s, ep);
  c.drawCircle(Offset(cx + 4.5 * s, hy), 1.8 * s, ep);

  // 鼻子
  final np = Paint()..color = nose;
  _tri(c, np, cx - 1.8 * s, hy + 3 * s, cx + 1.8 * s, hy + 3 * s, cx, hy + 5.5 * s);

  // 嘴（小微笑）
  final mp = Paint()
    ..color = AppTheme.textPrimary
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1 * s
    ..strokeCap = StrokeCap.round;
  final m = Path();
  m.moveTo(cx, hy + 5.5 * s);
  m.quadraticBezierTo(cx - 3 * s, hy + 8 * s, cx - 5 * s, hy + 6 * s);
  m.moveTo(cx, hy + 5.5 * s);
  m.quadraticBezierTo(cx + 3 * s, hy + 8 * s, cx + 5 * s, hy + 6 * s);
  c.drawPath(m, mp);
}

/// 黄昏加班：暖橙天幕 + 远山 + 小楼 + 一只看夕阳的猫
class _SunsetPainter extends CustomPainter {
  const _SunsetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final s = h / 150;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = AppTheme.skySoft);

    // 太阳
    canvas.drawCircle(Offset(w * 0.76, h * 0.3), w * 0.12, Paint()..color = AppTheme.primaryOrange);

    // 远山（浅）/近山（深）
    _hill(canvas, w, h, h * 0.66, AppTheme.warmNeutral, 0.18);
    _hill(canvas, w, h, h * 0.78, AppTheme.mountainWarm, -0.1);

    // 小楼剪影
    final building = Paint()..color = AppTheme.warmNeutral;
    final bw = w * 0.22;
    final bh = h * 0.3;
    final bx = w * 0.6;
    final by = h - bh - h * 0.04;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(10)), building);
    final win = Paint()..color = AppTheme.primaryOrange;
    for (var r = 0; r < 3; r++) {
      for (var col = 0; col < 2; col++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(bx + bw * 0.18 + col * bw * 0.42, by + bh * 0.16 + r * bh * 0.28, bw * 0.22, bh * 0.16),
            const Radius.circular(3),
          ),
          win,
        );
      }
    }

    // 看夕阳的猫
    _cat(canvas, size, w * 0.28, h * 0.74, s, AppTheme.warmNeutral, AppTheme.primaryOrange, AppTheme.primaryOrangeDeep);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 深夜加班：浅蓝夜空 + 月亮 + 星点 + 城市 + 一只看月亮的猫
class _NightPainter extends CustomPainter {
  const _NightPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final s = h / 150;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = AppTheme.blueSoft);

    // 月亮
    canvas.drawCircle(Offset(w * 0.78, h * 0.26), w * 0.1, Paint()..color = Colors.white);

    // 星点
    final star = Paint()..color = AppTheme.accentBlue;
    for (final p in [Offset(0.2, 0.2), Offset(0.34, 0.34), Offset(0.5, 0.16), Offset(0.62, 0.3)]) {
      canvas.drawCircle(Offset(w * p.dx, h * p.dy), 2.5, star);
    }

    // 城市剪影
    final city = Paint()..color = AppTheme.warmNeutral;
    final blocks = [0.1, 0.22, 0.16, 0.28, 0.18, 0.24];
    var x = w * 0.06;
    for (final bl in blocks) {
      final bh = h * bl;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, h - bh - h * 0.04, w * 0.1, bh), const Radius.circular(8)), city);
      x += w * 0.145;
    }

    // 看月亮的猫
    _cat(canvas, size, w * 0.34, h * 0.74, s, AppTheme.warmNeutral, AppTheme.accentBlue, AppTheme.primaryOrangeDeep);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 春日绿地：豆绿丘陵 + 小路 + 晒太阳的猫
class _SpringPainter extends CustomPainter {
  const _SpringPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final s = h / 150;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = AppTheme.blueSoft);
    canvas.drawCircle(Offset(w * 0.2, h * 0.26), w * 0.09, Paint()..color = AppTheme.warmNeutral);
    _hill(canvas, w, h, h * 0.62, AppTheme.secondaryGreen, 0);
    _hill(canvas, w, h, h * 0.76, AppTheme.greenSoft, -0.08);

    // 小草丛点缀
    final grass = Paint()..color = AppTheme.secondaryGreen;
    for (final gx in [0.7, 0.82, 0.9]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(w * gx, h * 0.82), width: 6 * s, height: 12 * s), grass);
    }

    // 晒太阳的猫
    _cat(canvas, size, w * 0.5, h * 0.72, s, AppTheme.warmNeutral, AppTheme.primaryOrange, AppTheme.primaryOrangeDeep);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 冬日雪景：浅蓝天 + 雪丘 + 落雪 + 戴围巾的猫
class _WinterPainter extends CustomPainter {
  const _WinterPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final s = h / 150;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = AppTheme.blueSoft);
    canvas.drawCircle(Offset(w * 0.76, h * 0.28), w * 0.1, Paint()..color = Colors.white);
    _hill(canvas, w, h, h * 0.66, AppTheme.accentBlue, 0);
    _hill(canvas, w, h, h * 0.8, Colors.white, -0.06);

    // 落雪点
    final snow = Paint()..color = Colors.white;
    for (final p in [Offset(0.2, 0.3), Offset(0.4, 0.22), Offset(0.55, 0.4), Offset(0.3, 0.5), Offset(0.68, 0.55)]) {
      canvas.drawCircle(Offset(w * p.dx, h * p.dy), 3, snow);
    }

    // 戴围巾的猫
    _cat(canvas, size, w * 0.52, h * 0.74, s, AppTheme.warmNeutral, AppTheme.accentBlue, AppTheme.primaryOrangeDeep,
        scarf: AppTheme.accentBlue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
