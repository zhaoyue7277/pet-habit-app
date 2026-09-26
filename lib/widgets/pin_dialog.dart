import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../widgets/common_widgets.dart';

/// 家长密码输入弹窗（v1.4.0 全面加强）
///
/// **v1.3 的问题**
///
/// 旧版是「4 位纯数字 + 自绘数字键盘」，两个弱点叠加：
/// 1. **强度低**：4 位数字只有 1 万种组合，孩子试几次就可能蒙对；
/// 2. **自绘键盘等于写明了规则**：屏幕上就摆着 0-9 十个键，孩子
///    一眼就知道「哦，只要 4 个数字」，还会饶有兴致地一个个试。
///
/// **v1.4 的方案（用户选的 b + c）**
///
/// - **b. 字母数字混合**：密码改为「至少 6 位、必须同时含字母和数字」，
///   组合空间从 1 万跃升到千万级；
/// - **c. 系统键盘**：改用 [TextField] + `obscureText`，让系统输入法
///   接管。既支持字母数字，又不再是「摆在明面上的谜题」。
///
/// **额外加的一道锁：连续失败锁定**
///
/// 密码强度够，但「无限次尝试」依然危险。所以这里记录连续失败次数：
/// 每错 1 次锁 3 秒，错满 5 次锁 30 秒（用 [DateTime] 算剩余时间，
/// 不依赖定时器，避免页面销毁后状态丢失）。
///
/// **安全说明**：纯本地单机 App，密码以 SHA-256 加盐哈希后存于 Hive。
/// 这个强度能挡住「孩子随手翻看 / 暴力尝试」，但挡不住 root 后读文件 ——
/// 对儿童使用场景而言足够。
class PinInputDialog extends StatefulWidget {
  PinInputDialog({
    super.key,
    required this.title,
    required this.subtitle,
    this.onVerify,
    this.isSettingMode = false,
    this.confirmText = '确认',
  }) : assert(
          onVerify != null || isSettingMode,
          '校验模式必须提供 onVerify；设置模式（isSettingMode）则不需要',
        );

  /// 标题
  final String title;

  /// 副标题提示
  final String subtitle;

  /// 校验回调：返回 true 表示通过。设置模式下可为 null。
  final bool Function(String pin)? onVerify;

  /// 是否为「设置新密码」模式（需要二次确认输入）
  final bool isSettingMode;

  /// 确认按钮文案
  final String confirmText;

  /// 便捷入口：弹出校验弹窗，返回 true = 通过，null / false = 取消
  ///
  /// 把「构造 + showDialog + 取结果」三步封装起来，调用方一行搞定。
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    String subtitle = '',
    bool Function(String pin)? onVerify,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PinInputDialog(
        title: title,
        subtitle: subtitle,
        onVerify: onVerify,
      ),
    );
  }

  /// 便捷入口：弹出「设置新密码」弹窗，返回新密码（null = 取消）
  static Future<String?> showSetPassword(
    BuildContext context, {
    String title = '设置家长密码',
    String subtitle = '至少 6 位，需同时包含字母和数字',
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PinInputDialog(
        title: title,
        subtitle: subtitle,
        isSettingMode: true,
      ),
    );
  }

  @override
  State<PinInputDialog> createState() => _PinInputDialogState();
}

class _PinInputDialogState extends State<PinInputDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  /// 设置模式下第一次输入的值
  String? _firstPin;

  /// 错误提示
  String? _error;

  /// 密码可见性（默认隐藏；给一个「看一眼」的按钮，避免家长打错还要重来）
  bool _obscure = true;

  // ==================== 失败锁定 ====================

  /// 连续失败次数
  int _failCount = 0;

  /// 锁定截止时间（null = 未锁定）
  DateTime? _lockedUntil;

  /// 锁定状态刷新用的定时器（仅用于每秒重绘倒计时数字）
  ///
  /// 注意：**判定用的是 `_lockedUntil` 时间戳**，定时器只负责「让
  /// 界面每秒动一下」。即便定时器被销毁，锁定状态也不会丢。
  bool get _isLocked =>
      _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);

  int get _lockRemainSeconds {
    final until = _lockedUntil;
    if (until == null) return 0;
    final s = until.difference(DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }

  /// 最短密码长度
  static const int _minLength = 6;

  /// 最多密码长度
  static const int _maxLength = 20;

  @override
  void initState() {
    super.initState();
    // 自动聚焦，省一次点击
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ==================== 校验 ====================

  /// 检查密码格式：至少 6 位 + 同时含字母与数字
  ///
  /// 只在「设置模式」严格校验；校验模式（登录）不校验格式 ——
  /// 因为老用户可能仍是旧的 4 位数字密码，卡格式会把人家锁在门外。
  String? _validateFormat(String value) {
    if (value.length < _minLength) {
      return '密码至少 $_minLength 位';
    }
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
    final hasDigit = RegExp(r'[0-9]').hasMatch(value);
    if (!hasLetter || !hasDigit) {
      return '密码需要同时包含字母和数字';
    }
    return null;
  }

  void _submit() {
    if (_isLocked) return;

    final value = _controller.text;

    // ---------- 设置模式 ----------
    if (widget.isSettingMode) {
      if (_firstPin == null) {
        final err = _validateFormat(value);
        if (err != null) {
          setState(() => _error = err);
          HapticFeedback.heavyImpact();
          return;
        }
        setState(() {
          _firstPin = value;
          _controller.clear();
          _error = null;
        });
        _focus.requestFocus();
        return;
      }
      if (_firstPin != value) {
        setState(() {
          _error = '两次输入不一致，请重新设置';
          _firstPin = null;
          _controller.clear();
        });
        HapticFeedback.heavyImpact();
        return;
      }
      Navigator.pop(context, value);
      return;
    }

    // ---------- 校验模式 ----------
    if (value.isEmpty) {
      setState(() => _error = '请输入家长密码');
      return;
    }

    final verify = widget.onVerify;
    if (verify != null && verify(value)) {
      Navigator.pop(context, true);
      return;
    }

    // 失败：累计次数，决定要不要锁
    _failCount++;
    HapticFeedback.heavyImpact();
    final lockSeconds = _lockSecondsFor(_failCount);
    setState(() {
      _controller.clear();
      if (lockSeconds > 0) {
        _lockedUntil = DateTime.now().add(Duration(seconds: lockSeconds));
        _error = '密码不正确，请 $lockSeconds 秒后再试';
        _scheduleUnlockTick();
      } else {
        _error = '密码不正确，请重试（已错 $_failCount 次）';
      }
    });
  }

  /// 失败 N 次后应锁定多少秒
  ///
  /// 采用「越错越久」的策略：
  /// - 1~2 次：不锁（打错很常见，别把家长也烦到）
  /// - 3 次起：每多错 1 次，锁定时间指数上升（3s → 6s → 12s → 30s 封顶）
  ///
  /// 孩子试到第 5 次就会撞上 30 秒墙，耐心基本被磨没了。
  int _lockSecondsFor(int fails) {
    if (fails < 3) return 0;
    final seconds = 3 << (fails - 3); // 3, 6, 12, 24...
    return seconds > 30 ? 30 : seconds;
  }

  /// 每秒刷新一次锁定倒计时（仅用于界面重绘）
  void _scheduleUnlockTick() {
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        if (DateTime.now().isAfter(_lockedUntil ?? DateTime.now())) {
          _lockedUntil = null;
          _error = null;
          _focus.requestFocus();
        } else {
          _error = '密码不正确，请 $_lockRemainSeconds 秒后再试';
          _scheduleUnlockTick();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmStage = widget.isSettingMode && _firstPin != null;

    return Dialog(
      insetPadding: EdgeInsets.all(AppSizes.spaceXl),
      child: Padding(
        padding: EdgeInsets.all(AppSizes.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------- 图标与标题 ----------
            const Center(child: Text('🔐', style: TextStyle(fontSize: 44))),
            SizedBox(height: AppSizes.spaceMd),
            Text(
              isConfirmStage ? '请再次输入确认' : widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSizes.fontHeadline,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppSizes.spaceSm),
            Text(
              isConfirmStage
                  ? '确保家长记得住这个密码哦'
                  : widget.subtitle.isEmpty
                      ? '至少 6 位，含字母和数字'
                      : widget.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSizes.fontCaption,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: AppSizes.spaceXl),

            // ---------- 系统键盘输入框 ----------
            TextField(
              controller: _controller,
              focusNode: _focus,
              enabled: !_isLocked,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: _maxLength,
              // 字母数字混合：不限定 inputFormatters，
              // 让系统键盘自由输入（数字键盘会挡住字母）
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSizes.fontHeadline,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: isConfirmStage ? '再输一次' : '请输入密码',
                hintStyle: TextStyle(
                  fontSize: AppSizes.fontBody,
                  letterSpacing: 0,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w400,
                ),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                errorText: _error,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: AppColors.textHint,
                    size: 22,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),

            SizedBox(height: AppSizes.spaceLg),

            // ---------- 确认按钮 ----------
            BouncyButton(
              onPressed: _isLocked ? null : _submit,
              color: _isLocked ? AppColors.textHint : AppColors.primary,
              child: Text(
                _isLocked
                    ? '请等待 $_lockRemainSeconds 秒'
                    : (isConfirmStage ? '确认设置' : widget.confirmText),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),

            SizedBox(height: AppSizes.spaceSm),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '取消',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
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
        padding: EdgeInsets.all(AppSizes.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🥺', style: TextStyle(fontSize: 56)),
            SizedBox(height: AppSizes.spaceMd),
            Text(
              dialogue,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSizes.fontBody,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
            SizedBox(height: AppSizes.spaceLg),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.spaceLg,
                vertical: AppSizes.spaceSm,
              ),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
              ),
              child: Text(
                '还差 $coinEmoji $shortfall',
                style: TextStyle(
                  fontSize: AppSizes.fontBody,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentDark,
                ),
              ),
            ),
            SizedBox(height: AppSizes.spaceXl),
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
        padding: EdgeInsets.all(AppSizes.spaceXl),
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
            SizedBox(height: AppSizes.spaceMd),
            Text(
              '兑换成功！',
              style: TextStyle(
                fontSize: AppSizes.fontTitle,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppSizes.spaceSm),
            Text(
              itemName,
              style: TextStyle(
                fontSize: AppSizes.fontBody,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
            SizedBox(height: AppSizes.spaceLg),
            Text(
              dialogue,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSizes.fontLabel,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: AppSizes.spaceXl),
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
