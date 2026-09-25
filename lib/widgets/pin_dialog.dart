import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../widgets/common_widgets.dart';

/// 家长 PIN 码输入弹窗
///
/// **对应需求模块 3 的第 3 步：** 余额足够时弹出家长 PIN 码输入框，
/// 从本地读取哈希值验证。
///
/// **安全说明：** 纯本地单机 App，PIN 以 SHA-256 加盐哈希后存于 Hive。
/// 这个强度能防止孩子直接翻看明文，但挡不住 root 后读取文件——
/// 对儿童使用场景而言足够。
class PinInputDialog extends StatefulWidget {
  const PinInputDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onVerify,
    this.isSettingMode = false,
    this.confirmText = '确认',
  });

  /// 标题
  final String title;

  /// 副标题提示
  final String subtitle;

  /// 校验回调：返回 true 表示通过
  final bool Function(String pin) onVerify;

  /// 是否为「设置新 PIN」模式（需要二次确认输入）
  final bool isSettingMode;

  /// 确认按钮文案
  final String confirmText;

  @override
  State<PinInputDialog> createState() => _PinInputDialogState();
}

class _PinInputDialogState extends State<PinInputDialog> {
  /// 已输入的 PIN
  String _pin = '';

  /// 设置模式下第一次输入的值
  String? _firstPin;

  /// 错误提示
  String? _error;

  /// 最大位数
  static const int _maxLength = 4;

  void _onDigit(String digit) {
    if (_pin.length >= _maxLength) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    HapticFeedback.lightImpact();

    // 输入满 4 位自动提交
    if (_pin.length == _maxLength) {
      Future.delayed(const Duration(milliseconds: 180), _submit);
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  void _submit() {
    if (_pin.length < _maxLength) {
      setState(() => _error = '请输入 4 位密码');
      return;
    }

    if (widget.isSettingMode) {
      // 设置模式：第一次输入后要求二次确认
      if (_firstPin == null) {
        setState(() {
          _firstPin = _pin;
          _pin = '';
          _error = null;
        });
        return;
      }
      if (_firstPin != _pin) {
        setState(() {
          _error = '两次输入不一致，请重新设置';
          _firstPin = null;
          _pin = '';
        });
        return;
      }
      Navigator.pop(context, _pin);
      return;
    }

    // 校验模式
    if (widget.onVerify(_pin)) {
      Navigator.pop(context, true);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = '密码不正确，请重试';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmStage = widget.isSettingMode && _firstPin != null;

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSizes.spaceXl),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---------- 图标与标题 ----------
            const Text('🔐', style: TextStyle(fontSize: 44)),
            const SizedBox(height: AppSizes.spaceMd),
            Text(
              isConfirmStage ? '请再次输入确认' : widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppSizes.fontHeadline,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceSm),
            Text(
              isConfirmStage ? '确保家长记得住这个密码哦' : widget.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppSizes.fontCaption,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceXl),

            // ---------- PIN 圆点指示 ----------
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_maxLength, (i) {
                final filled = i < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSizes.spaceSm,
                  ),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: _error != null
                          ? AppColors.error
                          : AppColors.primaryLight,
                      width: 2.5,
                    ),
                  ),
                );
              }),
            ),

            // ---------- 错误提示 ----------
            if (_error != null) ...[
              const SizedBox(height: AppSizes.spaceMd),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: AppSizes.fontCaption,
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: AppSizes.spaceXl),

            // ---------- 数字键盘 ----------
            _buildKeypad(),

            const SizedBox(height: AppSizes.spaceMd),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }

  /// 自绘数字键盘（大按键，适合儿童场景下家长快速操作）
  Widget _buildKeypad() {
    return Column(
      children: [
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', 'del'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.spaceMd),
            child: Row(
              children: row.map((key) {
                if (key.isEmpty) {
                  return const Expanded(child: SizedBox(height: 56));
                }
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spaceXs,
                    ),
                    child: GestureDetector(
                      onTap: key == 'del' ? _onDelete : () => _onDigit(key),
                      child: Container(
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: key == 'del'
                              ? AppColors.surfaceVariant
                              : AppColors.surfaceVariant,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMd),
                        ),
                        child: key == 'del'
                            ? const Icon(
                                Icons.backspace_rounded,
                                color: AppColors.textSecondary,
                              )
                            : Text(
                                key,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

/// 「余额不足」的宠物卖萌拒绝提示
///
/// **对应需求模块 3 的第 2 步：**
/// 如果余额不足，**无需弹密码框**，直接让宠物弹出可爱拒绝提示。
class CoinNotEnoughDialog extends StatelessWidget {
  const CoinNotEnoughDialog({
    super.key,
    required this.dialogue,
    required this.shortfall,
    required this.coinEmoji,
  });

  /// 宠物台词
  final String dialogue;

  /// 还差多少币
  final int shortfall;

  /// 币种 Emoji
  final String coinEmoji;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🥺', style: TextStyle(fontSize: 56)),
            const SizedBox(height: AppSizes.spaceMd),
            Text(
              dialogue,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppSizes.fontBody,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSizes.spaceLg),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spaceLg,
                vertical: AppSizes.spaceSm,
              ),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
              ),
              child: Text(
                '还差 $coinEmoji $shortfall',
                style: const TextStyle(
                  fontSize: AppSizes.fontBody,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentDark,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.spaceXl),
            BouncyButton(
              onPressed: () => Navigator.pop(context),
              width: 200,
              child: const Text('好的，我再努力'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 兑换成功庆祝弹窗（撒花 + 宠物欢呼 + 仪式感）
class ExchangeSuccessDialog extends StatelessWidget {
  const ExchangeSuccessDialog({
    super.key,
    required this.itemName,
    required this.itemIcon,
    required this.dialogue,
  });

  final String itemName;
  final String itemIcon;
  final String dialogue;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 撒花装饰
            Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(width: 160, height: 100),
                const Positioned(
                  top: 0,
                  left: 10,
                  child: Text('🎊', style: TextStyle(fontSize: 28)),
                ),
                const Positioned(
                  top: 10,
                  right: 10,
                  child: Text('✨', style: TextStyle(fontSize: 24)),
                ),
                const Positioned(
                  bottom: 20,
                  left: 0,
                  child: Text('🎉', style: TextStyle(fontSize: 26)),
                ),
                const Positioned(
                  bottom: 10,
                  right: 0,
                  child: Text('⭐', style: TextStyle(fontSize: 22)),
                ),
                // 商品图标
                Container(
                  width: 90,
                  height: 90,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Text(itemIcon, style: const TextStyle(fontSize: 44)),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spaceMd),
            const Text(
              '兑换成功！',
              style: TextStyle(
                fontSize: AppSizes.fontTitle,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceSm),
            Text(
              itemName,
              style: const TextStyle(
                fontSize: AppSizes.fontBody,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: AppSizes.spaceLg),
            Text(
              dialogue,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppSizes.fontLabel,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceXl),
            BouncyButton(
              onPressed: () => Navigator.pop(context),
              width: 200,
              child: const Text('好耶！'),
            ),
          ],
        ),
      ),
    );
  }
}
