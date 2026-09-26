import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import 'common_widgets.dart';

/// 任务卡片 —— 对应截图首页的待办任务卡
///
/// 布局还原：
/// - 左上角科目标签（橙色块，「语文」「英语」）
/// - 标题 + 优先级罗马数字 + 难度标签 + 喇叭图标
/// - 右上角显示预估时长（「25分钟」）
/// - 左下角奖励币（💛 ×15）
/// - 右下角按钮：计时类显示实时走秒（「06:14」），检查类显示「完成」
class TaskCard extends ConsumerStatefulWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onComplete,
    this.onStartTimer,
  });

  final Task task;

  /// 点击卡片（编辑任务）
  final VoidCallback? onTap;

  /// 检查类任务：一键完成回调
  final Future<void> Function(Task task)? onComplete;

  /// 计时类任务：进入番茄钟回调
  final VoidCallback? onStartTimer;

  @override
  ConsumerState<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<TaskCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.isRunning != widget.task.isRunning) {
      _syncTicker();
    }
  }

  /// 任务进行中时启动每秒刷新（对应截图：右下角实时走秒）
  void _syncTicker() {
    _ticker?.cancel();
    if (!widget.task.isRunning) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// 计算当前已用时长文案
  String get _durationLabel {
    final t = widget.task;
    if (t.isRunning && t.startedAt != null) {
      final elapsed = DateTime.now().difference(t.startedAt!).inSeconds;
      return _fmt(elapsed);
    }
    return _fmt(t.usedSeconds);
  }

  String _fmt(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final done = t.isDone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          onTap: widget.onTap,
          showShadow: true,
          child: Opacity(
            opacity: done ? 0.55 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- 第一行：标题 + 标签 + 时长 ----------
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 标题（完成后加删除线）
                    Flexible(
                      child: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppSizes.fontHeadline,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSizes.spaceSm),

                    // 优先级罗马数字
                    _priorityBadge(t.priority),
                    SizedBox(width: AppSizes.spaceSm),

                    // 难度标签
                    TagChip(
                      text: t.difficulty.label,
                      color: _difficultyColor(t.difficulty),
                      textColor: Colors.white,
                      fontSize: AppSizes.fontTiny,
                    ),
                    SizedBox(width: AppSizes.spaceSm),

                    // 重复任务喇叭图标（对应截图）
                    if (t.repeatFrequency != RepeatFrequency.once)
                      const Icon(
                        Icons.volume_up_rounded,
                        size: 18,
                        color: AppColors.textHint,
                      ),

                    const Spacer(),

                    // 预估时长
                    if (t.estimatedMinutes != null)
                      Text(
                        '${t.estimatedMinutes}分钟',
                        style: TextStyle(
                          fontSize: AppSizes.fontCaption,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),

                SizedBox(height: AppSizes.spaceLg),

                // ---------- 第二行：奖励 + 操作按钮 ----------
                Row(
                  children: [
                    // 奖励币
                    CoinLabel(
                      type: t.rewardType,
                      amount: t.rewardValue,
                    ),

                    // 已完成标记
                    if (done) ...[
                      SizedBox(width: AppSizes.spaceMd),
                      Text('✅ 已完成',
                          style: TextStyle(
                            fontSize: AppSizes.fontCaption,
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                          )),
                    ],

                    const Spacer(),

                    // 操作区
                    if (!done) _buildAction(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 右侧操作区：计时类显示走秒按钮，检查类显示完成按钮
  Widget _buildAction() {
    final t = widget.task;

    if (t.needsPomodoro) {
      // ---------- 计时类：显示已用时长 / 开始计时 ----------
      if (t.isRunning) {
        return GestureDetector(
          onTap: widget.onStartTimer,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSizes.spaceLg,
              vertical: AppSizes.spaceSm,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.primaryGradient,
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
            ),
            child: Text(
              _durationLabel,
              style: TextStyle(
                fontSize: AppSizes.fontBody,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        );
      }
      return GestureDetector(
        onTap: widget.onStartTimer,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.spaceLg,
            vertical: AppSizes.spaceSm,
          ),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
          ),
          child: Row(
            children: [
              Icon(Icons.play_arrow_rounded,
                  size: 20, color: AppColors.primaryDark),
              SizedBox(width: AppSizes.spaceXs),
              Text(
                '开始专注',
                style: TextStyle(
                  fontSize: AppSizes.fontLabel,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ---------- 检查类：直接勾选完成 ----------
    return GestureDetector(
      onTap: () => widget.onComplete?.call(t),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.success, width: 2),
        ),
        child: Icon(
          Icons.check_rounded,
          color: AppColors.success,
          size: AppSizes.iconMd,
        ),
      ),
    );
  }

  /// 优先级徽章（罗马数字）
  Widget _priorityBadge(Priority p) {
    final color = switch (p) {
      Priority.must => AppColors.secondary,
      Priority.should => AppColors.secondaryDark,
      Priority.could => AppColors.info,
    };
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Text(
        p.romanNumeral,
        style: TextStyle(
          fontSize: AppSizes.fontTiny,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  Color _difficultyColor(Difficulty d) => switch (d) {
        Difficulty.easy => AppColors.success,
        Difficulty.medium => AppColors.accentDark,
        Difficulty.hard => AppColors.error,
      };
}
