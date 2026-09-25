import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../routes/app_router.dart';
import '../providers/core_providers.dart';
import '../providers/habit_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../widgets/common_widgets.dart';
import 'habit_edit_page.dart';

/// 习惯游乐园页面
///
/// **对应截图 3：**
/// - 顶部插画区（小屋 / 摩天轮 / 双宠物）+ 右侧数据面板
///   （获得奖励 / 连击天数 🔥 / 连击奖励）
/// - 星星进度条 + 小怪兽举旗（1/1）
/// - 「漫游驿站 · 全天可打卡」时段分组标题
/// - 习惯卡：图标 + 名称 + 奖励 + 7 格打卡格 + 星星牌时间 + 勾选框
class HabitParkPage extends ConsumerWidget {
  const HabitParkPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(activeChildProvider);

    if (child == null) {
      return const SafeArea(
        child: EmptyPlaceholder(
          emoji: '🐣',
          text: '还没有小朋友档案',
          hint: '请先在首页创建档案',
        ),
      );
    }

    final grouped = ref.watch(habitsByTimeSlotProvider);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          // ---------- 顶部标题栏 ----------
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spaceLg,
                vertical: AppSizes.spaceMd,
              ),
              child: Row(
                children: [
                  const Icon(Icons.map_rounded, size: 24, color: AppColors.primaryDark),
                  const Spacer(),
                  const Text(
                    '习惯游乐园',
                    style: TextStyle(
                      fontSize: AppSizes.fontTitle,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _openCreate(context, ref),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.secondaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: AppColors.secondaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---------- 顶部插画 + 数据面板 ----------
          SliverToBoxAdapter(child: _buildHeaderCard()),

          const SliverToBoxAdapter(child: SizedBox(height: AppSizes.spaceLg)),

          // ---------- 星星进度条 ----------
          SliverToBoxAdapter(child: _buildStarProgress()),

          const SliverToBoxAdapter(child: SizedBox(height: AppSizes.spaceXl)),

          // ---------- 习惯列表（按时段分组） ----------
          if (grouped.isEmpty)
            SliverToBoxAdapter(
              child: EmptyPlaceholder(
                emoji: '🎠',
                text: '还没有习惯哦',
                hint: '点击右上角 + 从习惯库挑选一个吧',
                action: BouncyButton(
                  onPressed: () => _openCreate(context, ref),
                  width: 200,
                  child: const Text('添加习惯'),
                ),
              ),
            )
          else
            ...grouped.entries.expand((entry) => [
                  SliverToBoxAdapter(
                    child: _buildStationHeader(entry.key),
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      children: entry.value
                          .map((h) => Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSizes.spaceLg,
                                  0,
                                  AppSizes.spaceLg,
                                  AppSizes.spaceMd,
                                ),
                                child: HabitCard(
                                  habit: h,
                                  onCheckIn: () => _checkIn(context, ref, h),
                                  onTap: () => _openEdit(context, h),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ]),

          const SliverToBoxAdapter(
            child: SizedBox(height: AppSizes.bottomNavHeight + 40),
          ),
        ],
      ),
    );
  }

  /// 顶部卡片：左侧插画区 + 右侧数据面板
  Widget _buildHeaderCard() {
    return Consumer(
      builder: (context, ref, _) {
        final summary = ref.watch(todayHabitSummaryProvider);
        final now = DateTime.now();
        const weekdays = ['一', '二', '三', '四', '五', '六', '日'];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceLg),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                // ---------- 左侧：场景插画占位 ----------
                SizedBox(
                  width: 150,
                  height: 150,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppSizes.cardRadius),
                      bottomLeft: Radius.circular(AppSizes.cardRadius),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppColors.primaryGradient,
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 星空点缀
                          for (int i = 0; i < 12; i++)
                            Positioned(
                              top: (i * 37 % 130).toDouble(),
                              left: (i * 53 % 140).toDouble(),
                              child: Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  color: Colors.white70,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          // 摩天轮简化图形
                          Icon(
                            Icons.attractions_rounded,
                            size: 52,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          // 双宠物
                          const Positioned(
                            bottom: 16,
                            child: Row(
                              children: [
                                Text('🦄', style: TextStyle(fontSize: 30)),
                                SizedBox(width: AppSizes.spaceXs),
                                Text('🐳', style: TextStyle(fontSize: 34)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ---------- 右侧：数据面板 ----------
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.spaceMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${now.month}月${now.day}日 周${weekdays[now.weekday - 1]}',
                          style: const TextStyle(
                            fontSize: AppSizes.fontBody,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSizes.spaceXs),
                        // 装饰波浪线
                        Row(
                          children: List.generate(
                            8,
                            (i) => Container(
                              margin: const EdgeInsets.only(right: 3),
                              width: 8,
                              height: 2,
                              color: AppColors.secondaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSizes.spaceMd),

                        _headerLine(
                          '获得奖励：',
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('💛', style: TextStyle(fontSize: 16)),
                              Text(
                                '+${summary.rewardGained}',
                                style: const TextStyle(
                                  fontSize: AppSizes.fontLabel,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accentDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSizes.spaceXs),
                        _headerLine(
                          '连击天数：',
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${summary.maxStreak}天',
                                style: const TextStyle(
                                  fontSize: AppSizes.fontLabel,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.secondary,
                                ),
                              ),
                              const Text(' 🔥',
                                  style: TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSizes.spaceXs),
                        _headerLine(
                          '连击奖励：',
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🪙', style: TextStyle(fontSize: 16)),
                              Text(
                                '+${summary.streakRewardGained}',
                                style: const TextStyle(
                                  fontSize: AppSizes.fontLabel,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.secondaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _headerLine(String label, Widget value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: AppSizes.fontCaption,
            color: AppColors.textSecondary,
          ),
        ),
        value,
      ],
    );
  }

  /// 星星进度条（对应截图：⭐×11 + 小怪兽举旗 + 1/1）
  Widget _buildStarProgress() {
    return Consumer(
      builder: (context, ref, _) {
        final summary = ref.watch(todayHabitSummaryProvider);
        final total = summary.totalCount == 0 ? 11 : summary.totalCount;
        final done = summary.checkedCount;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceLg),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.spaceMd,
                    vertical: AppSizes.spaceSm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
                  ),
                  child: Row(
                    children: [
                      for (int i = 0; i < total && i < 12; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Text(
                            i < done ? '⭐' : '☆',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.spaceSm),
              Text(
                '🐳',
                style: TextStyle(fontSize: done > 0 ? 26 : 22),
              ),
              const SizedBox(width: AppSizes.spaceSm),
              Text(
                summary.progressLabel,
                style: const TextStyle(
                  fontSize: AppSizes.fontBody,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 时段分组标题（对应截图：「漫游驿站 · 全天可打卡」）
  Widget _buildStationHeader(TimeSlot slot) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.spaceLg,
        0,
        AppSizes.spaceLg,
        AppSizes.spaceSm,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spaceLg,
              vertical: AppSizes.spaceSm,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF5EDD8),
              borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
              border: Border.all(color: const Color(0xFFD9C9A8), width: 1.5),
            ),
            child: Row(
              children: [
                const Text('🏕️', style: TextStyle(fontSize: 18)),
                const SizedBox(width: AppSizes.spaceSm),
                const Text(
                  '漫游驿站',
                  style: TextStyle(
                    fontSize: AppSizes.fontBody,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF8B7355),
                  ),
                ),
                const SizedBox(width: AppSizes.spaceSm),
                TagChip(
                  text: '${slot.label}可打卡',
                  color: const Color(0xFFE8DCC0),
                  textColor: const Color(0xFF8B7355),
                  fontSize: AppSizes.fontTiny,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 交互 ====================

  /// 习惯打卡
  Future<void> _checkIn(BuildContext context, WidgetRef ref, Habit habit) async {
    final reward = await ref.read(habitControllerProvider).checkIn(habit);
    if (!context.mounted) return;

    if (reward > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '打卡成功！获得 ${habit.checkInRewardType.emoji} $reward',
            style: const TextStyle(
              fontSize: AppSizes.fontBody,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '今天已经打满啦，明天继续哦～',
            style: TextStyle(
              fontSize: AppSizes.fontBody,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppColors.info,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
      );
    }
  }

  void _openCreate(BuildContext context, WidgetRef ref) {
    AppNavigator.push(context, const HabitEditPage());
  }

  void _openEdit(BuildContext context, Habit habit) {
    AppNavigator.push(context, HabitEditPage(habit: habit));
  }
}

/// 习惯卡片 —— 对应截图中的单个习惯行
///
/// 布局：图标 + 名称 + 奖励 ×10 + 7 格打卡格 + 星星牌时间 + 勾选框
class HabitCard extends ConsumerWidget {
  const HabitCard({
    super.key,
    required this.habit,
    required this.onCheckIn,
    this.onTap,
  });

  final Habit habit;
  final VoidCallback onCheckIn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkedIds = ref.watch(checkedHabitIdsProvider);
    final isCheckedToday = checkedIds.contains(habit.id);
    final weekStatus = ref.watch(habitControllerProvider).weekStatus(habit);
    final checkInTime = ref.watch(habitControllerProvider).todayCheckInTime(habit);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSizes.spaceMd),
      child: Row(
        children: [
          // ---------- 习惯图标 ----------
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _categoryColor(habit.category).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: habit.iconAsset != null
                ? Image.asset(
                    habit.iconAsset!,
                    width: 40,
                    height: 40,
                    errorBuilder: (_, __, ___) => Text(
                      habit.iconEmoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  )
                : Text(habit.iconEmoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: AppSizes.spaceMd),

          // ---------- 名称 + 奖励 + 周视图 ----------
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        habit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppSizes.fontHeadline,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.spaceSm),
                    // 奖励
                    Text(
                      habit.checkInRewardType.emoji,
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      '×${habit.checkInRewardValue}',
                      style: const TextStyle(
                        fontSize: AppSizes.fontCaption,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentDark,
                      ),
                    ),
                    // 连击火苗
                    if (habit.currentStreakDays > 0) ...[
                      const SizedBox(width: AppSizes.spaceSm),
                      Text(
                        '🔥${habit.currentStreakDays}',
                        style: const TextStyle(
                          fontSize: AppSizes.fontCaption,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSizes.spaceSm),

                // 7 格周打卡视图
                Row(
                  children: List.generate(7, (i) {
                    // 最后一个是今天
                    final isToday = i == 6;
                    final done = i < weekStatus.length && weekStatus[i];
                    return Container(
                      margin: const EdgeInsets.only(right: 5),
                      width: 26,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: done
                            ? AppColors.secondary
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                        border: isToday
                            ? Border.all(color: AppColors.primary, width: 1.5)
                            : null,
                      ),
                      child: done
                          ? const Icon(Icons.check_rounded,
                              size: 14, color: Colors.white)
                          : null,
                    );
                  }),
                ),
              ],
            ),
          ),

          const SizedBox(width: AppSizes.spaceSm),

          // ---------- 星星牌：显示打卡时间 ----------
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCheckedToday
                  ? AppColors.accent.withValues(alpha: 0.25)
                  : AppColors.surfaceVariant,
              shape: BoxShape.circle,
              border: Border.all(
                color: isCheckedToday ? AppColors.accentDark : AppColors.divider,
                width: 2,
              ),
            ),
            child: Text(
              checkInTime != null
                  ? '${checkInTime.hour.toString().padLeft(2, '0')}:'
                      '${checkInTime.minute.toString().padLeft(2, '0')}'
                  : '⭐',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: checkInTime != null ? 11 : 20,
                fontWeight: FontWeight.w700,
                color: isCheckedToday
                    ? AppColors.accentDark
                    : AppColors.textHint,
              ),
            ),
          ),

          const SizedBox(width: AppSizes.spaceSm),

          // ---------- 打卡勾选框 ----------
          GestureDetector(
            onTap: onCheckIn,
            child: AnimatedContainer(
              duration: AppSizes.durationFast,
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isCheckedToday
                    ? AppColors.secondary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                border: Border.all(
                  color: isCheckedToday
                      ? AppColors.secondary
                      : AppColors.secondaryLight,
                  width: 2.5,
                ),
              ),
              child: isCheckedToday
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 24)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(HabitCategory category) => switch (category) {
        HabitCategory.study => AppColors.primary,
        HabitCategory.health => AppColors.success,
        HabitCategory.life => AppColors.warning,
        HabitCategory.interest => AppColors.secondary,
      };
}
