import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/habit_providers.dart';
import '../providers/task_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import 'common_widgets.dart';

/// 顶部问候栏 —— 「凌晨好，乐乐 ∨」+ 右侧图标
///
/// 对应截图：左上角问候语 + 下拉箭头（多孩切换），右上角两个功能图标。
class HomeGreetingBar extends ConsumerWidget {
  const HomeGreetingBar({
    super.key,
    required this.onChildTap,
    required this.onCalendarTap,
    required this.onPetTap,
  });

  /// 点击孩子名（触发多孩切换）
  final VoidCallback onChildTap;

  /// 点击日历图标
  final VoidCallback onCalendarTap;

  /// 点击宠物图标
  final VoidCallback onPetTap;

  /// 根据当前时间生成问候语
  ///
  /// 对应截图：「凌晨好，乐乐」（截图时间为 00:07）。
  static String greetingOf(DateTime now) {
    final h = now.hour;
    if (h < 5) return '凌晨好';
    if (h < 9) return '早上好';
    if (h < 12) return '上午好';
    if (h < 14) return '中午好';
    if (h < 18) return '下午好';
    if (h < 23) return '晚上好';
    return '夜深了';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(activeChildProvider);
    final greeting = greetingOf(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spaceLg,
        vertical: AppSizes.spaceMd,
      ),
      child: Row(
        children: [
          // ---------- 问候语 + 孩子名（可点击切换） ----------
          Expanded(
            child: GestureDetector(
              onTap: onChildTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      '$greeting，${child?.name ?? '小朋友'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppSizes.fontTitle,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.spaceSm),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: AppSizes.iconMd,
                  ),
                ],
              ),
            ),
          ),

          // ---------- 日历图标（v2：矢量图标替代 emoji） ----------
          _IconButton(
            icon: Icons.calendar_month_rounded,
            onTap: onCalendarTap,
          ),
          const SizedBox(width: AppSizes.spaceMd),

          // ---------- 宠物图标（跳宠物中心） ----------
          _IconButton(
            icon: Icons.pets_rounded,
            onTap: onPetTap,
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          boxShadow: AppShadows.card,
        ),
        child: Icon(
          icon,
          size: 22,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

/// 一周日期条 —— 显示本周 7 天与打卡标记
///
/// 设计系统 v2：今天改为**主色实心圆角块 + 白字**（替代 v1 的白底 + 粉边框 + 粉字，
/// 后者在浅色背景上对比度不足），其余日子为浅底灰字，层级一眼可辨。
class WeekDateBar extends ConsumerWidget {
  const WeekDateBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    // 计算本周一
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final checkedIds = ref.watch(checkedHabitIdsProvider);
    final tasks = ref.watch(todayTasksProvider);

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceLg),
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: AppSizes.spaceSm),
        itemBuilder: (context, index) {
          final day = monday.add(Duration(days: index));
          final isToday = day.day == today.day &&
              day.month == today.month &&
              day.year == today.year;
          // 有任务或有打卡的日子显示小圆点
          final hasActivity = checkedIds.isNotEmpty
              ? true
              : tasks.any((t) => t.isDone);
          return _DateCell(
            day: day,
            isToday: isToday,
            hasActivity: hasActivity && !day.isAfter(today),
          );
        },
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.day,
    required this.isToday,
    required this.hasActivity,
  });

  final DateTime day;
  final bool isToday;
  final bool hasActivity;

  static const List<String> _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final label = _weekdayLabels[day.weekday - 1];

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppSizes.fontCaption,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
            color: isToday ? AppColors.primaryDark : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSizes.spaceXs),
        Container(
          width: 48,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // v2：今天 = 主色实心块，辨识度更高
            color: isToday ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            boxShadow: isToday ? AppShadows.card : null,
          ),
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontSize: AppSizes.fontBody,
              fontWeight: FontWeight.w700,
              color: isToday ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.spaceXs),
        // 活动标记小圆点
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasActivity ? AppColors.secondary : Colors.transparent,
          ),
        ),
      ],
    );
  }
}

/// 今日学习统计卡 —— 对应截图右侧的统计面板
///
/// 显示：日期、学习总时长、预估总时长、两种币的收益、「今日战报」按钮。
class TodayStatsCard extends ConsumerWidget {
  const TodayStatsCard({super.key, required this.onReportTap});

  final VoidCallback onReportTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(todayStudyStatsProvider);
    final now = DateTime.now();
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];

    return Container(
      padding: const EdgeInsets.all(AppSizes.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.primaryLight, width: 2),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------- 日期标题栏（主色底） ----------
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceSm),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Center(
              child: Text(
                '${now.month}月${now.day}日（周${weekdays[now.weekday - 1]}）',
                style: const TextStyle(
                  fontSize: AppSizes.fontLabel,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.spaceMd),

          // ---------- 学习时长 ----------
          _statLine(
            '学习总时长：',
            '${stats.studiedMinutes} 分钟',
          ),
          const SizedBox(height: AppSizes.spaceXs),
          _statLine(
            '预估总时长：',
            '${stats.estimatedMinutes} 分钟',
          ),
          const SizedBox(height: AppSizes.spaceSm),

          // ---------- 两种币的今日收益 ----------
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CoinLabel(
                type: RewardType.wishCoin,
                amount: stats.wishCoinGained,
                showPlus: true,
                fontSize: AppSizes.fontLabel,
              ),
              const SizedBox(width: AppSizes.spaceLg),
              CoinLabel(
                type: RewardType.petCoin,
                amount: stats.petCoinGained,
                showPlus: true,
                fontSize: AppSizes.fontLabel,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceMd),

          // ---------- 今日战报按钮 ----------
          GestureDetector(
            onTap: onReportTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceSm),
              decoration: BoxDecoration(
                color: AppColors.secondaryLight,
                borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
                border: Border.all(color: AppColors.secondary, width: 1.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    size: 18,
                    color: AppColors.secondaryDark,
                  ),
                  SizedBox(width: AppSizes.spaceSm),
                  Text(
                    '今日战报',
                    style: TextStyle(
                      fontSize: AppSizes.fontLabel,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: AppSizes.fontLabel,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: AppSizes.fontLabel,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// 宠物对话气泡 —— 对应截图：「两天没见，本怪兽有点想乐乐～」
class PetDialogueBubble extends StatelessWidget {
  const PetDialogueBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 气泡尖角
        CustomPaint(
          size: const Size(20, 12),
          painter: _BubbleTailPainter(),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spaceLg,
            vertical: AppSizes.spaceMd,
          ),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: AppSizes.fontLabel,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// 气泡尖角绘制
class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.secondary;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
