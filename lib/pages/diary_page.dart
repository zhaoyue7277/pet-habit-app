import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/settings_providers.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../widgets/common_widgets.dart';

/// 打卡日记页面
///
/// **对应需求模块 6：**
/// - 以日历本 UI 展示每日完成的任务
/// - 底部留有家长写 Note 的输入框（本地存储）
class DiaryPage extends ConsumerStatefulWidget {
  const DiaryPage({super.key});

  @override
  ConsumerState<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends ConsumerState<DiaryPage> {
  /// 当前查看的月份
  DateTime _currentMonth = DateTime.now();

  /// 选中的日期
  DateTime _selectedDate = DateTime.now();

  final TextEditingController _noteController = TextEditingController();
  String _selectedMood = '😊';

  static const List<String> _moodEmojis = ['😊', '😄', '😐', '😔', '😤'];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(activeChildProvider);

    if (child == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('打卡日记')),
        body: const EmptyPlaceholder(emoji: '🐣', text: '请先创建小朋友档案'),
      );
    }

    // 同步已保存的备注到输入框
    final dateKey = HabitCheckIn.keyOf(_selectedDate);
    final existingNote = ref.watch(dailyNoteProvider(dateKey));
    if (existingNote != null && _noteController.text != existingNote.content) {
      _noteController.text = existingNote.content;
      _selectedMood = existingNote.moodEmoji;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('打卡日记'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          children: [
            // ---------- 日历 ----------
            _buildCalendar(child.id),

            const SizedBox(height: AppSizes.spaceLg),

            // ---------- 当日完成任务 ----------
            _buildDayTasks(child.id),

            const SizedBox(height: AppSizes.spaceLg),

            // ---------- 家长备注 ----------
            _buildNoteSection(child.id, dateKey),

            const SizedBox(height: AppSizes.spaceXxl),
          ],
        ),
      ),
    );
  }

  /// 日历本
  Widget _buildCalendar(String childId) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

    // 本月第一天是周几（1=周一）
    final startWeekday = firstDay.weekday;

    // 收集本月有活动的日期
    final activityDays = _getActivityDays(childId);

    return AppCard(
      child: Column(
        children: [
          // ---------- 月份切换 ----------
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => setState(() {
                  _currentMonth =
                      DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
                }),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${_currentMonth.year}年${_currentMonth.month}月',
                    style: const TextStyle(
                      fontSize: AppSizes.fontHeadline,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => setState(() {
                  _currentMonth =
                      DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
                }),
              ),
            ],
          ),

          const SizedBox(height: AppSizes.spaceSm),

          // ---------- 星期表头 ----------
          Row(
            children: ['一', '二', '三', '四', '五', '六', '日']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontSize: AppSizes.fontCaption,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),

          const SizedBox(height: AppSizes.spaceSm),

          // ---------- 日期网格 ----------
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: AppSizes.spaceXs,
              crossAxisSpacing: AppSizes.spaceXs,
              childAspectRatio: 1,
            ),
            itemCount: startWeekday - 1 + daysInMonth,
            itemBuilder: (context, index) {
              // 前置空格
              if (index < startWeekday - 1) {
                return const SizedBox.shrink();
              }

              final day = index - startWeekday + 2;
              final date = DateTime(
                _currentMonth.year,
                _currentMonth.month,
                day,
              );
              final isSelected = _isSameDay(date, _selectedDate);
              final isToday = _isSameDay(date, DateTime.now());
              final hasActivity = activityDays.contains(
                HabitCheckIn.keyOf(date),
              );

              return GestureDetector(
                onTap: () => setState(() => _selectedDate = date),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (isToday
                            ? AppColors.primaryLight.withValues(alpha: 0.4)
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    border: isToday && !isSelected
                        ? Border.all(color: AppColors.primary, width: 1.5)
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: AppSizes.fontLabel,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                      // 活动标记
                      if (hasActivity)
                        Positioned(
                          bottom: 4,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.success,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 当日完成的任务列表
  Widget _buildDayTasks(String childId) {
    final db = DatabaseService.instance;
    final dateKey = HabitCheckIn.keyOf(_selectedDate);

    // 当天完成的任务
    final doneTasks = db.getTasks(childId).where((t) {
      return t.completedAt != null &&
          HabitCheckIn.keyOf(t.completedAt!) == dateKey;
    }).toList();

    // 当天的习惯打卡
    final checkIns = db.checkIns.values.cast<HabitCheckIn>().where((c) {
      return c.childId == childId && c.dateKey == dateKey;
    }).toList();

    // 当天的学习时长
    final minutes = db.getPomodoroSessions(childId)
        .where((s) => s.dateKey == dateKey && s.isCompleted)
        .fold(0, (sum, s) => sum + s.actualMinutes);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${_selectedDate.month}月${_selectedDate.day}日',
                style: const TextStyle(
                  fontSize: AppSizes.fontHeadline,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (minutes > 0)
                TagChip(
                  text: '⏱️ 学习 $minutes 分钟',
                  color: AppColors.primaryLight,
                  textColor: AppColors.primaryDark,
                ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceLg),

          if (doneTasks.isEmpty && checkIns.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSizes.spaceLg),
              child: Center(
                child: Text(
                  '这一天还没有记录哦',
                  style: TextStyle(
                    fontSize: AppSizes.fontBody,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            )
          else ...[
            // 完成的任务
            ...doneTasks.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.spaceSm),
                  child: Row(
                    children: [
                      const Text('✅', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: AppSizes.spaceSm),
                      Expanded(
                        child: Text(
                          t.title,
                          style: const TextStyle(
                            fontSize: AppSizes.fontBody,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${t.rewardType.emoji}+${t.rewardValue}',
                        style: const TextStyle(
                          fontSize: AppSizes.fontCaption,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentDark,
                        ),
                      ),
                    ],
                  ),
                )),

            // 习惯打卡
            ...checkIns.map((c) {
              final habit = db.habits.get(c.habitId) as Habit?;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.spaceSm),
                child: Row(
                  children: [
                    Text(
                      habit?.iconEmoji ?? '🔥',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: AppSizes.spaceSm),
                    Expanded(
                      child: Text(
                        habit?.name ?? '习惯打卡',
                        style: const TextStyle(
                          fontSize: AppSizes.fontBody,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${c.checkInTime.hour.toString().padLeft(2, '0')}:'
                      '${c.checkInTime.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: AppSizes.fontCaption,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// 家长备注区
  Widget _buildNoteSection(String childId, String dateKey) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✍️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: AppSizes.spaceSm),
              const Text(
                '家长寄语',
                style: TextStyle(
                  fontSize: AppSizes.fontHeadline,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              // 心情选择
              ..._moodEmojis.map((m) => GestureDetector(
                    onTap: () => setState(() => _selectedMood = m),
                    child: Container(
                      margin: const EdgeInsets.only(left: AppSizes.spaceXs),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _selectedMood == m
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: _selectedMood == m
                            ? Border.all(color: AppColors.primary, width: 2)
                            : null,
                      ),
                      child: Text(m, style: const TextStyle(fontSize: 18)),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: AppSizes.spaceLg),

          // 输入框
          TextField(
            controller: _noteController,
            maxLines: 4,
            style: const TextStyle(fontSize: AppSizes.fontBody),
            decoration: InputDecoration(
              hintText: '写点什么鼓励孩子吧～',
              hintStyle: const TextStyle(
                fontSize: AppSizes.fontBody,
                color: AppColors.textHint,
              ),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.spaceMd),

          // 保存按钮
          BouncyButton(
            onPressed: () async {
              await ref.read(diaryControllerProvider).saveNote(
                    childId: childId,
                    dateKey: dateKey,
                    content: _noteController.text.trim(),
                    moodEmoji: _selectedMood,
                  );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('已保存 💾'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                  ),
                );
              }
            },
            height: AppSizes.buttonSmallHeight,
            child: const Text('保存寄语'),
          ),
        ],
      ),
    );
  }

  /// 收集有活动的日期（任务完成 / 习惯打卡）
  Set<String> _getActivityDays(String childId) {
    final db = DatabaseService.instance;
    final days = <String>{};

    for (final t in db.getTasks(childId)) {
      if (t.completedAt != null) {
        days.add(HabitCheckIn.keyOf(t.completedAt!));
      }
    }
    for (final c in db.checkIns.values.cast<HabitCheckIn>()) {
      if (c.childId == childId) days.add(c.dateKey);
    }
    for (final note in db.dailyNotes.values.cast<DailyNote>()) {
      if (note.childId == childId && note.content.isNotEmpty) {
        days.add(note.dateKey);
      }
    }

    return days;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
