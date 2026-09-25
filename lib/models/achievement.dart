import 'package:hive/hive.dart';

import 'enums.dart';


/// 勋章定义表（全局配置，**无 childId**）
///
/// 为什么拆表：勋章的名称 / 描述 / 解锁条件属于**全局配置**，
/// 所有孩子共用同一套定义。如果和「解锁状态」混在一张表，
/// 每新增一个孩子都要复制全套勋章数据，新增勋章时也要给所有孩子补数据。
/// 因此拆为「定义表 + 进度表」两张。
@HiveType(typeId: 6)
class AchievementDef extends HiveObject {
  AchievementDef({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.iconEmoji = '🏅',
    required this.conditionType,
    required this.conditionValue,
    this.rewardType = RewardType.wishCoin,
    this.rewardValue = 20,
    this.sortOrder = 0,
  });

  @HiveField(0)
  String id;

  /// 勋章名称
  @HiveField(1)
  String name;

  /// 勋章描述
  @HiveField(2)
  String description;

  /// 分类（成长 / 习惯 / 效率 / 知识）
  @HiveField(3)
  AchievementCategory category;

  /// 图标 Emoji 占位
  @HiveField(4)
  String iconEmoji;

  /// 解锁条件类型（见 [AchievementConditionType]）
  @HiveField(5)
  String conditionType;

  /// 解锁条件阈值
  @HiveField(6)
  int conditionValue;

  /// 解锁奖励币种
  @HiveField(7)
  RewardType rewardType;

  /// 解锁奖励数值
  @HiveField(8)
  int rewardValue;

  /// 排序权重
  @HiveField(9)
  int sortOrder;
}

/// 孩子成就进度表（多孩隔离：通过 [childId] 关联 Child）
@HiveType(typeId: 7)
class ChildAchievement extends HiveObject {
  ChildAchievement({
    required this.id,
    required this.childId,
    required this.achievementId,
    this.isUnlocked = false,
    this.unlockedAt,
    this.currentProgress = 0,
    this.isRewardClaimed = false,
  });

  @HiveField(0)
  String id;

  /// 外键 → Child.id
  @HiveField(1)
  String childId;

  /// 外键 → AchievementDef.id
  @HiveField(2)
  String achievementId;

  /// 是否已解锁（对应需求：未解锁灰显、解锁亮起）
  @HiveField(3)
  bool isUnlocked;

  /// 解锁时间
  @HiveField(4)
  DateTime? unlockedAt;

  /// 当前进度值（用于展示进度，如 3/10）
  @HiveField(5)
  int currentProgress;

  /// 奖励是否已领取（防止重复发放）
  @HiveField(6)
  bool isRewardClaimed;

  ChildAchievement copyWith({
    String? id,
    String? childId,
    String? achievementId,
    bool? isUnlocked,
    DateTime? unlockedAt,
    int? currentProgress,
    bool? isRewardClaimed,
  }) {
    return ChildAchievement(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      achievementId: achievementId ?? this.achievementId,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      currentProgress: currentProgress ?? this.currentProgress,
      isRewardClaimed: isRewardClaimed ?? this.isRewardClaimed,
    );
  }
}

/// 成就条件类型常量
///
/// 使用字符串常量而非枚举，便于后续扩展新条件类型而不影响已有数据。
class AchievementConditionType {
  AchievementConditionType._();

  /// 累计完成番茄钟个数
  static const String totalPomodoro = 'total_pomodoro';

  /// 累计完成任务数
  static const String totalTaskDone = 'total_task_done';

  /// 累计习惯打卡次数
  static const String totalCheckIn = 'total_check_in';

  /// 习惯最长连击天数
  static const String maxHabitStreak = 'max_habit_streak';

  /// 累计学习时长（分钟）
  static const String totalStudyMinutes = 'total_study_minutes';

  /// 累计兑换次数
  static const String totalExchange = 'total_exchange';

  /// 宠物最高等级
  static const String maxPetLevel = 'max_pet_level';

  /// 使用天数
  static const String usageDays = 'usage_days';

  /// 累计朗读录音条数（朗读打卡）
  static const String totalRecording = 'total_recording';

  /// 累计有效朗读时长（分钟）
  static const String totalReadingMinutes = 'total_reading_minutes';
}
