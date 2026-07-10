import 'package:flutter/material.dart';
import 'package:overtime/theme/app_theme.dart';

/// 通用卡片组件：统一圆角、阴影、内边距
class CommonCard extends StatelessWidget {
  const CommonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
    this.color = Colors.white,
    this.radius = AppTheme.cardRadius,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final BorderRadius radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
    if (onTap != null) {
      return InkWell(borderRadius: radius, onTap: onTap, child: card);
    }
    return card;
  }
}

/// 标签胶囊
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, this.color = AppTheme.secondaryGreen, this.textColor = AppTheme.textPrimary});

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppTheme.smallRadius,
      ),
      child: Text(label, style: AppTheme.tagText.copyWith(color: textColor)),
    );
  }
}

/// 主按钮（暖橙纯色，禁止渐变）
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppTheme.largeRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

/// 次要按钮（白底 + 浅灰边框）
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textSecondary,
          side: const BorderSide(color: AppTheme.divider),
          shape: RoundedRectangleBorder(borderRadius: AppTheme.largeRadius),
        ),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
