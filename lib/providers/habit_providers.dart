import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import 'core_providers.dart';

/// 当前孩子的全部习惯
final habitListProvider = Provider<List<Habit>>((ref) {
  final childId = ref.watch(activeChildIdProvider);
  ref.watch(dataRevisionProvider);
  if (childId == null) return [];
  return ref.watch(databaseProvider).getHabits(childId);
});

/// 今日已**验收通过**的习惯 ID 集合
///
/// v1.4.0 起：待验收 / 已驳回的记录不算完成，见
/// `DatabaseService.getCheckedHabitIdsOn`。
final checkedHabitIdsProvider = Provider<Set<String>>((ref) {
  final childId = ref.watch(activeChildIdProvider);
  ref.watch(dataRevisionProvider);
  if (childId == null) return {};
  return ref.watch(databaseProvider).getCheckedHabitIdsOn(childId, DateTime.now());
});

/// 今日**待验收**的习惯 ID 集合（UI 显示「⏳ 待验收」角标）
final pendingHabitIdsProvider = Provider<Set<String>>((ref) {
  final childId = ref.watch(activeChildIdProvider);
  ref.watch(dataRevisionProvider);
  if (childId == null) return {};
  final db = ref.watch(databaseProvider);
  final today = HabitCheckIn.keyOf(DateTime.now());
  return db
      .getPendingCheckIns(childId)
      .where((c) => c.dateKey == today)
      .map((c) => c.habitId)
      .toSet();
});

/// 待验收记录队列（家长验收页数据源，最新在前）
final pendingCheckInsProvider = Provider<List<HabitCheckIn>>((ref) {
  final childId = ref.watch(activeChildIdProvider);
  ref.watch(dataRevisionProvider);
  if (childId == null) return [];
  return ref.watch(databaseProvider).getPendingCheckIns(childId);
});

/// 今日被驳回的记录（孩子需要知道「可以补交」）
///
/// 单独成一个 provider，是因为「驳回」与「待验收」在 UI 上语气
/// 完全不同：前者要安慰 + 引导补交，后者只是等待。
final rejectedCheckInsTodayProvider = Provider<List<HabitCheckIn>>((ref) {
  final childId = ref.watch(activeChildIdProvider);
  ref.watch(dataRevisionProvider);
  if (childId == null) return [];
  final db = ref.watch(databaseProvider);
  final today = HabitCheckIn.keyOf(DateTime.now());
  return db.checkIns.values
      .cast<HabitCheckIn>()
      .where((c) =>
          c.childId == childId && c.dateKey == today && c.isRejected)
      .toList();
});

/// 待验收数量（首页红点角标）
final pendingCheckInCountProvider = Provider<int>((ref) {
  final childId = ref.watch(activeChildIdProvider);
  ref.watch(dataRevisionProvider);
  if (childId == null) return 0;
  return ref.watch(databaseProvider).getPendingCheckInCount(childId);
});

/// 习惯按打卡时段分组（对应截图：「漫游驿站 · 全天可打卡」）
///
/// 每个习惯按其**第一个时段**归类，同组内按排序权重排列。
final habitsByTimeSlotProvider = Provider<Map<TimeSlot, List<Habit>>>((ref) {
  final habits = ref.watch(habitListProvider);
  final grouped = <TimeSlot, List<Habit>>{};
  for (final h in habits) {
    if (h.isExpired) continue;
    final slot = h.timeSlots.isEmpty ? TimeSlot.anytime : h.timeSlots.first;
    grouped.putIfAbsent(slot, () => []).add(h);
  }
  // 按时段枚举顺序输出，保证 UI 顺序稳定
  final ordered = <TimeSlot, List<Habit>>{};
  for (final slot in TimeSlot.values) {
    if (grouped.containsKey(slot)) ordered[slot] = grouped[slot]!;
  }
  return ordered;
});

/// 今日打卡总览（对应截图顶部的「获得奖励 / 连击天数 / 连击奖励」）
class TodayHabitSummary {
  const TodayHabitSummary({
    required this.totalCount,
    required this.checkedCount,
    required this.rewardGained,
    required this.maxStreak,
    required this.streakRewardGained,
  });

  /// 今日习惯总数
  final int totalCount;

  /// 今日已打卡数
  final int checkedCount;

  /// 今日获得的心愿币奖励
  final int rewardGained;

  /// 最高连击天数
  final int maxStreak;

  /// 连击奖励（宠物币）
  final int streakRewardGained;

  /// 完成度 0.0 - 1.0
  double get progress => totalCount <= 0 ? 0 : checkedCount / totalCount;

  /// 展示文案（对应截图「1/1」）
  String get progressLabel => '$checkedCount/$totalCount';
}

/// 今日习惯总览 Provider
final todayHabitSummaryProvider = Provider<TodayHabitSummary>((ref) {
  final habits = ref.watch(habitListProvider);
  final checked = ref.watch(checkedHabitIdsProvider);

  var reward = 0;
  var streakReward = 0;
  var maxStreak = 0;

  for (final h in habits) {
    if (checked.contains(h.id)) {
      if (h.checkInRewardType == RewardType.wishCoin) {
        reward += h.checkInRewardValue;
      }
    }
    if (h.currentStreakDays > maxStreak) maxStreak = h.currentStreakDays;
    if (h.lastStreakRewardAt != null &&
        h.targetRewardType == RewardType.petCoin &&
        HabitCheckIn.keyOf(h.lastStreakRewardAt!) ==
            HabitCheckIn.keyOf(DateTime.now())) {
      streakReward += h.targetRewardValue;
    }
  }

  final active = habits.where((h) => !h.isExpired).length;

  return TodayHabitSummary(
    totalCount: active,
    checkedCount: checked.length,
    rewardGained: reward,
    maxStreak: maxStreak,
    streakRewardGained: streakReward,
  );
});

/// 习惯库模板（全局，按分类筛选）
final habitTemplatesByCategoryProvider =
    Provider.family<List<HabitTemplate>, HabitCategory>((ref, category) {
  final db = ref.watch(databaseProvider);
  return db.habitTemplates.values
      .cast<HabitTemplate>()
      .where((t) => t.category == category)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
});

/// 习惯操作控制器
class HabitController {
  HabitController(this._db, this._ref);

  final DatabaseService _db;
  final Ref _ref;

  void _bump() => _ref.read(dataRevisionProvider.notifier).bump();

  /// 创建习惯（可从习惯库模板快速创建）
  Future<Habit> createHabit({
    required String childId,
    required String name,
    String iconEmoji = '⭐',
    String? iconAsset,
    HabitCategory category = HabitCategory.study,
    int dailyTargetCount = 1,
    List<TimeSlot> timeSlots = const [TimeSlot.anytime],
    HabitFrequency frequency = HabitFrequency.daily,
    int weeklyTargetCount = 7,
    CheckInMode checkInMode = CheckInMode.quick,
    DateTime? startDate,
    DateTime? endDate,
    RewardType checkInRewardType = RewardType.wishCoin,
    int checkInRewardValue = 10,
    bool enableStreakReward = true,
    int targetStreakDays = 14,
    RewardType targetRewardType = RewardType.petCoin,
    int targetRewardValue = 50,
    RewardValidity rewardValidity = RewardValidity.once,
  }) async {
    final habit = Habit(
      id: _db.newId('habit_'),
      childId: childId,
      name: name,
      iconEmoji: iconEmoji,
      iconAsset: iconAsset,
      category: category,
      dailyTargetCount: dailyTargetCount,
      timeSlots: timeSlots,
      frequency: frequency,
      weeklyTargetCount: weeklyTargetCount,
      checkInMode: checkInMode,
      startDate: startDate ?? DateTime.now(),
      endDate: endDate,
      checkInRewardType: checkInRewardType,
      checkInRewardValue: checkInRewardValue,
      enableStreakReward: enableStreakReward,
      targetStreakDays: targetStreakDays,
      targetRewardType: targetRewardType,
      targetRewardValue: targetRewardValue,
      rewardValidity: rewardValidity,
      createdAt: DateTime.now(),
      sortOrder: _db.getHabits(childId).length,
    );
    await _db.saveHabit(habit);
    _bump();
    return habit;
  }

  /// 从习惯库模板创建
  Future<Habit> createFromTemplate(String childId, HabitTemplate template) {
    return createHabit(
      childId: childId,
      name: template.name,
      iconEmoji: template.iconEmoji,
      iconAsset: template.iconAsset,
      category: template.category,
      dailyTargetCount: template.defaultDailyCount,
      timeSlots: [template.defaultTimeSlot],
      checkInRewardValue: template.defaultRewardValue,
      targetStreakDays: template.defaultTargetStreakDays,
    );
  }

  /// 更新习惯
  Future<void> updateHabit(Habit habit) async {
    await _db.saveHabit(habit);
    _bump();
  }

  /// 归档习惯（保留历史打卡记录）
  Future<void> archiveHabit(String habitId) async {
    final h = _db.habits.get(habitId) as Habit?;
    if (h == null) return;
    await _db.saveHabit(h.copyWith(isArchived: true));
    _bump();
  }

  /// 删除习惯及其打卡记录
  Future<void> deleteHabit(String habitId) async {
    await _db.deleteHabit(habitId);
    _bump();
  }

  /// 打卡（v1.4.0：提交后进入「待验收」，不再立即发奖励）
  ///
  /// 返回值恒为 0 —— 奖励要等家长在验收队列里点「通过」才发。
  /// 保留返回值是为了不破坏既有调用点。
  Future<int> checkIn(Habit habit) async {
    await _db.checkInHabit(habit);
    _bump();
    return 0;
  }

  /// 家长确认打卡 → 真实发放奖励
  ///
  /// 返回本次发放的奖励总额。
  Future<int> approveCheckIn(String checkInId) async {
    final childId = _ref.read(activeChildIdProvider);
    final reward = await _db.approveCheckIn(checkInId);
    if (childId != null) await _db.refreshAchievements(childId);
    _bump();
    return reward;
  }

  /// 家长驳回打卡（可附原因，不发奖励）
  Future<void> rejectCheckIn(String checkInId, {String? reason}) async {
    await _db.rejectCheckIn(checkInId, reason: reason);
    _bump();
  }

  /// 一键全部通过
  Future<int> approveAllPending() async {
    final childId = _ref.read(activeChildIdProvider);
    if (childId == null) return 0;
    final reward = await _db.approveAllPending(childId);
    await _db.refreshAchievements(childId);
    _bump();
    return reward;
  }

  /// 某习惯最近 7 天打卡情况（对应截图：7 格周视图）
  List<bool> weekStatus(Habit habit) =>
      _db.getHabitWeekStatus(habit.id, habit.childId);

  /// 某习惯今日打卡时间（对应截图：星星牌上的时间）
  DateTime? todayCheckInTime(Habit habit) =>
      _db.getHabitCheckInTime(habit.id, habit.childId, DateTime.now());

  /// 某习惯今日的打卡记录（含待验收 / 已驳回）
  HabitCheckIn? todayRecord(Habit habit) =>
      _db.getCheckInRecord(habit.id, habit.childId, DateTime.now());
}

final habitControllerProvider = Provider<HabitController>((ref) {
  return HabitController(ref.watch(databaseProvider), ref);
});
