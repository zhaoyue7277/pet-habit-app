import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/pet_providers.dart';
import '../providers/settings_providers.dart';
import '../providers/pomodoro_providers.dart';
import '../services/white_noise_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../widgets/common_widgets.dart';
import '../widgets/pet_avatar.dart';

/// 番茄钟页面
///
/// **对应需求模块 2：**
/// - 倒计时居中显示
/// - 下方白噪音开关（雨声、海浪、森林等）
/// - 防作弊：切出 App 超过 5 分钟作废本次计时，不发奖励
/// - 结束发放宠物币与经验，弹出宠物欢呼动画
class PomodoroPage extends ConsumerStatefulWidget {
  const PomodoroPage({super.key, required this.task});

  final Task task;

  @override
  ConsumerState<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends ConsumerState<PomodoroPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _celebrateController;
  final WhiteNoiseService _whiteNoise = WhiteNoiseService.instance;

  /// 作废提示是否已展示（防止重复弹窗）
  bool _abortHandled = false;

  @override
  void initState() {
    super.initState();
    _celebrateController = AnimationController(
      vsync: this,
      duration: AppSizes.durationCelebrate,
    );

    // 注册作废回调（宠物垂头丧气动画）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pomodoroProvider.notifier).addAbandonListener(_onAbandoned);
      _whiteNoise.init();
      _startSession();
    });
  }

  @override
  void dispose() {
    ref.read(pomodoroProvider.notifier).removeAbandonListener(_onAbandoned);
    _whiteNoise.stop();
    _celebrateController.dispose();
    super.dispose();
  }

  /// 开始本次番茄钟会话
  void _startSession() {
    final settings = ref.read(settingsProvider);
    final minutes = widget.task.estimatedMinutes ?? settings.defaultPomodoroMinutes;

    ref.read(pomodoroProvider.notifier).start(
          task: widget.task,
          minutes: minutes,
        );

    // 若开启了自动播放白噪音
    if (settings.autoStartWhiteNoise && settings.selectedWhiteNoiseIndex != null) {
      final type = WhiteNoiseType.values[settings.selectedWhiteNoiseIndex!];
      _whiteNoise.play(type);
    }
  }

  /// 番茄钟被作废（切出超时）—— 弹出宠物委屈提示
  void _onAbandoned() {
    if (!mounted || _abortHandled) return;
    _abortHandled = true;

    _whiteNoise.stop();

    final dialogue = ref.read(pomodoroProvider.notifier).abortDialogue();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AbandonDialog(
        dialogue: dialogue,
        pet: ref.read(activePetProvider),
        onConfirm: () {
          Navigator.pop(ctx);
          Navigator.pop(context); // 退出番茄钟页
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pomodoroProvider);

    // 监听状态变化：完成时播放庆祝动画
    ref.listen<PomodoroState>(pomodoroProvider, (prev, next) {
      if (prev?.status != next.status) {
        if (next.status == PomodoroStatus.finished) {
          _celebrateController.forward(from: 0);
          _whiteNoise.stop();
          _showFinishDialog();
        } else if (next.status == PomodoroStatus.aborted) {
          _onAbandoned();
        } else if (next.status == PomodoroStatus.paused) {
          // 切出或手动暂停：白噪音同步暂停（对应约束 6-A）
          _whiteNoise.pause();
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
          onPressed: _confirmExit,
        ),
        title: Text(
          state.taskTitle.isEmpty ? '专注时间' : state.taskTitle,
          style: TextStyle(
            fontSize: AppSizes.fontHeadline,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          // 状态指示
          Padding(
            padding: EdgeInsets.only(right: AppSizes.spaceLg),
            child: Center(
              child: TagChip(
                text: state.status.label,
                color: _statusColor(state.status),
                textColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // ---------- 居中倒计时 ----------
            _buildTimer(state),

            SizedBox(height: AppSizes.spaceXl),

            // ---------- 宠物陪伴 ----------
            _buildPetCompanion(state),

            const Spacer(),

            // ---------- 白噪音控制 ----------
            _buildWhiteNoisePanel(state),

            SizedBox(height: AppSizes.spaceXl),

            // ---------- 操作按钮 ----------
            _buildControls(state),

            SizedBox(height: AppSizes.spaceXxl),
          ],
        ),
      ),
    );
  }

  /// 倒计时显示区
  Widget _buildTimer(PomodoroState state) {
    return Column(
      children: [
        // 环形进度 + 居中数字
        SizedBox(
          width: 260,
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 背景圆环
              const SizedBox(
                width: 260,
                height: 260,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 16,
                  backgroundColor: Colors.transparent,
                  valueColor:
                      AlwaysStoppedAnimation(AppColors.surfaceVariant),
                ),
              ),
              // 进度圆环
              SizedBox(
                width: 260,
                height: 260,
                child: AnimatedBuilder(
                  animation: _celebrateController,
                  builder: (context, _) {
                    return CircularProgressIndicator(
                      value: state.progress,
                      strokeWidth: 16,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation(
                        state.status == PomodoroStatus.paused
                            ? AppColors.textHint
                            : AppColors.primary,
                      ),
                    );
                  },
                ),
              ),
              // 居中时间文字
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.remainingLabel,
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      color: state.status == PomodoroStatus.paused
                          ? AppColors.textHint
                          : AppColors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  SizedBox(height: AppSizes.spaceSm),
                  Text(
                    '共 ${state.planMinutes} 分钟',
                    style: TextStyle(
                      fontSize: AppSizes.fontLabel,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (state.status == PomodoroStatus.paused) ...[
                    SizedBox(height: AppSizes.spaceSm),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSizes.spaceMd,
                        vertical: AppSizes.spaceXs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.2),
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusCircle),
                      ),
                      child: Text(
                        '⏸ 已暂停（切出 App 会暂停计时）',
                        style: TextStyle(
                          fontSize: AppSizes.fontCaption,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 宠物陪伴区
  Widget _buildPetCompanion(PomodoroState state) {
    final live = ref.watch(petLiveStateProvider);
    final isCelebrating = _celebrateController.isAnimating;

    return Column(
      children: [
        PetAvatar(
          pet: live?.pet,
          size: 110,
          moodState: isCelebrating
              ? PetMoodState.excited
              : (state.status == PomodoroStatus.paused
                  ? PetMoodState.sleepy
                  : PetMoodState.happy),
          isJumping: isCelebrating,
          showGlow: isCelebrating,
        ),
        SizedBox(height: AppSizes.spaceSm),
        Text(
          isCelebrating
              ? '太棒了！你做到了 🎉'
              : state.status == PomodoroStatus.paused
                  ? '我在等你回来哦～'
                  : '我会一直陪着你专注 ✨',
          style: TextStyle(
            fontSize: AppSizes.fontLabel,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// 白噪音控制面板
  Widget _buildWhiteNoisePanel(PomodoroState state) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.spaceLg),
      child: AppCard(
        child: Column(
          children: [
            Row(
              children: [
                const Text('🎵', style: TextStyle(fontSize: 20)),
                SizedBox(width: AppSizes.spaceSm),
                Text(
                  '白噪音',
                  style: TextStyle(
                    fontSize: AppSizes.fontBody,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                // 静音提示（音频文件缺失时）
                if (!_whiteNoise.assetsAvailable)
                  Text(
                    '音频未放入',
                    style: TextStyle(
                      fontSize: AppSizes.fontTiny,
                      color: AppColors.textHint,
                    ),
                  ),
              ],
            ),
            SizedBox(height: AppSizes.spaceMd),

            // 音效选择按钮
            Wrap(
              spacing: AppSizes.spaceSm,
              runSpacing: AppSizes.spaceSm,
              children: WhiteNoiseType.values.map((type) {
                final selected = state.whiteNoiseType == type;
                return GestureDetector(
                  onTap: () => _toggleWhiteNoise(type),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.spaceLg,
                      vertical: AppSizes.spaceSm,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusCircle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(type.emoji,
                            style: const TextStyle(fontSize: 16)),
                        SizedBox(width: AppSizes.spaceXs),
                        Text(
                          type.label,
                          style: TextStyle(
                            fontSize: AppSizes.fontLabel,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 底部操作按钮
  Widget _buildControls(PomodoroState state) {
    final isRunning = state.status == PomodoroStatus.running;
    final isPaused = state.status == PomodoroStatus.paused;

    if (state.status == PomodoroStatus.finished ||
        state.status == PomodoroStatus.aborted) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSizes.spaceLg),
        child: BouncyButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('返回首页'),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.spaceLg),
      child: Row(
        children: [
          // 放弃按钮
          Expanded(
            child: BouncyButton(
              onPressed: _confirmGiveUp,
              color: AppColors.textHint,
              child: const Text('放弃'),
            ),
          ),
          SizedBox(width: AppSizes.spaceLg),

          // 暂停 / 继续
          Expanded(
            flex: 2,
            child: BouncyButton(
              onPressed: () {
                if (isRunning) {
                  ref.read(pomodoroProvider.notifier).pause();
                  _whiteNoise.pause();
                } else if (isPaused) {
                  ref.read(pomodoroProvider.notifier).resume();
                  if (state.whiteNoiseType != null) {
                    _whiteNoise.resume();
                  }
                }
              },
              child: Text(isRunning ? '暂停' : '继续'),
            ),
          ),
        ],
      ),
    );
  }

  /// 切换白噪音
  Future<void> _toggleWhiteNoise(WhiteNoiseType type) async {
    final state = ref.read(pomodoroProvider);
    if (!state.isActive) return;

    final wasSelected = state.whiteNoiseType == type;
    ref.read(pomodoroProvider.notifier).toggleWhiteNoise(type);

    if (wasSelected) {
      await _whiteNoise.stop();
    } else {
      await _whiteNoise.play(type);
    }
  }

  /// 退出确认
  void _confirmExit() {
    final state = ref.read(pomodoroProvider);
    if (!state.isActive) {
      Navigator.pop(context);
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认退出？'),
        content: const Text('退出后本次专注将作废，不会获得奖励哦～'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('继续专注'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(pomodoroProvider.notifier).giveUp();
              _whiteNoise.stop();
              Navigator.pop(context);
            },
            child: const Text('退出', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  /// 放弃确认
  void _confirmGiveUp() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('要放弃吗？'),
        content: const Text('放弃后本次不计入学习时长，也没有奖励哦～'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('再坚持一下'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(pomodoroProvider.notifier).giveUp();
              _whiteNoise.stop();
            },
            child: const Text('放弃', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  /// 完成庆祝弹窗（撒花 + 宠物欢呼）
  void _showFinishDialog() {
    final live = ref.watch(petLiveStateProvider);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CelebrateDialog(
        rewardCoin: _lastReward,
        expGained: _lastExp,
        dialogue: live?.dialogue ?? '你太棒啦！',
        pet: live?.pet,
        onConfirm: () {
          Navigator.pop(ctx);
          ref.read(pomodoroProvider.notifier).reset();
          Navigator.pop(context);
        },
      ),
    );
  }

  final int _lastReward = 0;
  final int _lastExp = 0;

  Color _statusColor(PomodoroStatus status) => switch (status) {
        PomodoroStatus.idle => AppColors.textHint,
        PomodoroStatus.running => AppColors.success,
        PomodoroStatus.paused => AppColors.warning,
        PomodoroStatus.finished => AppColors.primary,
        PomodoroStatus.aborted => AppColors.error,
      };
}

/// 完成庆祝弹窗 —— 撒花 + 宠物欢呼
class _CelebrateDialog extends StatefulWidget {
  const _CelebrateDialog({
    required this.rewardCoin,
    required this.expGained,
    required this.dialogue,
    required this.pet,
    required this.onConfirm,
  });

  final int rewardCoin;
  final int expGained;
  final String dialogue;
  final Pet? pet;
  final VoidCallback onConfirm;

  @override
  State<_CelebrateDialog> createState() => _CelebrateDialogState();
}

class _CelebrateDialogState extends State<_CelebrateDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 撒花动画
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiController,
                builder: (context, _) => CustomPaint(
                  painter: _ConfettiPainter(_confettiController.value),
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(AppSizes.spaceXl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 48)),
                SizedBox(height: AppSizes.spaceMd),
                Text(
                  '专注完成！',
                  style: TextStyle(
                    fontSize: AppSizes.fontTitle,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: AppSizes.spaceLg),

                // 宠物欢呼
                PetAvatar(
                  pet: widget.pet,
                  size: 100,
                  moodState: PetMoodState.excited,
                  isJumping: true,
                  showGlow: true,
                ),
                SizedBox(height: AppSizes.spaceMd),

                Text(
                  widget.dialogue,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppSizes.fontLabel,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: AppSizes.spaceLg),

                // 奖励展示
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CoinLabel(
                      type: RewardType.petCoin,
                      amount: widget.rewardCoin,
                      showPlus: true,
                    ),
                    SizedBox(width: AppSizes.spaceLg),
                    Text(
                      '⭐ +${widget.expGained} 经验',
                      style: TextStyle(
                        fontSize: AppSizes.fontBody,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryDark,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSizes.spaceXl),

                BouncyButton(
                  onPressed: widget.onConfirm,
                  width: 200,
                  child: const Text('太棒啦！'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 撒花粒子动画
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.progress);

  final double progress;

  static const List<Color> _colors = [
    AppColors.secondary, // 珊瑚橙
    AppColors.primary,   // 晴空蓝
    AppColors.accent,    // 暖阳黄
    AppColors.success,   // 绿
    AppColors.info,      // 蓝
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1.0) return;

    final paint = Paint();
    // 24 个粒子从中心向外扩散
    for (int i = 0; i < 24; i++) {
      final angle = (i / 24) * math.pi * 2;
      final distance = progress * size.width * 0.55;
      final x = size.width / 2 + math.cos(angle) * distance;
      final y = size.height / 2 + math.sin(angle) * distance;

      paint.color = _colors[i % _colors.length]
          .withValues(alpha: (1 - progress).clamp(0.0, 1.0));

      // 旋转的小方块
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * 6 + i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: 8,
            height: 12,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// 作废提示弹窗 —— 宠物垂头丧气
class _AbandonDialog extends StatelessWidget {
  const _AbandonDialog({
    required this.dialogue,
    required this.pet,
    required this.onConfirm,
  });

  final String dialogue;
  final Pet? pet;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: EdgeInsets.all(AppSizes.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 宠物垂头丧气（sad 状态 + 无跳跃，视觉上更低沉）
            PetAvatar(
              pet: pet,
              size: 110,
              moodState: PetMoodState.sad,
            ),
            SizedBox(height: AppSizes.spaceMd),
            Text(
              '本次任务失败',
              style: TextStyle(
                fontSize: AppSizes.fontHeadline,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppSizes.spaceMd),
            Text(
              dialogue,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSizes.fontBody,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            SizedBox(height: AppSizes.spaceSm),
            Text(
              '（离开 App 太久，本次不计入学习时长）',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSizes.fontCaption,
                color: AppColors.textHint,
              ),
            ),
            SizedBox(height: AppSizes.spaceXl),
            BouncyButton(
              onPressed: onConfirm,
              width: 200,
              child: const Text('下次一定专心'),
            ),
          ],
        ),
      ),
    );
  }
}
