import 'package:hive/hive.dart';

import 'enums.dart';


/// 宠物表
///
/// 多孩隔离：通过 [childId] 关联 Child。
/// 一个孩子可拥有多只宠物（不同品种），[isBattle] 标记当前出战的那只。
///
/// ⚠️ 饱食度 / 心情值属于「随时间衰减的派生数据」，正确做法是：
///   存储 [lastDecayTime]，读取时调用 [currentSatiety] / [currentMood] 实时计算，
///   **不要靠定时任务写库**，否则 App 未打开时数值会算错。
@HiveType(typeId: 1)
class Pet extends HiveObject {
  Pet({
    required this.id,
    required this.childId,
    required this.species,
    this.name = '',
    this.level = 1,
    this.exp = 0,
    this.satiety = 100,
    this.mood = 100,
    this.currentSkinId = 'default',
    List<String>? unlockedSkinIds,
    this.isBattle = false,
    required this.lastDecayTime,
    required this.createdAt,
    this.totalFeedCount = 0,
    this.totalPetCount = 0,
    this.lastFeedTime,
    this.lastPetTime,
  }) : unlockedSkinIds = unlockedSkinIds ?? <String>['default'];

  @HiveField(0)
  String id;

  /// 外键 → Child.id（多孩隔离关键字段）
  @HiveField(1)
  String childId;

  /// 宠物品种
  @HiveField(2)
  PetSpecies species;

  /// 宠物昵称（用户可自定义，为空则显示品种名）
  @HiveField(3)
  String name;

  /// 等级，默认 1
  @HiveField(4)
  int level;

  /// 当前等级内已积累的经验值（升级时扣除阈值，不回退）
  @HiveField(5)
  int exp;

  /// 饱食度 0-100（存储值 = 上次结算时刻的值）
  @HiveField(6)
  int satiety;

  /// 心情值 0-100（存储值 = 上次结算时刻的值）
  @HiveField(7)
  int mood;

  /// 当前皮肤 ID
  @HiveField(8)
  String currentSkinId;

  /// 已解锁的皮肤 ID 列表
  @HiveField(9)
  List<String> unlockedSkinIds;

  /// 是否出战（当前陪伴宠物）
  @HiveField(10)
  bool isBattle;

  /// 上次衰减结算时间（用于实时计算饱食度 / 心情）
  @HiveField(11)
  DateTime lastDecayTime;

  /// 领养时间
  @HiveField(12)
  DateTime createdAt;

  /// 累计喂食次数（用于成就统计）
  @HiveField(13)
  int totalFeedCount;

  /// 累计抚摸次数（用于成就统计）
  @HiveField(14)
  int totalPetCount;

  /// 上次喂食时间（用于冷却控制）
  @HiveField(15)
  DateTime? lastFeedTime;

  /// 上次抚摸时间（用于冷却控制）
  @HiveField(16)
  DateTime? lastPetTime;

  // ==================== 等级与经验计算 ====================

  /// 升到下一级所需经验：随等级线性增长（Lv1→2 需 100，Lv2→3 需 150...）
  static int expToNextLevel(int level) => 50 + level * 50;

  /// 当前等级的经验进度（0.0 - 1.0），用于经验条展示
  double get expProgress {
    final need = expToNextLevel(level);
    if (need <= 0) return 0;
    return (exp / need).clamp(0.0, 1.0);
  }

  /// 宠物简称（昵称优先）
  String get displayName => name.isNotEmpty ? name : species.label;

  // ==================== 衰减实时计算 ====================

  /// 饱食度每小时下降点数
  static const int satietyDecayPerHour = 4;

  /// 心情值每小时下降点数
  static const int moodDecayPerHour = 3;

  /// 实时计算当前饱食度
  ///
  /// 公式：存储值 - 经过小时数 × 每小时衰减，夹紧到 [0, 100]。
  int currentSatiety([DateTime? now]) {
    final elapsed = (now ?? DateTime.now()).difference(lastDecayTime);
    final decayed = satiety - (elapsed.inMinutes / 60 * satietyDecayPerHour).floor();
    return decayed.clamp(0, 100);
  }

  /// 实时计算当前心情值
  int currentMood([DateTime? now]) {
    final elapsed = (now ?? DateTime.now()).difference(lastDecayTime);
    final decayed = mood - (elapsed.inMinutes / 60 * moodDecayPerHour).floor();
    return decayed.clamp(0, 100);
  }

  /// 根据实时数值推断宠物当前情绪状态（用于选择台词与形象表情）
  PetMoodState moodState([DateTime? now]) {
    final s = currentSatiety(now);
    final m = currentMood(now);
    if (s < 30) return PetMoodState.hungry;
    if (m < 30) return PetMoodState.sad;
    if (m >= 85 && s >= 70) return PetMoodState.happy;
    if (s < 50 || m < 50) return PetMoodState.sleepy;
    return PetMoodState.normal;
  }

  // ==================== 能力解锁 ====================

  /// 当前等级已解锁的能力列表
  List<PetAbility> get unlockedAbilities => PetAbility.unlockedAt(level);

  /// 判断某项能力是否已解锁
  bool hasAbility(PetAbility ability) => level >= ability.unlockLevel;

  /// 该宠物当前是否已解锁指定皮肤
  bool hasSkin(String skinId) => unlockedSkinIds.contains(skinId);

  Pet copyWith({
    String? id,
    String? childId,
    PetSpecies? species,
    String? name,
    int? level,
    int? exp,
    int? satiety,
    int? mood,
    String? currentSkinId,
    List<String>? unlockedSkinIds,
    bool? isBattle,
    DateTime? lastDecayTime,
    DateTime? createdAt,
    int? totalFeedCount,
    int? totalPetCount,
    DateTime? lastFeedTime,
    DateTime? lastPetTime,
  }) {
    return Pet(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      species: species ?? this.species,
      name: name ?? this.name,
      level: level ?? this.level,
      exp: exp ?? this.exp,
      satiety: satiety ?? this.satiety,
      mood: mood ?? this.mood,
      currentSkinId: currentSkinId ?? this.currentSkinId,
      unlockedSkinIds: unlockedSkinIds ?? List<String>.from(this.unlockedSkinIds),
      isBattle: isBattle ?? this.isBattle,
      lastDecayTime: lastDecayTime ?? this.lastDecayTime,
      createdAt: createdAt ?? this.createdAt,
      totalFeedCount: totalFeedCount ?? this.totalFeedCount,
      totalPetCount: totalPetCount ?? this.totalPetCount,
      lastFeedTime: lastFeedTime ?? this.lastFeedTime,
      lastPetTime: lastPetTime ?? this.lastPetTime,
    );
  }
}
