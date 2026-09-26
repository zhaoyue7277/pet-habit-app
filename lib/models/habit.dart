import 'package:hive/hive.dart';

import 'enums.dart';


/// 习惯表
///
/// 多孩隔离：通过 [childId] 关联 Child。
///
/// 奖励结构拆成两组（对应截图「创建新习惯」页）：
/// 1. **日常打卡奖励**：[checkInRewardType] / [checkInRewardValue]（每次打卡都发）
/// 2. **目标连击奖励**：[targetStreakDays] + [targetRewardValue]（连击达标才发）
@HiveType(typeId: 3)
class Habit extends HiveObject {
  Habit({
    required this.id,
    required this.childId,
    required this.name,
    this.iconEmoji = '⭐',
    this.iconAsset,
    this.category = HabitCategory.study,
    this.dailyTargetCount = 1,
    this.timeSlots = const [TimeSlot.anytime],
    this.frequency = HabitFrequency.daily,
    this.weeklyTargetCount = 7,
    this.checkInMode = CheckInMode.quick,
    required this.startDate,
    this.endDate,
    this.checkInRewardType = RewardType.wishCoin,
    this.checkInRewardValue = 10,
    this.enableStreakReward = true,
    this.targetStreakDays = 14,
    this.targetRewardType = RewardType.petCoin,
    this.targetRewardValue = 50,
    this.rewardValidity = RewardValidity.once,
    this.currentStreakDays = 0,
    this.bestStreakDays = 0,
    this.lastCheckInTime,
    this.lastStreakRewardAt,
    this.isArchived = false,
    required this.createdAt,
    this.sortOrder = 0,
  });

  @HiveField(0)
  String id;

  /// 外键 → Child.id
  @HiveField(1)
  String childId;

  /// 习惯名称（对应截图：「早读」「错题整理」）
  @HiveField(2)
  String name;

  /// 图标 Emoji 占位（后续可替换为插画资源）
  @HiveField(3)
  String iconEmoji;

  /// 图标资源路径（习惯库插画，留空则回退到 Emoji）
  @HiveField(4)
  String? iconAsset;

  /// 习惯分类（学习 / 健康 / 生活 / 兴趣）
  @HiveField(5)
  HabitCategory category;

  /// 每日打卡次数（对应截图：「每日打卡次数 1次」）
  @HiveField(6)
  int dailyTargetCount;

  /// 打卡时段（对应截图：「全天任意」，支持多选）
  @HiveField(7)
  List<TimeSlot> timeSlots;

  /// 打卡频率（对应截图：「每天」）
  @HiveField(8)
  HabitFrequency frequency;

  /// 每周目标次数（当 [frequency] == weekly 时生效）
  @HiveField(9)
  int weeklyTargetCount;

  /// 打卡方式（对应截图：「快速打卡」）
  @HiveField(10)
  CheckInMode checkInMode;

  /// 开始时间（对应截图：「开始时间 9月25日」）
  @HiveField(11)
  DateTime startDate;

  /// 结束时间；为空表示「不限 / 长期」（对应截图）
  @HiveField(12)
  DateTime? endDate;

  /// 日常打卡奖励类型
  @HiveField(13)
  RewardType checkInRewardType;

  /// 日常打卡奖励数值（对应截图：「打卡奖励 10 💛」）
  @HiveField(14)
  int checkInRewardValue;

  /// 是否开启目标奖励（对应截图：「开启目标奖励」开关）
  @HiveField(15)
  bool enableStreakReward;

  /// 目标连击天数（对应截图：「连续打卡 14天」）
  @HiveField(16)
  int targetStreakDays;

  /// 目标奖励类型（对应截图：「奖励类型 心愿币」）
  @HiveField(17)
  RewardType targetRewardType;

  /// 目标奖励数值（对应截图：「50 💛」）
  @HiveField(18)
  int targetRewardValue;

  /// 奖励时效（对应截图：「一次性奖励」）
  @HiveField(19)
  RewardValidity rewardValidity;

  /// 当前连续打卡天数（连击火苗 🔥 数据源）
  @HiveField(20)
  int currentStreakDays;

  /// 历史最长连击天数
  @HiveField(21)
  int bestStreakDays;

  /// 上次打卡时间（用于判断连击是否中断）
  @HiveField(22)
  DateTime? lastCheckInTime;

  /// 上次领取连击目标奖励的时间（配合 [rewardValidity] 防止重复领取）
  @HiveField(23)
  DateTime? lastStreakRewardAt;

  /// 是否已归档（归档后不在列表展示，但保留历史数据）
  @HiveField(24)
  bool isArchived;

  /// 创建时间
  @HiveField(25)
  DateTime createdAt;

  /// 排序权重（越小越靠前）
  @HiveField(26)
  int sortOrder;

  // ==================== 派生属性 ====================

  /// 是否已过结束日期（长期习惯返回 false）
  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  /// 是否已达成目标连击天数
  bool get hasReachedStreakTarget =>
      enableStreakReward && currentStreakDays >= targetStreakDays;

  /// 连击目标奖励是否可领取（已达标 + 未超时效限制）
  bool get canClaimStreakReward {
    if (!hasReachedStreakTarget) return false;
    if (rewardValidity == RewardValidity.once) {
      return lastStreakRewardAt == null;
    }
    return true;
  }

  /// 连击进度（0.0 - 1.0），用于进度条展示
  double get streakProgress {
    if (targetStreakDays <= 0) return 0;
    return (currentStreakDays / targetStreakDays).clamp(0.0, 1.0);
  }

  /// 打卡时段展示文案（多选时用「、」连接）
  String get timeSlotLabel =>
      timeSlots.isEmpty ? '全天任意' : timeSlots.map((e) => e.label).join('、');

  /// 频率展示文案
  String get frequencyLabel => frequency == HabitFrequency.weekly
      ? '每周$weeklyTargetCount次'
      : frequency.label;

  /// 结束时间展示文案
  String get endDateLabel => endDate == null ? '不限' : '${endDate!.month}月${endDate!.day}日';

  Habit copyWith({
    String? id,
    String? childId,
    String? name,
    String? iconEmoji,
    String? iconAsset,
    HabitCategory? category,
    int? dailyTargetCount,
    List<TimeSlot>? timeSlots,
    HabitFrequency? frequency,
    int? weeklyTargetCount,
    CheckInMode? checkInMode,
    DateTime? startDate,
    DateTime? endDate,
    RewardType? checkInRewardType,
    int? checkInRewardValue,
    bool? enableStreakReward,
    int? targetStreakDays,
    RewardType? targetRewardType,
    int? targetRewardValue,
    RewardValidity? rewardValidity,
    int? currentStreakDays,
    int? bestStreakDays,
    DateTime? lastCheckInTime,
    DateTime? lastStreakRewardAt,
    bool? isArchived,
    DateTime? createdAt,
    int? sortOrder,
  }) {
    return Habit(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      name: name ?? this.name,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      iconAsset: iconAsset ?? this.iconAsset,
      category: category ?? this.category,
      dailyTargetCount: dailyTargetCount ?? this.dailyTargetCount,
      timeSlots: timeSlots ?? List<TimeSlot>.from(this.timeSlots),
      frequency: frequency ?? this.frequency,
      weeklyTargetCount: weeklyTargetCount ?? this.weeklyTargetCount,
      checkInMode: checkInMode ?? this.checkInMode,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      checkInRewardType: checkInRewardType ?? this.checkInRewardType,
      checkInRewardValue: checkInRewardValue ?? this.checkInRewardValue,
      enableStreakReward: enableStreakReward ?? this.enableStreakReward,
      targetStreakDays: targetStreakDays ?? this.targetStreakDays,
      targetRewardType: targetRewardType ?? this.targetRewardType,
      targetRewardValue: targetRewardValue ?? this.targetRewardValue,
      rewardValidity: rewardValidity ?? this.rewardValidity,
      currentStreakDays: currentStreakDays ?? this.currentStreakDays,
      bestStreakDays: bestStreakDays ?? this.bestStreakDays,
      lastCheckInTime: lastCheckInTime ?? this.lastCheckInTime,
      lastStreakRewardAt: lastStreakRewardAt ?? this.lastStreakRewardAt,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

/// 习惯打卡记录表
///
/// **这张表是刻意补充的**：如果只在 Habit 表存一个计数字段，
/// 将无法回溯「哪天打了卡」，也就做不了日历视图、周报与 7 格打卡格。
///
/// 多孩隔离：同时带 [childId] 与 [habitId]。
///
/// **v1.4.0 新增「三态验收」**
///
/// 背景：孩子点一下「完成」就立即发奖励，家长完全不知情，孩子可以
/// 秒点全部习惯刷币。现在改为「孩子打卡 → 进入待验收队列 → 家长确认」
/// 的延迟确认机制。
///
/// 三个状态：
/// - [HabitVerifyStatus.pending]  待确认：孩子已打卡，奖励**未发放**
/// - [HabitVerifyStatus.approved] 已确认：家长点头，奖励发放
/// - [HabitVerifyStatus.rejected] 已驳回：家长认为不算数，可写原因，
///   孩子**补做后可重新提交**（同一天允许覆盖 pending 记录）
///
/// ⚠️ 兼容旧数据：v1.3.0 及之前写入的记录没有这些字段，
/// Hive 反序列化时缺失字段会取类型默认值。为了让老记录被正确
/// 视为「已确认」（否则升级后旧打卡会突然变成待验收），
/// 这里用一个「哨兵」字段 [isLegacy] 来区分，详见 [verifyStatus] 的 getter。
@HiveType(typeId: 4)
class HabitCheckIn extends HiveObject {
  HabitCheckIn({
    required this.id,
    required this.childId,
    required this.habitId,
    required this.checkInTime,
    required this.dateKey,
    this.verifyStatusRaw,
    this.verifiedAt,
    this.rejectReason,
    this.rewardGiven = false,
    this.isLegacy = false,
  });

  @HiveField(0)
  String id;

  /// 外键 → Child.id
  @HiveField(1)
  String childId;

  /// 外键 → Habit.id
  @HiveField(2)
  String habitId;

  /// 打卡时间（对应截图：早读卡上的「23:49」）
  @HiveField(3)
  DateTime checkInTime;

  /// 日期键 `yyyy-MM-dd`，用于按天去重与快速查询
  @HiveField(4)
  String dateKey;

  // ==================== v1.4.0 三态验收字段 ====================

  /// 验收状态的持久化值（见 [HabitVerifyStatus]）。
  ///
  /// 用 `int?` 而非枚举本身，是为了让「字段缺失」与「值为 0」
  /// 可区分——Hive 对枚举缺失字段会给到 `values[0]`，
  /// 而 `values[0]` 恰好是 pending，会把旧记录误判为待验收。
  /// 存 int? 时缺失即为 null，配合 [isLegacy] 优雅兜底。
  @HiveField(27)
  int? verifyStatusRaw;

  /// 家长确认 / 驳回的时间
  @HiveField(28)
  DateTime? verifiedAt;

  /// 驳回原因（家长填写，给孩子看）
  @HiveField(29)
  String? rejectReason;

  /// 奖励是否已实际发放。
  ///
  /// **不能靠状态推断**：approved 也分「刚同意还没发」与「已发」两步，
  /// 中间可能因异常中断。用它做幂等标记，避免重复发币。
  @HiveField(30)
  bool rewardGiven;

  /// 是否为 v1.3.0 及之前写入的旧记录。
  ///
  /// 旧记录写入时还没这套机制，语义上等价于「已确认」（当时点即发）。
  /// 新记录一律 false。
  @HiveField(31)
  bool isLegacy;

  // ==================== 派生属性 ====================

  /// 验收状态（对外统一入口）
  HabitVerifyStatus get verifyStatus {
    // 旧数据：没有状态字段，视为已确认（当时是「点了就发」）
    if (isLegacy && verifyStatusRaw == null) {
      return HabitVerifyStatus.approved;
    }
    final raw = verifyStatusRaw;
    if (raw == null) return HabitVerifyStatus.pending;
    if (raw < 0 || raw >= HabitVerifyStatus.values.length) {
      return HabitVerifyStatus.pending;
    }
    return HabitVerifyStatus.values[raw];
  }

  set verifyStatus(HabitVerifyStatus v) => verifyStatusRaw = v.index;

  /// 是否待家长确认
  bool get isPending => verifyStatus == HabitVerifyStatus.pending;

  /// 是否已通过
  bool get isApproved => verifyStatus == HabitVerifyStatus.approved;

  /// 是否被驳回
  bool get isRejected => verifyStatus == HabitVerifyStatus.rejected;

  /// 是否计入「已完成」（已通过或旧数据）
  ///
  /// **重要**：统计打卡率、连击、周报时一律用这个，
  /// 而不是 `isApproved`——否则每天都会漏掉老记录。
  bool get countsAsDone =>
      verifyStatus == HabitVerifyStatus.approved;

  /// 生成标准日期键
  static String keyOf(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  HabitCheckIn copyWith({
    String? id,
    String? childId,
    String? habitId,
    DateTime? checkInTime,
    String? dateKey,
    int? verifyStatusRaw,
    HabitVerifyStatus? verifyStatusValue,
    DateTime? verifiedAt,
    String? rejectReason,
    bool? rewardGiven,
    bool? isLegacy,
    bool clearVerifiedAt = false,
    bool clearRejectReason = false,
  }) {
    return HabitCheckIn(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      habitId: habitId ?? this.habitId,
      checkInTime: checkInTime ?? this.checkInTime,
      dateKey: dateKey ?? this.dateKey,
      verifyStatusRaw:
          verifyStatusValue?.index ?? verifyStatusRaw ?? this.verifyStatusRaw,
      verifiedAt: clearVerifiedAt ? null : (verifiedAt ?? this.verifiedAt),
      rejectReason:
          clearRejectReason ? null : (rejectReason ?? this.rejectReason),
      rewardGiven: rewardGiven ?? this.rewardGiven,
      isLegacy: isLegacy ?? this.isLegacy,
    );
  }
}
