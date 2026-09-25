import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../widgets/common_widgets.dart';

/// 统计周期
enum ReportPeriod {
  week('本周'),
  month('本月');

  const ReportPeriod(this.label);
  final String label;
}

/// 数据报告页面
///
/// **对应需求模块 6：**
/// - 统计维度：学习总时长、任务完成率、科目均衡度、按时完成率
/// - 用柱状图 / 饼图展示（fl_chart）
class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  ReportPeriod _period = ReportPeriod.week;

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(activeChildProvider);

    if (child == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('数据报告')),
        body: const EmptyPlaceholder(emoji: '🐣', text: '请先创建小朋友档案'),
      );
    }

    final data = _computeStats(child.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('学习报告'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spaceLg,
              vertical: AppSizes.spaceSm,
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
              ),
              child: Row(
                children: ReportPeriod.values.map((p) {
                  final selected = _period == p;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _period = p),
                      child: AnimatedContainer(
                        duration: AppSizes.durationFast,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.spaceSm,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusCircle),
                        ),
                        child: Text(
                          p.label,
                          style: TextStyle(
                            fontSize: AppSizes.fontLabel,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          children: [
            // ---------- 核心指标卡 ----------
            _buildMetricGrid(data),

            const SizedBox(height: AppSizes.spaceLg),

            // ---------- 学习时长柱状图 ----------
            _buildDurationChart(data),

            const SizedBox(height: AppSizes.spaceLg),

            // ---------- 科目均衡度饼图 ----------
            _buildSubjectPie(data),

            const SizedBox(height: AppSizes.spaceXxl),
          ],
        ),
      ),
    );
  }

  /// 核心指标网格
  Widget _buildMetricGrid(_ReportData data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _metricCard(
                emoji: '⏱️',
                label: '学习总时长',
                value: '${data.totalMinutes}',
                unit: '分钟',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSizes.spaceMd),
            Expanded(
              child: _metricCard(
                emoji: '✅',
                label: '任务完成率',
                value: '${(data.completionRate * 100).round()}',
                unit: '%',
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spaceMd),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                emoji: '⚖️',
                label: '科目均衡度',
                value: '${(data.balanceScore * 100).round()}',
                unit: '%',
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: AppSizes.spaceMd),
            Expanded(
              child: _metricCard(
                emoji: '🎯',
                label: '按时完成率',
                value: '${(data.onTimeRate * 100).round()}',
                unit: '%',
                color: AppColors.accentDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricCard({
    required String emoji,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: AppSizes.spaceSm),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: AppSizes.fontCaption,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: AppSizes.spaceXs),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: AppSizes.fontCaption,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 学习时长柱状图
  Widget _buildDurationChart(_ReportData data) {
    final maxY = data.dailyMinutes.isEmpty
        ? 60.0
        : (data.dailyMinutes.reduce((a, b) => a > b ? a : b) + 15)
            .toDouble();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '学习时长趋势',
            style: TextStyle(
              fontSize: AppSizes.fontHeadline,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.spaceLg),

          SizedBox(
            height: 180,
            child: data.dailyMinutes.every((e) => e == 0)
                ? const EmptyPlaceholder(
                    emoji: '📊',
                    text: '还没有学习记录',
                    hint: '完成一个番茄钟就会出现在这里',
                  )
                : BarChart(
                    BarChartData(
                      maxY: maxY,
                      alignment: BarChartAlignment.spaceAround,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => AppColors.textPrimary,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${rod.toY.round()} 分钟',
                              const TextStyle(
                                color: Colors.white,
                                fontSize: AppSizes.fontCaption,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            interval: maxY / 3,
                            getTitlesWidget: (value, meta) => Text(
                              value.round().toString(),
                              style: const TextStyle(
                                fontSize: AppSizes.fontTiny,
                                color: AppColors.textHint,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= data.dayLabels.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSizes.spaceSm,
                                ),
                                child: Text(
                                  data.dayLabels[i],
                                  style: const TextStyle(
                                    fontSize: AppSizes.fontTiny,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 3,
                        getDrawingHorizontalLine: (value) => const FlLine(
                          color: AppColors.divider,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(data.dailyMinutes.length, (i) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: data.dailyMinutes[i].toDouble(),
                              width: 16,
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusSm,
                              ),
                              gradient: const LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [AppColors.primary, AppColors.info],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 科目均衡度饼图
  Widget _buildSubjectPie(_ReportData data) {
    if (data.subjectMinutes.isEmpty) {
      return const AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '科目均衡度',
              style: TextStyle(
                fontSize: AppSizes.fontHeadline,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppSizes.spaceLg),
            EmptyPlaceholder(
              emoji: '🥧',
              text: '还没有科目数据',
            ),
          ],
        ),
      );
    }

    final entries = data.subjectMinutes.entries.toList();
    const colors = [
      AppColors.primary,
      AppColors.accent,
      AppColors.secondary,
      AppColors.success,
      AppColors.warning,
      AppColors.info,
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '科目均衡度',
            style: TextStyle(
              fontSize: AppSizes.fontHeadline,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.spaceLg),

          Row(
            children: [
              // 饼图
              SizedBox(
                width: 140,
                height: 140,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 32,
                    sections: List.generate(entries.length, (i) {
                      final total = data.subjectMinutes.values
                          .fold(0, (a, b) => a + b);
                      final percent =
                          total == 0 ? 0 : entries[i].value / total * 100;
                      return PieChartSectionData(
                        value: entries[i].value.toDouble(),
                        color: colors[i % colors.length],
                        radius: 34,
                        showTitle: percent > 8,
                        title: '${percent.round()}%',
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.spaceLg),

              // 图例
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(entries.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppSizes.spaceSm,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: colors[i % colors.length],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: AppSizes.spaceSm),
                          Expanded(
                            child: Text(
                              entries[i].key,
                              style: const TextStyle(
                                fontSize: AppSizes.fontCaption,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${entries[i].value}分',
                            style: const TextStyle(
                              fontSize: AppSizes.fontCaption,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSizes.spaceMd),

          // 均衡度提示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSizes.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Text(
              data.balanceScore >= 0.7
                  ? '👍 各科目分布很均衡，继续保持！'
                  : '💡 科目之间有点偏科，注意均衡安排哦',
              style: const TextStyle(
                fontSize: AppSizes.fontCaption,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 计算统计数据
  _ReportData _computeStats(String childId) {
    final db = DatabaseService.instance;
    final now = DateTime.now();

    // 计算统计区间
    final (start, dayCount) = _period == ReportPeriod.week
        ? (now.subtract(Duration(days: now.weekday - 1)), 7)
        : (DateTime(now.year, now.month, 1), now.day);

    // ---------- 番茄钟学习时长 ----------
    final sessions = db
        .getPomodoroSessions(childId)
        .where((s) => s.isCompleted && s.endTime.isAfter(start))
        .toList();

    final totalMinutes = sessions.fold(0, (sum, s) => sum + s.actualMinutes);

    // 按天聚合学习时长
    final dailyMinutes = List<int>.filled(dayCount, 0);
    for (final s in sessions) {
      final dayIndex = s.endTime
          .difference(start)
          .inDays;
      if (dayIndex >= 0 && dayIndex < dayCount) {
        dailyMinutes[dayIndex] += s.actualMinutes;
      }
    }

    // 日期标签
    final dayLabels = List.generate(dayCount, (i) {
      final d = start.add(Duration(days: i));
      return '${d.day}';
    });

    // ---------- 科目学习时长 ----------
    final subjectMinutes = <String, int>{};
    for (final s in sessions) {
      if (s.taskId == null) continue;
      final task = db.tasks.get(s.taskId) as Task?;
      if (task == null) continue;
      subjectMinutes[task.subject] =
          (subjectMinutes[task.subject] ?? 0) + s.actualMinutes;
    }

    // ---------- 任务完成率 ----------
    final tasks = db.getTasks(childId);
    final periodTasks = tasks.where((t) {
      // 统计区间内创建或完成的任务
      return t.createdAt.isAfter(start) ||
          (t.completedAt?.isAfter(start) ?? false);
    }).toList();

    final doneTasks = periodTasks.where((t) => t.isDone).toList();
    final completionRate = periodTasks.isEmpty
        ? 0.0
        : doneTasks.length / periodTasks.length;

    // ---------- 按时完成率 ----------
    // 只要任务有截止时间，且完成时间早于截止时间，即算按时
    final tasksWithDue = doneTasks.where((t) => t.dueDate != null).toList();
    final onTimeTasks = tasksWithDue.where((t) {
      return t.completedAt != null &&
          !t.completedAt!.isAfter(
            DateTime(
              t.dueDate!.year,
              t.dueDate!.month,
              t.dueDate!.day,
              23,
              59,
              59,
            ),
          );
    }).toList();
    final onTimeRate =
        tasksWithDue.isEmpty ? 1.0 : onTimeTasks.length / tasksWithDue.length;

    // ---------- 科目均衡度 ----------
    // 用「各科目占比的标准差」衡量：越接近 1 越均衡
    double balanceScore = 0;
    if (subjectMinutes.length > 1) {
      final total = subjectMinutes.values.fold(0, (a, b) => a + b);
      if (total > 0) {
        final avg = total / subjectMinutes.length;
        final variance = subjectMinutes.values
                .map((v) => (v - avg) * (v - avg))
                .fold(0.0, (a, b) => a + b) /
            subjectMinutes.length;
        final stdDev = variance > 0 ? _sqrt(variance) : 0.0;
        // 标准差越小越均衡；归一化到 0-1
        balanceScore = (1 - (stdDev / avg).clamp(0.0, 1.0)).clamp(0.0, 1.0);
      }
    } else if (subjectMinutes.length == 1) {
      balanceScore = 0.5; // 只有一科，给中间分
    }

    return _ReportData(
      totalMinutes: totalMinutes,
      completionRate: completionRate,
      balanceScore: balanceScore,
      onTimeRate: onTimeRate,
      dailyMinutes: dailyMinutes,
      dayLabels: dayLabels,
      subjectMinutes: subjectMinutes,
    );
  }

  /// 平方根（避免引入 dart:math 影响其他命名）
  double _sqrt(double x) {
    if (x <= 0) return 0;
    var guess = x;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}

/// 报告数据
class _ReportData {
  const _ReportData({
    required this.totalMinutes,
    required this.completionRate,
    required this.balanceScore,
    required this.onTimeRate,
    required this.dailyMinutes,
    required this.dayLabels,
    required this.subjectMinutes,
  });

  final int totalMinutes;
  final double completionRate;
  final double balanceScore;
  final double onTimeRate;
  final List<int> dailyMinutes;
  final List<String> dayLabels;
  final Map<String, int> subjectMinutes;
}
