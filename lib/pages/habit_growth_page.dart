import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/habit_providers.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_sizes.dart';
import '../widgets/common_widgets.dart';

/// 习惯成长页（v1.4.0 新增）
///
/// **为什么单独做一页，而不是塞进乐园页？**
///
/// 乐园页的职责是「今天要做什么」（行动导向），成长页的职责是
/// 「我坚持了多久」（回顾导向）。两者节奏完全不同：前者要快、
/// 要一眼看到待办；后者要慢、要能翻看历史。
///
/// 混在一起会让乐园页越来越重，也会让「翻看成长」这件事变得
/// 有心理负担（毕竟打开就是一堆待办）。
///
/// **三个模块：**
/// 1. **热力图**：过去 12 周 × 7 天，一眼看出坚持的密度；
/// 2. **里程碑**：3/7/14/30/60/100 天节点，已达成的点亮；
/// 3. **养成度**：把所有习惯的坚持程度汇总成一个「养成进度」，
///    比单个连击更有整体成就感。
class HabitGrowthPage extends ConsumerWidget {
  const HabitGrowthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(activeChildProvider);

    if (child == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('习惯成长')),
        body: const EmptyPlaceholder(emoji: '🐣', text: '请先创建小朋友档案'),
      );
    }

    final habits = ref.watch(habitListProvider);
    final stats = _GrowthStats.compute(child.id, habits);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('习惯成长'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          children: [
            // ---------- 养成度总览 ----------
            _buildCultivationCard(stats),

            SizedBox(height: AppSizes.spaceLg),

            // ---------- 热力图 ----------
            _buildHeatmap(stats),

            SizedBox(height: AppSizes.spaceLg),

            // ---------- 里程碑 ----------
            _buildMilestones(stats),

            SizedBox(height: AppSizes.spaceXxl),
          ],
        ),
      ),
    );
  }

  /// 养成度总览卡
  Widget _buildCultivationCard(_GrowthStats stats) {
    final percent = (stats.cultivation * 100).round();
    final level = _levelLabel(stats.cultivation);

    return AppCard(
      padding: EdgeInsets.all(AppSizes.spaceXl),
      child: Column(
        children: [
          Text(
            '🌱 习惯养成度',
            style: TextStyle(
              fontSize: AppSizes.fontHeadline,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSizes.spaceLg),

          // 环形进度（用 stack + 圆环表示，避免引额外依赖）
          SizedBox(
            width: AppScale.s(140),
            height: AppScale.s(140),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: AppScale.s(140),
                  height: AppScale.s(140),
                  child: CircularProgressIndicator(
                    value: stats.cultivation,
                    strokeWidth: AppScale.s(12),
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: const AlwaysStoppedAnimation(
                      AppColors.primary,
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: AppScale.s(34),
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text(
                      level,
                      style: TextStyle(
                        fontSize: AppSizes.fontCaption,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: AppSizes.spaceLg),

          Text(
            stats.cultivationComment,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppSizes.fontBody,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),

          SizedBox(height: AppSizes.spaceLg),

          // 三个小统计
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  '累计打卡',
                  '${stats.totalCheckIns}',
                  '次',
                  AppColors.primary,
                ),
              ),
              Expanded(
                child: _miniStat(
                  '最长连击',
                  '${stats.bestStreak}',
                  '天',
                  AppColors.secondary,
                ),
              ),
              Expanded(
                child: _miniStat(
                  '活跃天数',
                  '${stats.activeDays}',
                  '天',
                  AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: AppScale.s(22),
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            SizedBox(width: 2),
            Text(
              unit,
              style: TextStyle(
                fontSize: AppSizes.fontTiny,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSizes.spaceXs),
        Text(
          label,
          style: TextStyle(
            fontSize: AppSizes.fontTiny,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// 12 周热力图
  ///
  /// 布局：横向 12 列（周）× 纵向 7 行（周一~周日）。
  /// 每格颜色深浅按当天的完成数量 —— 这是最直观的「坚持可视化」，
  /// 孩子会本能地想「把那片灰色填满」。
  Widget _buildHeatmap(_GrowthStats stats) {
    const weekCount = 12;
    final now = DateTime.now();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📆 坚持记录',
            style: TextStyle(
              fontSize: AppSizes.fontHeadline,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSizes.spaceXs),
          Text(
            '最近 12 周，颜色越深做得越多',
            style: TextStyle(
              fontSize: AppSizes.fontCaption,
              color: AppColors.textHint,
            ),
          ),
          SizedBox(height: AppSizes.spaceLg),

          // 热力图主体（用 Row/Column 手绘，避免额外依赖）
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(weekCount, (w) {
                // 从最早的一周开始
                final weeksAgo = weekCount - 1 - w;
                final weekStart = DateTime(
                  now.year,
                  now.month,
                  now.day,
                ).subtract(
                  Duration(days: (now.weekday - 1) + weeksAgo * 7),
                );

                return Column(
                  children: List.generate(7, (d) {
                    final day = weekStart.add(Duration(days: d));
                    if (day.isAfter(now)) {
                      return SizedBox(
                        width: AppScale.s(14),
                        height: AppScale.s(14),
                        child: SizedBox(
                          width: AppScale.s(12),
                          height: AppScale.s(12),
                        ),
                      );
                    }
                    final count = stats.dailyCounts[day] ?? 0;
                    final isToday = day.year == now.year &&
                        day.month == now.month &&
                        day.day == now.day;

                    return Container(
                      width: AppScale.s(12),
                      height: AppScale.s(12),
                      margin: EdgeInsets.all(AppScale.s(2)),
                      decoration: BoxDecoration(
                        color: _heatColor(count),
                        borderRadius: BorderRadius.circular(3),
                        border: isToday
                            ? Border.all(color: AppColors.primary, width: 1.5)
                            : null,
                      ),
                    );
                  }),
                );
              }),
            ),
          ),

          SizedBox(height: AppSizes.spaceMd),

          // 图例
          Row(
            children: [
              Text(
                '少',
                style: TextStyle(
                  fontSize: AppSizes.fontTiny,
                  color: AppColors.textHint,
                ),
              ),
              SizedBox(width: AppSizes.spaceSm),
              ...[0, 1, 2, 3].map(
                (n) => Container(
                  width: AppScale.s(12),
                  height: AppScale.s(12),
                  margin: EdgeInsets.only(right: AppScale.s(4)),
                  decoration: BoxDecoration(
                    color: _heatColor(n),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              SizedBox(width: AppSizes.spaceSm),
              Text(
                '多',
                style: TextStyle(
                  fontSize: AppSizes.fontTiny,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 热力格颜色：按当天完成数量分五档
  Color _heatColor(int count) {
    if (count <= 0) return AppColors.surfaceVariant;
    if (count == 1) return AppColors.primary.withValues(alpha: 0.28);
    if (count == 2) return AppColors.primary.withValues(alpha: 0.5);
    if (count == 3) return AppColors.primary.withValues(alpha: 0.72);
    return AppColors.primary;
  }

  /// 里程碑
  Widget _buildMilestones(_GrowthStats stats) {
    const milestones = [3, 7, 14, 30, 60, 100];
    final achieved = stats.bestStreak;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🏆 里程碑',
            style: TextStyle(
              fontSize: AppSizes.fontHeadline,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSizes.spaceLg),

          // 用 Wrap 而非 Row：窄屏上 6 个徽章一行放不下
          Wrap(
            spacing: AppSizes.spaceMd,
            runSpacing: AppSizes.spaceMd,
            children: milestones.map((m) {
              final done = achieved >= m;
              return SizedBox(
                width: AppScale.s(86),
                child: Column(
                  children: [
                    Container(
                      width: AppScale.s(56),
                      height: AppScale.s(56),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: done
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFFFFE08A),
                                  Color(0xFFF5B942),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: done ? null : AppColors.surfaceVariant,
                        boxShadow: done
                            ? [
                                BoxShadow(
                                  color: AppColors.accent
                                      .withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        done ? '🏅' : '🔒',
                        style: TextStyle(fontSize: AppScale.s(24)),
                      ),
                    ),
                    SizedBox(height: AppSizes.spaceSm),
                    Text(
                      '$m 天',
                      style: TextStyle(
                        fontSize: AppSizes.fontLabel,
                        fontWeight: FontWeight.w800,
                        color: done
                            ? AppColors.accentDark
                            : AppColors.textHint,
                      ),
                    ),
                    Text(
                      done ? '已达成' : '继续加油',
                      style: TextStyle(
                        fontSize: AppSizes.fontTiny,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 养成度 → 等级文案
  static String _levelLabel(double v) {
    if (v >= 0.9) return '习惯大师 💎';
    if (v >= 0.7) return '自律达人 🌟';
    if (v >= 0.5) return '稳步前行 🚀';
    if (v >= 0.25) return '正在起步 🌱';
    return '刚刚出发 🐾';
  }
}

/// 成长统计数据
class _GrowthStats {
  _GrowthStats({
    required this.totalCheckIns,
    required this.bestStreak,
    required this.activeDays,
    required this.dailyCounts,
    required this.cultivation,
  });

  /// 累计打卡次数（只算已通过的）
  final int totalCheckIns;

  /// 最长连击（所有习惯里最大的）
  final int bestStreak;

  /// 有打卡记录的天数
  final int activeDays;

  /// 每天完成次数（用于热力图）
  final Map<DateTime, int> dailyCounts;

  /// 养成度 0~1
  final double cultivation;

  /// 养成度评语
  String get cultivationComment {
    if (cultivation >= 0.9) {
      return '你的习惯已经像刷牙一样自然了，\n这种状态最难得！';
    }
    if (cultivation >= 0.7) {
      return '大部分日子都坚持下来了，\n你正在变成一个说到做到的人。';
    }
    if (cultivation >= 0.5) {
      return '已经过半啦！\n再稳一点点，习惯就长在身上了。';
    }
    if (cultivation >= 0.25) {
      return '好的开始！\n前 3 周最难，撑过去就轻松了。';
    }
    return '刚出发没关系，\n每天做一件最小的事，就算成功。';
  }

  /// 计算成长数据
  ///
  /// **养成度怎么算？** 不是简单除以天数，而是综合三个因子：
  ///
  /// ```
  /// 养成度 = 打卡密度 × 0.6 + 连击因子 × 0.25 + 广度因子 × 0.15
  /// ```
  ///
  /// - **打卡密度**：过去 30 天里，有完成记录的天数占比（最重要）；
  /// - **连击因子**：最长连击 / 21（21 天是习惯养成的经典门槛）；
  /// - **广度因子**：同时坚持 3 个以上习惯的加成。
  ///
  /// 这样设计的好处：**单点突破和全面开花都能得分**，
  /// 避免「只有连续 100 天才有成就感」的挫败感。
  static _GrowthStats compute(String childId, List<Habit> habits) {
    final db = DatabaseService.instance;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ---------- 收集过去 12 周每天的完成数 ----------
    final dailyCounts = <DateTime, int>{};
    var totalCheckIns = 0;
    var activeDays = 0;

    for (int i = 0; i < 84; i++) {
      final day = today.subtract(Duration(days: i));
      // 只统计「已通过」的打卡
      final count = db.getCheckedHabitIdsOn(childId, day).length;
      if (count > 0) {
        dailyCounts[day] = count;
        totalCheckIns += count;
        activeDays++;
      }
    }

    // ---------- 最长连击 ----------
    var bestStreak = 0;
    for (final h in habits) {
      if (h.currentStreakDays > bestStreak) bestStreak = h.currentStreakDays;
      if (h.bestStreakDays > bestStreak) bestStreak = h.bestStreakDays;
    }

    // ---------- 养成度 ----------
    // 1. 打卡密度：近 30 天活跃占比
    var active30 = 0;
    for (int i = 0; i < 30; i++) {
      final day = today.subtract(Duration(days: i));
      if ((dailyCounts[day] ?? 0) > 0) active30++;
    }
    final density = active30 / 30;

    // 2. 连击因子：21 天封顶
    final streakFactor = (bestStreak / 21).clamp(0.0, 1.0);

    // 3. 广度因子：近 7 天有记录的活跃习惯占比
    var activeHabits = 0;
    for (final h in habits) {
      for (int i = 0; i < 7; i++) {
        final day = today.subtract(Duration(days: i));
        final ids = db.getCheckedHabitIdsOn(childId, day);
        if (ids.contains(h.id)) {
          activeHabits++;
          break;
        }
      }
    }
    final breadth =
        habits.isEmpty ? 0.0 : (activeHabits / habits.length).clamp(0.0, 1.0);

    final cultivation =
        (density * 0.6 + streakFactor * 0.25 + breadth * 0.15)
            .clamp(0.0, 1.0);

    return _GrowthStats(
      totalCheckIns: totalCheckIns,
      bestStreak: bestStreak,
      activeDays: activeDays,
      dailyCounts: dailyCounts,
      cultivation: cultivation,
    );
  }
}
