import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/habit_providers.dart';
import '../providers/pet_providers.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_sizes.dart';
import '../widgets/common_widgets.dart';
import '../widgets/pet_avatar.dart';

/// 报告周期（v1.4.0：只做日报 + 周报）
///
/// **为什么不做月报？**
///
/// 三个理由：
/// 1. **反馈周期太长**：孩子对「一个月」没有直观感受，等拿到月报时
///    早忘了自己做过什么，激励作用趋近于零。日报/周报才是他能
///   跟当下行为建立联系的尺度。
/// 2. **数据稀疏**：一个 9 岁孩子的单月数据点也就 30 天，月报的
///   内容与周报高度重复，只是数字更大，边际价值低。
/// 3. **成本收益**：多一个周期就多一套聚合逻辑与 UI，而孩子的
///    注意力是稀缺资源，报表太多反而每个都不看。
///
/// 结论：**日报管「今天做得怎么样」，周报管「这一周有没有坚持」**，
/// 两个尺度就够了。
enum LearningReportPeriod {
  day('日报'),
  week('周报');

  const LearningReportPeriod(this.label);
  final String label;
}

/// 学习日报 / 周报页（v1.4.0 新增）
///
/// **与「数据报告」(ReportPage) 的区别**
///
/// | | 数据报告 | 学习报表（本页） |
/// |---|---|---|
/// | 受众 | 家长 | **孩子** |
/// | 语气 | 中性、指标化 | **宠物口吻、鼓励式** |
/// | 内容 | 柱状图 / 饼图 / 均衡度 | 一句话总结 + 亮点 + 小建议 |
/// | 目的 | 分析 | **情绪价值 + 激励** |
///
/// 所以这一页刻意**不放图表**：孩子看不懂标准差，也不想看。
/// 他要的是「小宠物夸我」。
class LearningReportPage extends ConsumerStatefulWidget {
  const LearningReportPage({super.key});

  @override
  ConsumerState<LearningReportPage> createState() => _LearningReportPageState();
}

class _LearningReportPageState extends ConsumerState<LearningReportPage> {
  LearningReportPeriod _period = LearningReportPeriod.day;

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(activeChildProvider);
    final pet = ref.watch(activePetProvider);

    if (child == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('学习报表')),
        body: const EmptyPlaceholder(emoji: '🐣', text: '请先创建小朋友档案'),
      );
    }

    final data = _compute(child.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('学习报表'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: EdgeInsets.symmetric(
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
                children: LearningReportPeriod.values.map((p) {
                  final selected = _period == p;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _period = p),
                      child: AnimatedContainer(
                        duration: AppSizes.durationFast,
                        padding: EdgeInsets.symmetric(
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
        padding: EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          children: [
            // ---------- 宠物开场白（本页灵魂） ----------
            _buildPetSpeech(pet, child.name, data),

            SizedBox(height: AppSizes.spaceLg),

            // ---------- 关键数字（大字，孩子爱看） ----------
            _buildBigNumbers(data),

            SizedBox(height: AppSizes.spaceLg),

            // ---------- 做得好的地方 ----------
            if (data.highlights.isNotEmpty) ...[
              _buildListCard(
                title: '🌟 做得特别棒',
                items: data.highlights,
                color: AppColors.success,
              ),
              SizedBox(height: AppSizes.spaceLg),
            ],

            // ---------- 可以更好的地方 ----------
            if (data.suggestions.isNotEmpty) ...[
              _buildListCard(
                title: '💡 明天可以试试',
                items: data.suggestions,
                color: AppColors.info,
              ),
              SizedBox(height: AppSizes.spaceLg),
            ],

            // ---------- 周报专属：7 天打卡热力条 ----------
            if (_period == LearningReportPeriod.week) ...[
              _buildWeekHeatmap(data),
              SizedBox(height: AppSizes.spaceLg),
            ],

            SizedBox(height: AppSizes.spaceXxl),
          ],
        ),
      ),
    );
  }

  /// 宠物开场白 —— 用宠物口吻把「今天/本周」总结成一句话
  ///
  /// 语气设计原则：
  /// - **先夸后提**：哪怕数据很差，也要先找出一件值得肯定的事；
  /// - **说人话**：不说「完成率 66.7%」，说「做了 2 件事，超棒的」；
  /// - **给期待**：结尾永远指向明天，而不是批评今天。
  Widget _buildPetSpeech(Pet? pet, String childName, _LearningData data) {
    final speech = data.petSpeech;

    return AppCard(
      padding: EdgeInsets.all(AppSizes.spaceLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pet != null)
            PetAvatar(
              pet: pet,
              size: AppScale.s(96),
              moodState: data.petMood,
            )
          else
            Text('🐱', style: TextStyle(fontSize: AppScale.s(72))),
          SizedBox(width: AppSizes.spaceLg),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(AppSizes.spaceMd),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppSizes.radiusSm),
                  topRight: Radius.circular(AppSizes.radiusLg),
                  bottomLeft: Radius.circular(AppSizes.radiusLg),
                  bottomRight: Radius.circular(AppSizes.radiusLg),
                ),
              ),
              child: Text(
                speech,
                style: TextStyle(
                  fontSize: AppSizes.fontBody,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 关键数字（三宫格大字）
  Widget _buildBigNumbers(_LearningData data) {
    return Row(
      children: [
        Expanded(
          child: _bigNumber(
            emoji: '⏱️',
            value: '${data.studyMinutes}',
            unit: '分钟',
            label: _period == LearningReportPeriod.day ? '今天学习' : '本周学习',
            color: AppColors.primary,
          ),
        ),
        SizedBox(width: AppSizes.spaceMd),
        Expanded(
          child: _bigNumber(
            emoji: '✅',
            value: '${data.doneThings}',
            unit: '件',
            label: '完成的事',
            color: AppColors.success,
          ),
        ),
        SizedBox(width: AppSizes.spaceMd),
        Expanded(
          child: _bigNumber(
            emoji: '🔥',
            value: '${data.streak}',
            unit: '天',
            label: '连续坚持',
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }

  Widget _bigNumber({
    required String emoji,
    required String value,
    required String unit,
    required String label,
    required Color color,
  }) {
    return AppCard(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.spaceSm,
        vertical: AppSizes.spaceLg,
      ),
      child: Column(
        children: [
          Text(emoji, style: TextStyle(fontSize: AppScale.s(22))),
          SizedBox(height: AppSizes.spaceSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: AppScale.s(26),
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
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppSizes.fontTiny,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// 要点列表卡
  Widget _buildListCard({
    required String title,
    required List<String> items,
    required Color color,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: AppSizes.fontHeadline,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSizes.spaceMd),
          ...items.map(
            (t) => Padding(
              padding: EdgeInsets.only(bottom: AppSizes.spaceSm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: AppScale.s(7)),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: AppSizes.spaceSm),
                  Expanded(
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: AppSizes.fontBody,
                        height: 1.5,
                        color: AppColors.textPrimary,
                      ),
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

  /// 周报专属：7 天打卡热力条
  ///
  /// 比数字更有冲击力 —— 孩子一眼看到「中间空了 2 天」，
  /// 这种视觉反馈比「完成率 71%」有效得多。
  Widget _buildWeekHeatmap(_LearningData data) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final now = DateTime.now();
    final todayIdx = now.weekday - 1;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📅 这一周的坚持',
            style: TextStyle(
              fontSize: AppSizes.fontHeadline,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSizes.spaceLg),
          Row(
            children: List.generate(7, (i) {
              final count = data.weekCounts.length > i ? data.weekCounts[i] : 0;
              final isToday = i == todayIdx;
              final isFuture = i > todayIdx;
              // 颜色深浅按当天完成数量分档
              final color = count >= 3
                  ? AppColors.success
                  : count == 2
                      ? AppColors.success.withValues(alpha: 0.65)
                      : count == 1
                          ? AppColors.success.withValues(alpha: 0.35)
                          : AppColors.surfaceVariant;

              return Expanded(
                child: Column(
                  children: [
                    Container(
                      height: AppScale.s(52),
                      margin: EdgeInsets.symmetric(
                        horizontal: AppScale.s(3),
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                        border: isToday
                            ? Border.all(color: AppColors.primary, width: 2)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: isFuture
                          ? null
                          : Text(
                              count > 0 ? '$count' : '',
                              style: TextStyle(
                                fontSize: AppSizes.fontLabel,
                                fontWeight: FontWeight.w800,
                                color: count > 0
                                    ? Colors.white
                                    : AppColors.textHint,
                              ),
                            ),
                    ),
                    SizedBox(height: AppSizes.spaceXs),
                    Text(
                      weekdays[i],
                      style: TextStyle(
                        fontSize: AppSizes.fontTiny,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                        color: isToday
                            ? AppColors.primaryDark
                            : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          SizedBox(height: AppSizes.spaceMd),
          Text(
            data.weekComment,
            style: TextStyle(
              fontSize: AppSizes.fontCaption,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 数据计算 ====================

  /// 汇总本周期数据
  _LearningData _compute(String childId) {
    final db = DatabaseService.instance;
    final now = DateTime.now();
    final isDay = _period == LearningReportPeriod.day;

    // 周期起点
    final start = isDay
        ? DateTime(now.year, now.month, now.day)
        : DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));

    // ---------- 番茄钟学习时长 ----------
    final sessions = db
        .getPomodoroSessions(childId)
        .where((s) => s.isCompleted && !s.endTime.isBefore(start))
        .toList();
    final studyMinutes = sessions.fold(0, (sum, s) => sum + s.actualMinutes);

    // ---------- 完成任务数 ----------
    final tasks = db
        .getTasks(childId)
        .where((t) => t.isDone && (t.completedAt?.isAfter(start) ?? false))
        .length;

    // ---------- 已通过的打卡数 ----------
    final checkIns = isDay
        ? db.getCheckedHabitIdsOn(childId, now).length
        : _weekApprovedCount(db, childId, start);

    final doneThings = tasks + checkIns;

    // ---------- 连续坚持天数 ----------
    final streak = _computeStreak(db, childId, now);

    // ---------- 本周每日完成数（周报用） ----------
    final weekCounts = List<int>.filled(7, 0);
    if (!isDay) {
      for (int i = 0; i < 7; i++) {
        final d = start.add(Duration(days: i));
        if (d.isAfter(now)) break;
        weekCounts[i] = _dailyDoneCount(db, childId, d);
      }
    }

    // ---------- 朗读次数 ----------
    final recordings = db
        .getRecordings(childId)
        .where((r) => !r.createdAt.isBefore(start))
        .length;

    return _LearningData(
      studyMinutes: studyMinutes,
      doneThings: doneThings,
      streak: streak,
      recordCount: recordings,
      weekCounts: weekCounts,
      isDay: isDay,
      childName: '',
      pomodoroCount: sessions.length,
      checkInCount: checkIns,
      taskCount: tasks,
    );
  }

  /// 一周内「已通过」的打卡总次数
  int _weekApprovedCount(DatabaseService db, String childId, DateTime start) {
    var total = 0;
    for (int i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      total += db.getCheckedHabitIdsOn(childId, d).length;
    }
    return total;
  }

  /// 某天完成的事情数（打卡 + 任务）
  int _dailyDoneCount(DatabaseService db, String childId, DateTime day) {
    final checkIns = db.getCheckedHabitIdsOn(childId, day).length;
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final tasks = db.getTasks(childId).where((t) {
      final at = t.completedAt;
      return t.isDone &&
          at != null &&
          !at.isBefore(dayStart) &&
          at.isBefore(dayEnd);
    }).length;
    return checkIns + tasks;
  }

  /// 连续坚持天数（从今天往回数，直到某天「什么都没做」）
  int _computeStreak(DatabaseService db, String childId, DateTime now) {
    var streak = 0;
    var cursor = DateTime(now.year, now.month, now.day);

    // 今天还没做不算断 —— 从今天开始看，若今天为 0 则从昨天起算
    if (_dailyDoneCount(db, childId, cursor) == 0) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    for (int i = 0; i < 365; i++) {
      if (_dailyDoneCount(db, childId, cursor) > 0) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }
}

/// 汇总后的学习数据
class _LearningData {
  _LearningData({
    required this.studyMinutes,
    required this.doneThings,
    required this.streak,
    required this.recordCount,
    required this.weekCounts,
    required this.isDay,
    required this.childName,
    required this.pomodoroCount,
    required this.checkInCount,
    required this.taskCount,
  });

  final int studyMinutes;
  final int doneThings;
  final int streak;
  final int recordCount;
  final List<int> weekCounts;
  final bool isDay;
  final String childName;
  final int pomodoroCount;
  final int checkInCount;
  final int taskCount;

  // ==================== 宠物口吻文案生成 ====================

  /// 宠物开场白
  ///
  /// 分五档，从「啥也没做」到「超级棒」，每档语气不同。
  /// **关键：即使 0 分档也不责备**，而是表达「我在等你」。
  String get petSpeech {
    final unit = isDay ? '今天' : '这周';

    if (doneThings == 0 && studyMinutes == 0) {
      return isDay
          ? '咕噜噜…今天咱们好像还没一起努力呢。\n没关系呀，现在开始也不算晚，'
              '我在这里等你哦 🐾'
          : '这一周咱们好像都在休息呢～\n要不要下周一起定个小目标？我陪你！🐾';
    }

    if (doneThings <= 2) {
      return isDay
          ? '我看到你今天动起来啦！\n虽然只有 $doneThings 件，但「开始」'
              '本身就很了不起 💪'
          : '这周完成了 $doneThings 件事，有进步哦！\n'
              '坚持下去，我会一直陪着你的～';
    }

    if (doneThings <= 5) {
      return isDay
          ? '哇，今天完成了 $doneThings 件事！\n'
              '${studyMinutes > 0 ? '还学习了 $studyMinutes 分钟，' : ''}'
              '你越来越靠谱了 ✨'
          : '这周做了 $doneThings 件事，好厉害！\n'
              '${streak > 1 ? '而且已经连续 $streak 天啦，' : ''}'
              '我感觉自己都变强壮了一点 🐾';
    }

    if (streak >= 7) {
      return '太厉害了！连续 $streak 天都没有断过！\n'
          '${isDay ? '今天' : '这周'}做了 $doneThings 件事，'
          '你简直是我的超级英雄 🦸';
    }

    return isDay
        ? '今天火力全开呀！$doneThings 件事全部拿下！\n'
            '${studyMinutes > 0 ? '学习 $studyMinutes 分钟，' : ''}'
            '我都想给你颁个奖杯了 🏆'
        : '这周简直是你的高光时刻！\n'
            '$doneThings 件事 + 连续 $streak 天，'
            '我要把这个好消息告诉全世界 📣';
  }

  /// 宠物表情（跟随数据）
  PetMoodState get petMood {
    if (doneThings == 0 && studyMinutes == 0) return PetMoodState.sad;
    if (doneThings >= 6 || streak >= 7) return PetMoodState.excited;
    if (doneThings >= 3) return PetMoodState.happy;
    return PetMoodState.normal;
  }

  /// 做得好的地方（永远至少有一条 —— 这是「情绪价值」的底线）
  List<String> get highlights {
    final list = <String>[];
    final unit = isDay ? '今天' : '这周';

    if (studyMinutes >= 60) {
      list.add('$unit专注学习了 $studyMinutes 分钟，相当于坐了一整节课还多！');
    } else if (studyMinutes >= 25) {
      list.add('$unit学习了 $studyMinutes 分钟，专注力很不错哦～');
    } else if (studyMinutes > 0) {
      list.add('$unit开始学习啦，哪怕只是 $studyMinutes 分钟，也是好的开始。');
    }

    if (streak >= 3) {
      list.add('已经连续坚持 $streak 天！这种「不中断」最难得。');
    }

    if (checkInCount >= 3) {
      list.add('完成了 $checkInCount 个习惯打卡，自律能力在悄悄变强。');
    }

    if (taskCount >= 3) {
      list.add('$unit完成 $taskCount 个任务，说到做到的样子很帅。');
    }

    if (recordCount > 0) {
      list.add('朗读了 $recordCount 次，敢开口说话就是最大的进步。');
    }

    // 兜底：保证永远有内容（哪怕是「参与了」）
    if (list.isEmpty) {
      if (doneThings > 0) {
        list.add('$unit完成了 $doneThings 件事，迈出了第一步。');
      } else {
        list.add('愿意打开这一页看看自己，本身就是一种认真。');
      }
    }

    return list.take(3).toList();
  }

  /// 建议（温和、可执行，绝不批评）
  List<String> get suggestions {
    final list = <String>[];
    final unit = isDay ? '今天' : '这周';

    if (doneThings == 0) {
      list.add('先挑一件最简单的事做掉，比如读 5 分钟书，开了头就顺了。');
    }

    if (studyMinutes > 0 && studyMinutes < 25) {
      list.add('试着把学习时间拉长到 25 分钟，可以用番茄钟计时，中途不许跑。');
    }

    if (isDay && weekCounts.isEmpty) {
      // 日报不看周数据，跳过
    }

    if (!isDay && weekCounts.isNotEmpty) {
      final zeroDays = weekCounts.where((c) => c == 0).length;
      if (zeroDays >= 3) {
        list.add('这周有 $zeroDays 天什么都没做，下周试试「每天只做最少一件」。');
      } else if (zeroDays > 0) {
        list.add('这周空了 $zeroDays 天，把每天都连起来会更棒！');
      }
    }

    if (checkInCount == 0 && doneThings > 0) {
      list.add('别忘了习惯打卡，攒连击会有额外奖励哦。');
    }

    if (list.isEmpty) {
      list.add('保持这个状态就好，$unit做得刚刚好，不用给自己加码。');
    }

    return list.take(2).toList();
  }

  /// 周报底部点评
  String get weekComment {
    final total = weekCounts.fold(0, (a, b) => a + b);
    final active = weekCounts.where((c) => c > 0).length;

    if (total == 0) return '这周还没有记录，下周一起加油吧！';
    if (active == 7) return '7 天全勤！这是我见过最稳的一周 🎉';
    if (active >= 5) return '本周活跃 $active 天，非常稳定，继续保持～';
    if (active >= 3) return '本周活跃 $active 天，已经过半啦，再稳一点就更好。';
    return '本周活跃 $active 天，下周试着多坚持 1 天？';
  }
}
