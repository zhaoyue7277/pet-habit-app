import 'package:hive/hive.dart';

import 'enums.dart';
import 'habit.dart';


/// 习惯库模板表（全局配置，**无 childId**）
///
/// 对应截图「习惯库」：分 学习 / 健康 / 生活 / 兴趣 四个分类，
/// 每个分类下预置若干带插画的习惯（早读、背古诗、整理书桌、篮球……）。
/// 用户从库中选一个 → 复制为属于自己的 Habit 记录。
@HiveType(typeId: 10)
class HabitTemplate extends HiveObject {
  HabitTemplate({
    required this.id,
    required this.name,
    required this.category,
    this.iconEmoji = '⭐',
    this.iconAsset,
    this.defaultDailyCount = 1,
    this.defaultTimeSlot = TimeSlot.anytime,
    this.defaultRewardValue = 10,
    this.defaultTargetStreakDays = 14,
    this.sortOrder = 0,
  });

  @HiveField(0)
  String id;

  /// 习惯名（对应截图：「早读」「错题整理」「帮忙洗碗」）
  @HiveField(1)
  String name;

  /// 所属分类（学习 / 健康 / 生活 / 兴趣）
  @HiveField(2)
  HabitCategory category;

  /// 图标 Emoji 占位（截图中的插画资源需用户后续提供）
  @HiveField(3)
  String iconEmoji;

  /// 图标资源路径（插画），为空则回退 Emoji
  @HiveField(4)
  String? iconAsset;

  /// 默认每日打卡次数
  @HiveField(5)
  int defaultDailyCount;

  /// 默认打卡时段
  @HiveField(6)
  TimeSlot defaultTimeSlot;

  /// 默认打卡奖励
  @HiveField(7)
  int defaultRewardValue;

  /// 默认目标连击天数
  @HiveField(8)
  int defaultTargetStreakDays;

  /// 排序权重
  @HiveField(9)
  int sortOrder;
}

/// 宠物台词表（全局配置，**无 childId**）
///
/// 对应截图首页的对话气泡：「两天没见，本怪兽有点想乐乐～」
/// 台词按 [moodState] 与 [triggerType] 分组，随机挑选一条展示。
@HiveType(typeId: 11)
class PetDialogue extends HiveObject {
  PetDialogue({
    required this.id,
    required this.text,
    this.moodState,
    this.triggerType = PetDialogueTrigger.idle,
    this.priority = 0,
  });

  @HiveField(0)
  String id;

  /// 台词内容，支持 {name} 占位符替换为孩子 / 宠物名
  @HiveField(1)
  String text;

  /// 关联的宠物情绪状态；为空表示通用台词
  @HiveField(2)
  PetMoodState? moodState;

  /// 触发场景
  @HiveField(3)
  String triggerType;

  /// 优先级（越大越优先展示）
  @HiveField(4)
  int priority;
}

/// 宠物台词触发场景常量
class PetDialogueTrigger {
  PetDialogueTrigger._();

  /// 首页闲时随机台词
  static const String idle = 'idle';

  /// 长时间未打开 App（对应截图：两天没见）
  static const String longAbsence = 'long_absence';

  /// 番茄钟完成
  static const String pomodoroDone = 'pomodoro_done';

  /// 番茄钟作废（对应需求：宠物垂头丧气说本次任务失败）
  static const String pomodoroFailed = 'pomodoro_failed';

  /// 打卡成功
  static const String checkInDone = 'check_in_done';

  /// 兑换余额不足（对应需求：心愿币还差一点点哦～）
  static const String coinNotEnough = 'coin_not_enough';

  /// 兑换成功
  static const String exchangeDone = 'exchange_done';

  /// 升级
  static const String levelUp = 'level_up';

  /// 点击宠物（v1.3.0 新增）
  ///
  /// 与 [idle] 的区别：[idle] 是「进入页面时展示的闲时台词」，
  /// [tapPet] 是「用户主动点击宠物后说的话」—— 后者应该更短、更有回应感
  /// （如「哎呀，你戳我干嘛～」），避免每次都念同一套闲时台词。
  static const String tapPet = 'tap_pet';

  // ==================== v1.4.0：打卡验收相关 ====================

  /// 提交打卡、等家长验收时（宠物表达「我陪你一起等」）
  static const String checkInPending = 'check_in_pending';

  /// 家长确认通过（宠物欢呼庆祝）
  static const String checkInApproved = 'check_in_approved';

  /// 家长驳回（宠物安慰，**不责备**）
  ///
  /// 这是「情绪价值」最关键的场景：孩子被驳回本来就沮丧，
  /// 宠物这时应该是「抱抱你」「我们一起再来一次」，
  /// 绝不能是「你怎么又没做好」——那会让孩子把 App 和挫败感绑定。
  static const String checkInRejected = 'check_in_rejected';

  /// 录音防作弊被拦下（如静音、中途切出）
  static const String recordingVoided = 'recording_voided';
}

/// 家长备注 / 打卡日记表（多孩隔离：通过 [childId] 关联 Child）
///
/// 对应需求模块 6：日历本 UI 中家长可为每日写 Note，本地存储。
@HiveType(typeId: 12)
class DailyNote extends HiveObject {
  DailyNote({
    required this.id,
    required this.childId,
    required this.dateKey,
    this.content = '',
    this.moodEmoji = '😊',
    required this.updatedAt,
  });

  @HiveField(0)
  String id;

  /// 外键 → Child.id
  @HiveField(1)
  String childId;

  /// 日期键 `yyyy-MM-dd`
  @HiveField(2)
  String dateKey;

  /// 家长备注内容
  @HiveField(3)
  String content;

  /// 当日心情标记
  @HiveField(4)
  String moodEmoji;

  /// 更新时间
  @HiveField(5)
  DateTime updatedAt;

  DailyNote copyWith({
    String? id,
    String? childId,
    String? dateKey,
    String? content,
    String? moodEmoji,
    DateTime? updatedAt,
  }) {
    return DailyNote(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      dateKey: dateKey ?? this.dateKey,
      content: content ?? this.content,
      moodEmoji: moodEmoji ?? this.moodEmoji,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 番茄钟会话记录表（多孩隔离：通过 [childId] 关联 Child）
///
/// 用于数据报告（学习时长统计）与防作弊审计。
@HiveType(typeId: 13)
class PomodoroSession extends HiveObject {
  PomodoroSession({
    required this.id,
    required this.childId,
    this.taskId,
    required this.planMinutes,
    required this.actualMinutes,
    required this.startTime,
    required this.endTime,
    this.isCompleted = false,
    this.isAbandoned = false,
    this.abandonReason = '',
    this.whiteNoiseType,
    this.rewardType,
    this.rewardValue = 0,
    this.expGained = 0,
  });

  @HiveField(0)
  String id;

  /// 外键 → Child.id
  @HiveField(1)
  String childId;

  /// 关联任务 ID（对应截图：选择任务后进入番茄钟）
  @HiveField(2)
  String? taskId;

  /// 计划时长（分钟）
  @HiveField(3)
  int planMinutes;

  /// 实际时长（分钟）
  @HiveField(4)
  int actualMinutes;

  /// 开始时间
  @HiveField(5)
  DateTime startTime;

  /// 结束时间
  @HiveField(6)
  DateTime endTime;

  /// 是否正常完成
  @HiveField(7)
  bool isCompleted;

  /// 是否作废（切出超过 5 分钟）
  @HiveField(8)
  bool isAbandoned;

  /// 作废原因
  @HiveField(9)
  String abandonReason;

  /// 使用的白噪音类型
  @HiveField(10)
  WhiteNoiseType? whiteNoiseType;

  /// 发放的奖励币种
  @HiveField(11)
  RewardType? rewardType;

  /// 发放的奖励数值
  @HiveField(12)
  int rewardValue;

  /// 宠物获得经验
  @HiveField(13)
  int expGained;

  /// 日期键，便于按日聚合统计学习时长
  String get dateKey => HabitCheckIn.keyOf(endTime);
}
