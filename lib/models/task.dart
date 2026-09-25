import 'package:hive/hive.dart';

import 'enums.dart';


/// 任务表
///
/// 多孩隔离：通过 [childId] 关联 Child。
///
/// 核心区分（来自需求）：
/// - [needsPomodoro] = true  → **计时类**任务（做试卷、订正错题），走番茄钟流程；
/// - [needsPomodoro] = false → **检查类**任务（书写工整、早睡早起、做家务），一键勾选完成。
@HiveType(typeId: 2)
class Task extends HiveObject {
  Task({
    required this.id,
    required this.childId,
    required this.title,
    this.description = '',
    this.imagePath,
    this.subject = '其他',
    this.priority = Priority.should,
    this.difficulty = Difficulty.easy,
    this.estimatedMinutes,
    this.rewardType = RewardType.wishCoin,
    this.rewardValue = 15,
    this.status = TaskStatus.todo,
    this.repeatFrequency = RepeatFrequency.once,
    this.dueDate,
    this.needsPomodoro = false,
    this.parentTaskId,
    this.startedAt,
    this.usedSeconds = 0,
    this.completedPomodoros = 0,
    required this.createdAt,
    this.completedAt,
    this.lastCompletedAt,
  });

  @HiveField(0)
  String id;

  /// 外键 → Child.id
  @HiveField(1)
  String childId;

  /// 任务标题（对应截图：「打卡25分钟」「试卷一张」）
  @HiveField(2)
  String title;

  /// 任务描述（可选）
  @HiveField(3)
  String description;

  /// 任务配图本地路径（对应截图：新建任务页的图片按钮）
  @HiveField(4)
  String? imagePath;

  /// 科目（对应截图：语文 / 数学 / 英语 + 自定义）
  @HiveField(5)
  String subject;

  /// 优先级（必须做 / 应该做 / 可以做）
  @HiveField(6)
  Priority priority;

  /// 难度（简单 / 中等 / 困难）
  @HiveField(7)
  Difficulty difficulty;

  /// 预估时长（分钟）；**可为空**，对应截图「不确定」
  @HiveField(8)
  int? estimatedMinutes;

  /// 奖励类型（心愿币 / 宠物币）
  @HiveField(9)
  RewardType rewardType;

  /// 奖励数值
  @HiveField(10)
  int rewardValue;

  /// 任务状态
  @HiveField(11)
  TaskStatus status;

  /// 重复频率（无 / 每天 / 每周 / 每月）
  @HiveField(12)
  RepeatFrequency repeatFrequency;

  /// 截止日期（对应截图：今天 / 明天 / 其他）
  @HiveField(13)
  DateTime? dueDate;

  /// **是否需要番茄钟**（计时类 / 检查类 的区分开关）
  @HiveField(14)
  bool needsPomodoro;

  /// 父任务 ID（对应截图：「分解任务」功能，子任务回指父任务）
  @HiveField(15)
  String? parentTaskId;

  /// 本次开始计时的时间（对应截图：任务卡右下角实时走秒）
  @HiveField(16)
  DateTime? startedAt;

  /// 已用时长（秒）
  @HiveField(17)
  int usedSeconds;

  /// 已完成的番茄钟个数（为将来「一个任务多个番茄钟」预留）
  @HiveField(18)
  int completedPomodoros;

  /// 创建时间
  @HiveField(19)
  DateTime createdAt;

  /// 完成时间
  @HiveField(20)
  DateTime? completedAt;

  /// 上次完成时间（配合重复频率做周期重置）
  @HiveField(21)
  DateTime? lastCompletedAt;

  // ==================== 派生属性 ====================

  /// 是否正在计时中
  bool get isRunning => startedAt != null && status == TaskStatus.doing;

  /// 是否已完成
  bool get isDone => status == TaskStatus.done;

  /// 是否已归档（归档任务不在今日列表展示，但保留历史）
  /// 目前与「已完成的一次性任务」等价，预留独立字段便于后续扩展。
  bool get isArchivedTask =>
      isDone && repeatFrequency == RepeatFrequency.once;

  /// 是否已逾期（有截止时间、未完成、且已过截止时间）
  bool get isOverdue {
    if (isDone || dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  /// 预估时长的展示文案
  String get estimatedLabel =>
      estimatedMinutes == null ? '不确定' : '$estimatedMinutes分钟';

  /// 今日是否应展示此任务（结合重复频率与完成状态判断）
  bool shouldShowOn(DateTime day) {
    // 一次性任务：完成后不再显示
    if (repeatFrequency == RepeatFrequency.once) {
      return !isDone;
    }
    // 每天：始终显示；每周：仅在截止日当天显示（简化处理）
    if (repeatFrequency == RepeatFrequency.daily) return true;
    if (repeatFrequency == RepeatFrequency.weekly) {
      if (dueDate == null) return true;
      return dueDate!.weekday == day.weekday;
    }
    if (repeatFrequency == RepeatFrequency.monthly) {
      if (dueDate == null) return true;
      return dueDate!.day == day.day;
    }
    return true;
  }

  Task copyWith({
    String? id,
    String? childId,
    String? title,
    String? description,
    String? imagePath,
    String? subject,
    Priority? priority,
    Difficulty? difficulty,
    int? estimatedMinutes,
    RewardType? rewardType,
    int? rewardValue,
    TaskStatus? status,
    RepeatFrequency? repeatFrequency,
    DateTime? dueDate,
    bool? needsPomodoro,
    String? parentTaskId,
    DateTime? startedAt,
    int? usedSeconds,
    int? completedPomodoros,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? lastCompletedAt,
    bool clearStartedAt = false,
  }) {
    return Task(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      title: title ?? this.title,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      subject: subject ?? this.subject,
      priority: priority ?? this.priority,
      difficulty: difficulty ?? this.difficulty,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      rewardType: rewardType ?? this.rewardType,
      rewardValue: rewardValue ?? this.rewardValue,
      status: status ?? this.status,
      repeatFrequency: repeatFrequency ?? this.repeatFrequency,
      dueDate: dueDate ?? this.dueDate,
      needsPomodoro: needsPomodoro ?? this.needsPomodoro,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      usedSeconds: usedSeconds ?? this.usedSeconds,
      completedPomodoros: completedPomodoros ?? this.completedPomodoros,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
    );
  }
}
