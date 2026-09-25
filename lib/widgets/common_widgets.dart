import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';

/// 金币 / 宠物币标签
///
/// 对应截图：任务卡上的「💛 ×15」、首页的「💛+0 🪙+0」。
class CoinLabel extends StatelessWidget {
  const CoinLabel({
    super.key,
    required this.type,
    required this.amount,
    this.showPlus = false,
    this.fontSize = AppSizes.fontBody,
  });

  final RewardType type;
  final int amount;

  /// 是否显示 + 号（用于展示「获得」而非「持有」）
  final bool showPlus;

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final (emoji, color) = _styleOf(type);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: TextStyle(fontSize: fontSize)),
        const SizedBox(width: AppSizes.spaceXs),
        Text(
          '${showPlus && amount > 0 ? '+' : ''}$amount',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  static (String, Color) _styleOf(RewardType type) {
    switch (type) {
      case RewardType.wishCoin:
        return ('💛', AppColors.accentDark);
      case RewardType.petCoin:
        return ('🪙', AppColors.secondaryDark);
      case RewardType.custom:
        return ('🎁', AppColors.primary);
    }
  }
}

/// 通用圆角卡片
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSizes.spaceLg),
    this.color,
    this.onTap,
    this.radius = AppSizes.cardRadius,
    this.showShadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  final double radius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showShadow ? AppShadows.card : null,
      ),
      child: child,
    );

    if (onTap == null) return content;

    // 点击时轻微缩放，给儿童明显的交互反馈
    return _BouncyTap(onTap: onTap!, child: content);
  }
}

/// 有弹性缩放反馈的点击包装
class _BouncyTap extends StatefulWidget {
  const _BouncyTap({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<_BouncyTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppSizes.durationFast,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: () {
        HapticFeedback.lightImpact(); // 触觉反馈
        widget.onTap();
      },
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// 大号点击按钮（带缩放 + 触觉反馈）
class BouncyButton extends StatefulWidget {
  const BouncyButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.color,
    this.height = AppSizes.buttonHeight,
    this.width,
    this.radius = AppSizes.radiusCircle,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Color? color;
  final double height;
  final double? width;
  final double radius;

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppSizes.durationFast,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => _controller.forward() : null,
      onTapUp: enabled ? (_) => _controller.reverse() : null,
      onTapCancel: enabled ? () => _controller.reverse() : null,
      onTap: enabled
          ? () {
              HapticFeedback.mediumImpact();
              widget.onPressed!();
            }
          : null,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: widget.width,
          height: widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // v2：同色系渐变（替代 v1 的「主色→辅色」跨色渐变，避免蓝橙混色发灰）
            gradient: enabled
                ? LinearGradient(
                    colors: widget.color != null
                        ? [
                            widget.color!,
                            Color.lerp(widget.color!, Colors.black, 0.16) ??
                                widget.color!,
                          ]
                        : AppColors.primaryGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: enabled ? null : AppColors.divider,
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: enabled ? AppShadows.button : null,
          ),
          // 注意：这里必须显式 merge 主题字体。
          // DefaultTextStyle 若给出一个全新 TextStyle，其 fontFamily 为 null，
          // 不会自动继承 ThemeData.fontFamily。在 Web 平台上 fontFamily 为 null
          // 会触发 Flutter 去 fonts.gstatic.com 下载字体（国内不可达 → 文字空白），
          // 而不会回退到我们在 pubspec 中声明的 NotoSansSC。
          // 因此统一用 DefaultTextStyle.of(context).style.merge(...) 保留字体族。
          child: DefaultTextStyle(
            style: DefaultTextStyle.of(context).style.merge(
              TextStyle(
                fontSize: AppSizes.fontBody,
                fontWeight: FontWeight.w700,
                color: enabled ? AppColors.textOnPrimary : AppColors.textHint,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// 标题小标签（对应截图：任务卡上的「语文」「简单」标签）
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.text,
    this.color,
    this.textColor,
    this.fontSize = AppSizes.fontCaption,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSizes.spaceMd,
      vertical: AppSizes.spaceXs,
    ),
  });

  final String text;
  final Color? color;
  final Color? textColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: textColor ?? AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// 科目标签（对应截图：任务分组标题的橙色色块）
class SubjectTag extends StatelessWidget {
  const SubjectTag({super.key, required this.subject});

  final String subject;

  /// 科目配色表（按名称哈希稳定取色，保证同一科目颜色一致）
  ///
  /// v2：统一为设计令牌中的语义色，全部为中深色，保证白色文字对比度达标。
  static const List<Color> _palette = [
    AppColors.secondary, // 珊瑚橙
    AppColors.accentDark, // 深金
    AppColors.primary, // 晴空蓝
    AppColors.info, // 浅蓝
    AppColors.success, // 绿
    AppColors.petSleepy, // 淡紫
  ];

  Color get _color => _palette[subject.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spaceLg,
        vertical: AppSizes.spaceSm,
      ),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppSizes.radiusMd),
          topRight: Radius.circular(AppSizes.radiusMd),
        ),
      ),
      child: Text(
        subject,
        style: const TextStyle(
          fontSize: AppSizes.fontLabel,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// 通用进度条（圆角、加粗、带光泽）
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 14,
    this.color,
    this.backgroundColor,
    this.trailing,
  });

  /// 0.0 - 1.0
  final double value;
  final double height;
  final Color? color;
  final Color? backgroundColor;

  /// 进度条右侧的附加内容（对应截图：气球图标）
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (trailing != null) ...[
          trailing!,
          const SizedBox(width: AppSizes.spaceSm),
        ],
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
            child: Stack(
              children: [
                Container(
                  height: height,
                  color: backgroundColor ?? AppColors.surfaceVariant,
                ),
                AnimatedFractionallySizedBox(
                  duration: AppSizes.durationNormal,
                  curve: Curves.easeOutCubic,
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color ?? AppColors.accent,
                          Color.lerp(
                                color ?? AppColors.accent,
                                AppColors.warning,
                                0.4,
                              ) ??
                              AppColors.accent,
                        ],
                      ),
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusCircle),
                    ),
                  ),
                ),
                // 顶部高光，营造立体感
                Positioned(
                  top: 1,
                  left: 4,
                  right: 4,
                  child: Container(
                    height: height * 0.25,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 空状态占位
class EmptyPlaceholder extends StatelessWidget {
  const EmptyPlaceholder({
    super.key,
    required this.emoji,
    required this.text,
    this.hint,
    this.action,
  });

  final String emoji;
  final String text;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: AppSizes.spaceLg),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppSizes.fontBody,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: AppSizes.spaceSm),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppSizes.fontCaption,
                  color: AppColors.textHint,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSizes.spaceXl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
