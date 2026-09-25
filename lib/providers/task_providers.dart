import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import 'core_providers.dart';

/// 今日待办任务（已排序，未分组）
final todayTasksProvider = Provider<List<Task>>((ref) {
  final childId = ref.watch(activeChildIdProvider);
  ref.watch(dataRevisionProvider);
  if (childId == null) return [];
  return ref.watch(databaseProvider).getTodayTasks(childId);
});

/// 今日待办任务 —— **按科目分组**
///
/// 对应截图：任务卡上方有橙色的「语文」「英语」科目标签。
/// 返回的 Map 保持科目首次出现的顺序，避免列表跳动。
final tasksBySubjectProvider = Provider<Map<String, List<Task>>>((ref) {
  final tasks = ref.watch(todayTasksProvider);
  final grouped = <String, List<Task>>{};
  for (final t in tasks) {
    grouped.putIfAbsent(t.subject, () => []).add(t);
  }
  return grouped;
});

/// 可进入番茄钟的任务（仅计时类，且未完成）
final pomodoroTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(todayTasksProvider);
  return tasks.where((t) => t.needsPomodoro && !t.isDone).toList();
});

/// 今日学习统计（对应截图首页统计卡）
class TodayStudyStats {
  const TodayStudyStats({
    required this.studiedMinutes,
    required this.estimatedMinutes,
    required this.wishCoinGained,
    required this.petCoinGained,
  });

  /// 已学习时长（分钟）
  final int studiedMinutes;

  /// 预估总时长（分钟）
  final int estimatedMinutes;

  /// 今日获得心愿币
  final int wishCoinGained;

  /// 今日获得宠物币
  final int petCoinGained;

  /// 进度 0.0 - 1.0
  double get progress {
    if (estimatedMinutes <= 0) return 0;
    return (studiedMinutes / estimatedMinutes).clamp(0.0, 1.0);
  }
}

/// 今日学习统计 Provider
///
/// 学习时长只统计**计时类任务**（needsPomodoro = true）的实际番茄钟记录。
final todayStudyStatsProvider = Provider<TodayStudyStats>((ref) {
  final childId = ref.watch(activeChildIdProvider);
  final tasks = ref.watch(todayTasksProvider);
  ref.watch(dataRevisionProvider);
  if (childId == null) {
    return const TodayStudyStats(
      studiedMinutes: 0, estimatedMinutes: 0,
      wishCoinGained: 0, petCoinGained: 0,
    );
  }

  final db = ref.watch(databaseProvider);

  // 预估总时长：仅统计计时类任务
  final estimated = tasks
      .where((t) => t.needsPomodoro)
      .fold(0, (sum, t) => sum + (t.estimatedMinutes ?? 0));

  // 实际学习时长：来自番茄钟会话记录
  final studied = db.getTodayStudyMinutes(childId);

  // 今日收益：从已完成任务与打卡记录中汇总
  final today = DateTime.now();
  final todayKey = HabitCheckIn.keyOf(today);

  var wish = 0;
  var pet = 0;

  for (final t in tasks.where((t) => t.isDone && t.completedAt != null)) {
    if (HabitCheckIn.keyOf(t.completedAt!) != todayKey) continue;
    if (t.rewardType == RewardType.wishCoin) {
      wish += t.rewardValue;
    } else if (t.rewardType == RewardType.petCoin) {
      pet += t.rewardValue;
    }
  }

  // 今日习惯打卡收益
  for (final c in db.checkIns.values.cast<HabitCheckIn>()) {
    if (c.childId != childId || c.dateKey != todayKey) continue;
    final habit = db.habits.get(c.habitId) as Habit?;
    if (habit == null) continue;
    if (habit.checkInRewardType == RewardType.wishCoin) {
      wish += habit.checkInRewardValue;
    } else if (habit.checkInRewardType == RewardType.petCoin) {
      pet += habit.checkInRewardValue;
    }
  }

  return TodayStudyStats(
    studiedMinutes: studied,
    estimatedMinutes: estimated,
    wishCoinGained: wish,
    petCoinGained: pet,
  );
});

/// 任务操作控制器
class TaskController {
  TaskController(this._db, this._ref);

  final DatabaseService _db;
  final Ref _ref;

  void _bump() => _ref.read(dataRevisionProvider.notifier).bump();

  /// 新建任务
  Future<Task> createTask(Task task) async {
    await _db.saveTask(task);
    _bump();
    return task;
  }

  /// 新建任务的便捷方法
  Future<Task> addTask({
    required String childId,
    required String title,
    String description = '',
    String subject = '其他',
    Priority priority = Priority.should,
    Difficulty difficulty = Difficulty.easy,
    int? estimatedMinutes,
    RewardType rewardType = RewardType.wishCoin,
    int rewardValue = 15,
    RepeatFrequency repeatFrequency = RepeatFrequency.once,
    DateTime? dueDate,
    bool needsPomodoro = false,
    String? parentTaskId,
  }) async {
    return createTask(Task(
      id: _db.newId('task_'),
      childId: childId,
      title: title,
      description: description,
      subject: subject,
      priority: priority,
      difficulty: difficulty,
      estimatedMinutes: estimatedMinutes,
      rewardType: rewardType,
      rewardValue: rewardValue,
      repeatFrequency: repeatFrequency,
      dueDate: dueDate,
      needsPomodoro: needsPomodoro,
      parentTaskId: parentTaskId,
      createdAt: DateTime.now(),
    ));
  }

  /// 更新任务
  Future<void> updateTask(Task task) async {
    await _db.saveTask(task);
    _bump();
  }

  /// 删除任务
  Future<void> deleteTask(String taskId) async {
    await _db.deleteTask(taskId);
    _bump();
  }

  /// 检查类任务：直接勾选完成，立即发放奖励
  ///
  /// 返回实际发放的奖励数值。
  Future<int> completeTask(Task task) async {
    final reward = await _db.completeSimpleTask(task);
    _bump();
    return reward;
  }

  /// 开始任务计时（对应截图：任务卡右下角实时走秒）
  Future<void> startTask(Task task) async {
    await _db.saveTask(task.copyWith(
      status: TaskStatus.doing,
      startedAt: DateTime.now(),
    ));
    _bump();
  }

  /// 取消任务计时
  Future<void> stopTask(Task task) async {
    await _db.saveTask(task.copyWith(
      status: TaskStatus.todo,
      clearStartedAt: true,
      usedSeconds: task.usedSeconds +
          (task.startedAt == null
              ? 0
              : DateTime.now().difference(task.startedAt!).inSeconds),
    ));
    _bump();
  }

  /// 重置重复任务（次日恢复未完成状态）
  Future<void> resetTask(Task task) async {
    await _db.resetTask(task);
    _bump();
  }
}

final taskControllerProvider = Provider<TaskController>((ref) {
  return TaskController(ref.watch(databaseProvider), ref);
});
