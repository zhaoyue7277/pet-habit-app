import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../routes/app_router.dart';
import '../providers/core_providers.dart';
import '../providers/habit_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_sizes.dart';
import '../widgets/common_widgets.dart';
import 'habit_edit_page.dart';
import 'habit_growth_page.dart';
import 'recording_page.dart';

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
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.spaceLg,
                vertical: AppSizes.spaceMd,
              ),
              child: Row(
                children: [
                  const Icon(Icons.map_rounded, size: 24, color: AppColors.primaryDark),
                  const Spacer(),
                  Text(
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

          // ---------- v1.4.0 待验收提示条 ----------
          // 有记录处于「待验收」或「刚被驳回」时，给孩子一个明确的
          // 状态反馈。没有这条横幅的话，孩子提交完会疑惑
          // 「怎么没加币？是不是坏了？」—— 反而会去重复点击。
          SliverToBoxAdapter(child: _buildVerifyBanner(context, ref)),

          SliverToBoxAdapter(child: SizedBox(height: AppSizes.spaceLg)),

          // ---------- 星星进度条 ----------
          SliverToBoxAdapter(child: _buildStarProgress()),

          SliverToBoxAdapter(child: SizedBox(height: AppSizes.spaceXl)),

          // ---------- 习惯列表（按时段分组） ----------
          if (grouped.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                // 底部额外留白：避开中央 FAB 与底部导航栏
                padding: EdgeInsets.only(
                  bottom: AppSizes.bottomNavHeight + 56,
                ),
                child: EmptyPlaceholder(
                  emoji: '🎠',
                  text: '还没有习惯哦',
                  hint: '点右上角「+」挑一个习惯吧',
                  action: BouncyButton(
                    onPressed: () => _openCreate(context, ref),
                    width: 200,
                    child: const Text('添加习惯'),
                  ),
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
                                padding: EdgeInsets.fromLTRB(
                                  AppSizes.spaceLg,
                                  0,
                                  AppSizes.spaceLg,
                                  AppSizes.spaceMd,
                                ),
                                child: HabitCard(
                                  habit: h,
                                  onCheckIn: () => _checkIn(context, ref, h),
                                  onTap: () => _openEdit(context, h),
                                  onRecord: _isReadingHabit(h)
                                      ? () => _openRecording(context, h)
                                      : null,
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ]),

          SliverToBoxAdapter(
            child: SizedBox(height: AppSizes.bottomNavHeight + 40),
          ),
        ],
      ),
    );
  }

  /// 顶部卡片：左侧插画区 + 右侧数据面板
  /// 待验收提示条（v1.4.0）
  ///
  /// 两种情况才显示：
  /// 1. 有记录处于「待验收」→ 主色条 + ⏳，告诉孩子「在等了」；
  /// 2. 有记录刚被「已驳回」→ 橙色条 + 驳回原因，告诉孩子「可以补交」。
  ///
  /// 都没有时返回零尺寸（不占布局）。
  Widget _buildVerifyBanner(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingHabitIdsProvider);
    final rejected = ref.watch(rejectedCheckInsTodayProvider);

    if (pending.isEmpty && rejected.isEmpty) {
      return const SizedBox.shrink();
    }

    // 驳回优先显示（更需要孩子注意）
    final showReject = rejected.isNotEmpty;
    final count = showReject ? rejected.length : pending.length;
    final reason = showReject && rejected.first.rejectReason != null
        ? '：「${rejected.first.rejectReason}」'
        : '';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.spaceLg,
        AppSizes.spaceLg,
        AppSizes.spaceLg,
        0,
      ),
      child: Container(
        padding: EdgeInsets.all(AppSizes.spaceMd),
        decoration: BoxDecoration(
          color: showReject
              ? AppColors.warning.withValues(alpha: 0.15)
              : AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: showReject
                ? AppColors.warning.withValues(alpha: 0.5)
                : AppColors.primary.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              showReject ? '↩️' : '⏳',
              style: TextStyle(fontSize: AppScale.s(20)),
            ),
            SizedBox(width: AppSizes.spaceSm),
            Expanded(
              child: Text(
                showReject
                    ? '$count 个打卡被退回来了$reason\n补做一遍就能重新提交，我陪你一起～'
                    : '$count 个打卡正在等爸爸妈妈确认\n确认后奖励就会到账哦～',
                style: TextStyle(
                  fontSize: AppSizes.fontCaption,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: showReject
                      ? AppColors.secondaryDark
                      : AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Consumer(
      builder: (context, ref, _) {
        final summary = ref.watch(todayHabitSummaryProvider);
        final now = DateTime.now();
        const weekdays = ['一', '二', '三', '四', '五', '六', '日'];

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.spaceLg),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                // ---------- 左侧：场景插画占位 ----------
                SizedBox(
                  width: 150,
                  height: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
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
                          Positioned(
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
                    padding: EdgeInsets.all(AppSizes.spaceMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${now.month}月${now.day}日 周${weekdays[now.weekday - 1]}',
                          style: TextStyle(
                            fontSize: AppSizes.fontBody,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: AppSizes.spaceXs),
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
                        SizedBox(height: AppSizes.spaceMd),

                        _headerLine(
                          '获得奖励：',
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('💛', style: TextStyle(fontSize: 16)),
                              Text(
                                '+${summary.rewardGained}',
                                style: TextStyle(
                                  fontSize: AppSizes.fontLabel,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accentDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: AppSizes.spaceXs),
                        _headerLine(
                          '连击天数：',
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${summary.maxStreak}天',
                                style: TextStyle(
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
                        SizedBox(height: AppSizes.spaceXs),
                        _headerLine(
                          '连击奖励：',
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🪙', style: TextStyle(fontSize: 16)),
                              Text(
                                '+${summary.streakRewardGained}',
                                style: TextStyle(
                                  fontSize: AppSizes.fontLabel,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.secondaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: AppSizes.spaceSm),

                        // ---------- v1.4.0：习惯成长入口 ----------
                        // 放在数据面板底部：因为用户看完「连击天数」后，
                        // 最自然的下一步就是「想看看更长期的整体表现」。
                        GestureDetector(
                          onTap: () => AppNavigator.push(
                            context,
                            const HabitGrowthPage(),
                          ),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSizes.spaceSm,
                              vertical: AppSizes.spaceXs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusCircle,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '🌱',
                                  style: TextStyle(fontSize: AppScale.s(14)),
                                ),
                                SizedBox(width: AppSizes.spaceXs),
                                Text(
                                  '看成长',
                                  style: TextStyle(
                                    fontSize: AppSizes.fontTiny,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: AppScale.s(14),
                                  color: AppColors.primaryDark,
                                ),
                              ],
                            ),
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
          style: TextStyle(
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
          padding: EdgeInsets.symmetric(horizontal: AppSizes.spaceLg),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(
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
              SizedBox(width: AppSizes.spaceSm),
              Text(
                '🐳',
                style: TextStyle(fontSize: done > 0 ? 26 : 22),
              ),
              SizedBox(width: AppSizes.spaceSm),
              Text(
                summary.progressLabel,
                style: TextStyle(
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
      padding: EdgeInsets.fromLTRB(
        AppSizes.spaceLg,
        0,
        AppSizes.spaceLg,
        AppSizes.spaceSm,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
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
                SizedBox(width: AppSizes.spaceSm),
                Text(
                  '漫游驿站',
                  style: TextStyle(
                    fontSize: AppSizes.fontBody,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF8B7355),
                  ),
                ),
                SizedBox(width: AppSizes.spaceSm),
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

  /// 习惯打卡（v1.4.0：提交后进入「待验收」）
  ///
  /// **改动说明**：以前点一下立即发奖励、立即显示完成。现在改为
  /// 「提交 → 等家长确认」。这里只负责提交 + 给出明确反馈，
  /// 奖励发放发生在家长的验收队列里。
  Future<void> _checkIn(BuildContext context, WidgetRef ref, Habit habit) async {
    // 已有记录时区分「待验收」和「已通过」，给出不同提示
    final controller = ref.read(habitControllerProvider);
    final existing = controller.todayRecord(habit);

    if (existing != null && existing.isApproved) {
      _toast(context, '今天这个习惯已经通过啦，明天继续哦～', AppColors.info);
      return;
    }

    await controller.checkIn(habit);
    if (!context.mounted) return;

    final isResubmit = existing != null && existing.isRejected;
    _toast(
      context,
      isResubmit
          ? '已重新提交，等爸爸妈妈确认💪'
          : '提交成功！等爸爸妈妈确认后就能拿到奖励啦～',
      AppColors.primary,
    );
  }

  /// 统一的轻提示
  void _toast(BuildContext context, String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: TextStyle(
            fontSize: AppSizes.fontBody,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
    );
  }

  void _openCreate(BuildContext context, WidgetRef ref) {
    AppNavigator.push(context, const HabitEditPage());
  }

  void _openEdit(BuildContext context, Habit habit) {
    AppNavigator.push(context, HabitEditPage(habit: habit));
  }

  /// 是否为「朗读 / 口语」类习惯（显示麦克风入口）
  ///
  /// 判定基于习惯名称关键词 + 图标，覆盖内置模板（早读、讲故事、朗读、
  /// 背单词、英语口语…）以及用户自建时常用的表述。
  static const List<String> _readingKeywords = [
    '朗读', '早读', '读', '背诵', '背诵', '口', '说', '讲', '故事', '英语',
    '读绘本', '阅读', '唐诗', '古诗', '课文',
  ];

  bool _isReadingHabit(Habit habit) {
    final text = '${habit.name}${habit.iconEmoji}';
    return _readingKeywords.any(text.contains);
  }

  /// 进入朗读打卡（录音完成后自动完成该习惯的当日打卡）
  void _openRecording(BuildContext context, Habit habit) {
    AppNavigator.push(context, RecordingPage(habit: habit));
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
    this.onRecord,
  });

  final Habit habit;
  final VoidCallback onCheckIn;
  final VoidCallback? onTap;

  /// 朗读打卡入口（仅朗读/口语相关习惯会传入）
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkedIds = ref.watch(checkedHabitIdsProvider);
    final pendingIds = ref.watch(pendingHabitIdsProvider);
    final isCheckedToday = checkedIds.contains(habit.id);
    final isPendingToday = pendingIds.contains(habit.id);
    final weekStatus = ref.watch(habitControllerProvider).weekStatus(habit);
    final record = ref.watch(habitControllerProvider).todayRecord(habit);
    final isRejectedToday = record?.isRejected ?? false;
    final checkInTime = ref.watch(habitControllerProvider).todayCheckInTime(habit);

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.all(AppSizes.spaceMd),
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
          SizedBox(width: AppSizes.spaceMd),

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
                        style: TextStyle(
                          fontSize: AppSizes.fontHeadline,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSizes.spaceSm),
                    // 奖励
                    Text(
                      habit.checkInRewardType.emoji,
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      '×${habit.checkInRewardValue}',
                      style: TextStyle(
                        fontSize: AppSizes.fontCaption,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentDark,
                      ),
                    ),
                    // 连击火苗
                    if (habit.currentStreakDays > 0) ...[
                      SizedBox(width: AppSizes.spaceSm),
                      Text(
                        '🔥${habit.currentStreakDays}',
                        style: TextStyle(
                          fontSize: AppSizes.fontCaption,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: AppSizes.spaceSm),

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

          SizedBox(width: AppSizes.spaceSm),

          // ---------- 星星牌：显示打卡时间 / 验收状态 ----------
          //
          // 三种状态用不同底色 + 图标区分（v1.4.0）：
          //   · 已通过 → 金色底 + 打卡时间
          //   · 待验收 → 主色淡底 + ⏳
          //   · 已驳回 → 橙色淡底 + ↩️（提示可补交）
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCheckedToday
                  ? AppColors.accent.withValues(alpha: 0.25)
                  : isPendingToday
                      ? AppColors.primary.withValues(alpha: 0.16)
                      : isRejectedToday
                          ? AppColors.secondary.withValues(alpha: 0.16)
                          : AppColors.surfaceVariant,
              shape: BoxShape.circle,
              border: Border.all(
                color: isCheckedToday
                    ? AppColors.accentDark
                    : isPendingToday
                        ? AppColors.primary
                        : isRejectedToday
                            ? AppColors.secondary
                            : AppColors.divider,
                width: 2,
              ),
            ),
            child: Text(
              checkInTime != null
                  ? '${checkInTime.hour.toString().padLeft(2, '0')}:'
                      '${checkInTime.minute.toString().padLeft(2, '0')}'
                  : isPendingToday
                      ? '⏳'
                      : isRejectedToday
                          ? '↩️'
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

          SizedBox(width: AppSizes.spaceSm),

          // ---------- 朗读打卡入口（仅朗读/口语类习惯） ----------
          if (onRecord != null) ...[
            GestureDetector(
              onTap: onRecord,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  size: 22,
                  color: AppColors.success,
                ),
              ),
            ),
            SizedBox(width: AppSizes.spaceSm),
          ],

          // ---------- 打卡勾选框 ----------
          //
          // 四态（v1.4.0）：
          //   · 已通过   → 实心勾
          //   · 待验收   → 主色感叹号（点了也没用，已提交）
          //   · 已驳回   → 可再次点击补交（虚线框 + ↩️）
          //   · 未打卡   → 空心框
          GestureDetector(
            onTap: isPendingToday ? null : onCheckIn,
            child: AnimatedContainer(
              duration: AppSizes.durationFast,
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isCheckedToday
                    ? AppColors.secondary
                    : isPendingToday
                        ? AppColors.primary.withValues(alpha: 0.18)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                border: Border.all(
                  color: isCheckedToday
                      ? AppColors.secondary
                      : isPendingToday
                          ? AppColors.primary
                          : isRejectedToday
                              ? AppColors.secondary
                              : AppColors.secondaryLight,
                  width: 2.5,
                ),
              ),
              child: isCheckedToday
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 24)
                  : isPendingToday
                      ? const Icon(Icons.hourglass_top_rounded,
                          color: AppColors.primary, size: 22)
                      : isRejectedToday
                          ? const Icon(Icons.refresh_rounded,
                              color: AppColors.secondary, size: 22)
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
