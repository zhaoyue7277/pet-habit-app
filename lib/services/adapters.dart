import 'dart:typed_data';

import 'package:hive/hive.dart';

import '../models/models.dart';

/// 全部实体类的 Hive TypeAdapter 手写实现
///
/// 注意：每个 Model 中的 `@HiveField(n)` 编号必须与这里读写顺序严格一致，
/// 且 **编号一经发布不可变更**，只能在末尾追加。

// ===================================================================
// Child -- typeId 0
// ===================================================================
class ChildAdapter extends TypeAdapter<Child> {
  @override
  final int typeId = 0;

  @override
  Child read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Child(
      id: fields[0] as String,
      name: fields[1] as String,
      wishCoin: fields[2] as int? ?? 0,
      petCoin: fields[3] as int? ?? 0,
      currentPetId: fields[4] as String?,
      avatarIndex: fields[5] as int? ?? 0,
      grade: fields[6] as int? ?? 1,
      createdAt: fields[7] as DateTime,
      isActive: fields[8] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, Child obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.wishCoin)
      ..writeByte(3)
      ..write(obj.petCoin)
      ..writeByte(4)
      ..write(obj.currentPetId)
      ..writeByte(5)
      ..write(obj.avatarIndex)
      ..writeByte(6)
      ..write(obj.grade)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.isActive);
  }
}

// ===================================================================
// Pet -- typeId 1
// ===================================================================
class PetAdapter extends TypeAdapter<Pet> {
  @override
  final int typeId = 1;

  @override
  Pet read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Pet(
      id: fields[0] as String,
      childId: fields[1] as String,
      species: PetSpecies.values[fields[2] as int],
      name: fields[3] as String? ?? '',
      level: fields[4] as int? ?? 1,
      exp: fields[5] as int? ?? 0,
      satiety: fields[6] as int? ?? 100,
      mood: fields[7] as int? ?? 100,
      currentSkinId: fields[8] as String? ?? 'default',
      unlockedSkinIds: (fields[9] as List?)?.cast<String>() ?? <String>['default'],
      isBattle: fields[10] as bool? ?? false,
      lastDecayTime: fields[11] as DateTime,
      createdAt: fields[12] as DateTime,
      totalFeedCount: fields[13] as int? ?? 0,
      totalPetCount: fields[14] as int? ?? 0,
      lastFeedTime: fields[15] as DateTime?,
      lastPetTime: fields[16] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Pet obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.childId)
      ..writeByte(2)
      ..write(obj.species.index)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.level)
      ..writeByte(5)
      ..write(obj.exp)
      ..writeByte(6)
      ..write(obj.satiety)
      ..writeByte(7)
      ..write(obj.mood)
      ..writeByte(8)
      ..write(obj.currentSkinId)
      ..writeByte(9)
      ..write(obj.unlockedSkinIds)
      ..writeByte(10)
      ..write(obj.isBattle)
      ..writeByte(11)
      ..write(obj.lastDecayTime)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.totalFeedCount)
      ..writeByte(14)
      ..write(obj.totalPetCount)
      ..writeByte(15)
      ..write(obj.lastFeedTime)
      ..writeByte(16)
      ..write(obj.lastPetTime);
  }
}

// ===================================================================
// Task -- typeId 2
// ===================================================================
class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 2;

  @override
  Task read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Task(
      id: fields[0] as String,
      childId: fields[1] as String,
      title: fields[2] as String,
      description: fields[3] as String? ?? '',
      imagePath: fields[4] as String?,
      subject: fields[5] as String? ?? '其他',
      priority: Priority.values[fields[6] as int? ?? 1],
      difficulty: Difficulty.values[fields[7] as int? ?? 0],
      estimatedMinutes: fields[8] as int?,
      rewardType: RewardType.values[fields[9] as int? ?? 0],
      rewardValue: fields[10] as int? ?? 15,
      status: TaskStatus.values[fields[11] as int? ?? 0],
      repeatFrequency: RepeatFrequency.values[fields[12] as int? ?? 0],
      dueDate: fields[13] as DateTime?,
      needsPomodoro: fields[14] as bool? ?? false,
      parentTaskId: fields[15] as String?,
      startedAt: fields[16] as DateTime?,
      usedSeconds: fields[17] as int? ?? 0,
      completedPomodoros: fields[18] as int? ?? 0,
      createdAt: fields[19] as DateTime,
      completedAt: fields[20] as DateTime?,
      lastCompletedAt: fields[21] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.childId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.imagePath)
      ..writeByte(5)
      ..write(obj.subject)
      ..writeByte(6)
      ..write(obj.priority.index)
      ..writeByte(7)
      ..write(obj.difficulty.index)
      ..writeByte(8)
      ..write(obj.estimatedMinutes)
      ..writeByte(9)
      ..write(obj.rewardType.index)
      ..writeByte(10)
      ..write(obj.rewardValue)
      ..writeByte(11)
      ..write(obj.status.index)
      ..writeByte(12)
      ..write(obj.repeatFrequency.index)
      ..writeByte(13)
      ..write(obj.dueDate)
      ..writeByte(14)
      ..write(obj.needsPomodoro)
      ..writeByte(15)
      ..write(obj.parentTaskId)
      ..writeByte(16)
      ..write(obj.startedAt)
      ..writeByte(17)
      ..write(obj.usedSeconds)
      ..writeByte(18)
      ..write(obj.completedPomodoros)
      ..writeByte(19)
      ..write(obj.createdAt)
      ..writeByte(20)
      ..write(obj.completedAt)
      ..writeByte(21)
      ..write(obj.lastCompletedAt);
  }
}

// ===================================================================
// Habit -- typeId 3
// ===================================================================
class HabitAdapter extends TypeAdapter<Habit> {
  @override
  final int typeId = 3;

  @override
  Habit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Habit(
      id: fields[0] as String,
      childId: fields[1] as String,
      name: fields[2] as String,
      iconEmoji: fields[3] as String? ?? '⭐',
      iconAsset: fields[4] as String?,
      category: HabitCategory.values[fields[5] as int? ?? 0],
      dailyTargetCount: fields[6] as int? ?? 1,
      timeSlots: ((fields[7] as List?) ?? const [0])
          .map((e) => TimeSlot.values[e as int])
          .toList(),
      frequency: HabitFrequency.values[fields[8] as int? ?? 0],
      weeklyTargetCount: fields[9] as int? ?? 7,
      checkInMode: CheckInMode.values[fields[10] as int? ?? 0],
      startDate: fields[11] as DateTime,
      endDate: fields[12] as DateTime?,
      checkInRewardType: RewardType.values[fields[13] as int? ?? 0],
      checkInRewardValue: fields[14] as int? ?? 10,
      enableStreakReward: fields[15] as bool? ?? true,
      targetStreakDays: fields[16] as int? ?? 14,
      targetRewardType: RewardType.values[fields[17] as int? ?? 1],
      targetRewardValue: fields[18] as int? ?? 50,
      rewardValidity: RewardValidity.values[fields[19] as int? ?? 0],
      currentStreakDays: fields[20] as int? ?? 0,
      bestStreakDays: fields[21] as int? ?? 0,
      lastCheckInTime: fields[22] as DateTime?,
      lastStreakRewardAt: fields[23] as DateTime?,
      isArchived: fields[24] as bool? ?? false,
      createdAt: fields[25] as DateTime,
      sortOrder: fields[26] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, Habit obj) {
    writer
      ..writeByte(27)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.childId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.iconEmoji)
      ..writeByte(4)
      ..write(obj.iconAsset)
      ..writeByte(5)
      ..write(obj.category.index)
      ..writeByte(6)
      ..write(obj.dailyTargetCount)
      ..writeByte(7)
      ..write(obj.timeSlots.map((e) => e.index).toList())
      ..writeByte(8)
      ..write(obj.frequency.index)
      ..writeByte(9)
      ..write(obj.weeklyTargetCount)
      ..writeByte(10)
      ..write(obj.checkInMode.index)
      ..writeByte(11)
      ..write(obj.startDate)
      ..writeByte(12)
      ..write(obj.endDate)
      ..writeByte(13)
      ..write(obj.checkInRewardType.index)
      ..writeByte(14)
      ..write(obj.checkInRewardValue)
      ..writeByte(15)
      ..write(obj.enableStreakReward)
      ..writeByte(16)
      ..write(obj.targetStreakDays)
      ..writeByte(17)
      ..write(obj.targetRewardType.index)
      ..writeByte(18)
      ..write(obj.targetRewardValue)
      ..writeByte(19)
      ..write(obj.rewardValidity.index)
      ..writeByte(20)
      ..write(obj.currentStreakDays)
      ..writeByte(21)
      ..write(obj.bestStreakDays)
      ..writeByte(22)
      ..write(obj.lastCheckInTime)
      ..writeByte(23)
      ..write(obj.lastStreakRewardAt)
      ..writeByte(24)
      ..write(obj.isArchived)
      ..writeByte(25)
      ..write(obj.createdAt)
      ..writeByte(26)
      ..write(obj.sortOrder);
  }
}

// ===================================================================
// HabitCheckIn -- typeId 4
// ===================================================================
class HabitCheckInAdapter extends TypeAdapter<HabitCheckIn> {
  @override
  final int typeId = 4;

  @override
  HabitCheckIn read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    // ---------- v1.4.0 旧数据迁移 ----------
    //
    // v1.3.0 及之前只写了 0~4 五个字段（没有验收状态）。
    // 字段 27（verifyStatusRaw）缺失 ⇒ 这是旧记录 ⇒ 标记 isLegacy = true，
    // 让 `HabitCheckIn.verifyStatus` 把它视为「已通过」。
    //
    // 为什么不直接默认 approved？因为若将来真有新记录漏写该字段，
    // 会被误认为「已通过」而白送奖励。isLegacy 是显式标记，语义更准。
    final hasVerifyField = fields.containsKey(27);
    final rawStatus = fields[27] as int?;

    return HabitCheckIn(
      id: fields[0] as String,
      childId: fields[1] as String,
      habitId: fields[2] as String,
      checkInTime: fields[3] as DateTime,
      dateKey: fields[4] as String,
      verifyStatusRaw: rawStatus,
      verifiedAt: fields[28] as DateTime?,
      rejectReason: fields[29] as String?,
      rewardGiven: fields[30] as bool? ?? false,
      // 旧记录：没有状态字段 ⇒ 当时是「点了即发」，等价于已通过
      isLegacy: (fields[31] as bool?) ?? !hasVerifyField,
    );
  }

  @override
  void write(BinaryWriter writer, HabitCheckIn obj) {
    // 动态字段数：新记录写 10 个字段（0~4 + 27~31），旧记录若
    // 从未升级过也会被升级写入 —— 这是有意的，让数据格式尽快统一。
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.childId)
      ..writeByte(2)
      ..write(obj.habitId)
      ..writeByte(3)
      ..write(obj.checkInTime)
      ..writeByte(4)
      ..write(obj.dateKey)
      ..writeByte(27)
      ..write(obj.verifyStatusRaw)
      ..writeByte(28)
      ..write(obj.verifiedAt)
      ..writeByte(29)
      ..write(obj.rejectReason)
      ..writeByte(30)
      ..write(obj.rewardGiven)
      ..writeByte(31)
      ..write(obj.isLegacy);
  }
}

// ===================================================================
// ExchangeLog -- typeId 5
// ===================================================================
class ExchangeLogAdapter extends TypeAdapter<ExchangeLog> {
  @override
  final int typeId = 5;

  @override
  ExchangeLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExchangeLog(
      id: fields[0] as String,
      childId: fields[1] as String,
      itemName: fields[2] as String,
      itemIcon: fields[3] as String? ?? '🎁',
      coinType: RewardType.values[fields[4] as int? ?? 0],
      costCoin: fields[5] as int? ?? 0,
      exchangeTime: fields[6] as DateTime,
      status: ExchangeStatus.values[fields[7] as int? ?? 0],
      shopItemId: fields[8] as String?,
      approvedAt: fields[9] as DateTime?,
      note: fields[10] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, ExchangeLog obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.childId)
      ..writeByte(2)
      ..write(obj.itemName)
      ..writeByte(3)
      ..write(obj.itemIcon)
      ..writeByte(4)
      ..write(obj.coinType.index)
      ..writeByte(5)
      ..write(obj.costCoin)
      ..writeByte(6)
      ..write(obj.exchangeTime)
      ..writeByte(7)
      ..write(obj.status.index)
      ..writeByte(8)
      ..write(obj.shopItemId)
      ..writeByte(9)
      ..write(obj.approvedAt)
      ..writeByte(10)
      ..write(obj.note);
  }
}

// ===================================================================
// AchievementDef -- typeId 6
// ===================================================================
class AchievementDefAdapter extends TypeAdapter<AchievementDef> {
  @override
  final int typeId = 6;

  @override
  AchievementDef read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AchievementDef(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      category: AchievementCategory.values[fields[3] as int? ?? 0],
      iconEmoji: fields[4] as String? ?? '🏅',
      conditionType: fields[5] as String,
      conditionValue: fields[6] as int? ?? 1,
      rewardType: RewardType.values[fields[7] as int? ?? 0],
      rewardValue: fields[8] as int? ?? 20,
      sortOrder: fields[9] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, AchievementDef obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.category.index)
      ..writeByte(4)
      ..write(obj.iconEmoji)
      ..writeByte(5)
      ..write(obj.conditionType)
      ..writeByte(6)
      ..write(obj.conditionValue)
      ..writeByte(7)
      ..write(obj.rewardType.index)
      ..writeByte(8)
      ..write(obj.rewardValue)
      ..writeByte(9)
      ..write(obj.sortOrder);
  }
}

// ===================================================================
// ChildAchievement -- typeId 7
// ===================================================================
class ChildAchievementAdapter extends TypeAdapter<ChildAchievement> {
  @override
  final int typeId = 7;

  @override
  ChildAchievement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChildAchievement(
      id: fields[0] as String,
      childId: fields[1] as String,
      achievementId: fields[2] as String,
      isUnlocked: fields[3] as bool? ?? false,
      unlockedAt: fields[4] as DateTime?,
      currentProgress: fields[5] as int? ?? 0,
      isRewardClaimed: fields[6] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, ChildAchievement obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.childId)
      ..writeByte(2)
      ..write(obj.achievementId)
      ..writeByte(3)
      ..write(obj.isUnlocked)
      ..writeByte(4)
      ..write(obj.unlockedAt)
      ..writeByte(5)
      ..write(obj.currentProgress)
      ..writeByte(6)
      ..write(obj.isRewardClaimed);
  }
}

// ===================================================================
// ShopItem -- typeId 8
// ===================================================================
class ShopItemAdapter extends TypeAdapter<ShopItem> {
  @override
  final int typeId = 8;

  @override
  ShopItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ShopItem(
      id: fields[0] as String,
      name: fields[1] as String,
      iconEmoji: fields[2] as String? ?? '🎁',
      imageAsset: fields[3] as String?,
      shopType: ShopType.values[fields[4] as int? ?? 0],
      itemType: ShopItemType.values[fields[5] as int? ?? 0],
      price: fields[6] as int? ?? 0,
      coinType: RewardType.values[fields[7] as int? ?? 0],
      specLabel: fields[8] as String? ?? '',
      unlockLevel: fields[9] as int? ?? 1,
      isEnabled: fields[10] as bool? ?? true,
      sortOrder: fields[11] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, ShopItem obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.iconEmoji)
      ..writeByte(3)
      ..write(obj.imageAsset)
      ..writeByte(4)
      ..write(obj.shopType.index)
      ..writeByte(5)
      ..write(obj.itemType.index)
      ..writeByte(6)
      ..write(obj.price)
      ..writeByte(7)
      ..write(obj.coinType.index)
      ..writeByte(8)
      ..write(obj.specLabel)
      ..writeByte(9)
      ..write(obj.unlockLevel)
      ..writeByte(10)
      ..write(obj.isEnabled)
      ..writeByte(11)
      ..write(obj.sortOrder);
  }
}

// ===================================================================
// InventoryItem -- typeId 9
// ===================================================================
class InventoryItemAdapter extends TypeAdapter<InventoryItem> {
  @override
  final int typeId = 9;

  @override
  InventoryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InventoryItem(
      id: fields[0] as String,
      childId: fields[1] as String,
      shopItemId: fields[2] as String,
      itemName: fields[3] as String,
      itemIcon: fields[4] as String? ?? '🎁',
      itemType: ShopItemType.values[fields[5] as int? ?? 0],
      quantity: fields[6] as int? ?? 1,
      isEquipped: fields[7] as bool? ?? false,
      acquiredAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, InventoryItem obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.childId)
      ..writeByte(2)
      ..write(obj.shopItemId)
      ..writeByte(3)
      ..write(obj.itemName)
      ..writeByte(4)
      ..write(obj.itemIcon)
      ..writeByte(5)
      ..write(obj.itemType.index)
      ..writeByte(6)
      ..write(obj.quantity)
      ..writeByte(7)
      ..write(obj.isEquipped)
      ..writeByte(8)
      ..write(obj.acquiredAt);
  }
}

// ===================================================================
// HabitTemplate -- typeId 10
// ===================================================================
class HabitTemplateAdapter extends TypeAdapter<HabitTemplate> {
  @override
  final int typeId = 10;

  @override
  HabitTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HabitTemplate(
      id: fields[0] as String,
      name: fields[1] as String,
      category: HabitCategory.values[fields[2] as int? ?? 0],
      iconEmoji: fields[3] as String? ?? '⭐',
      iconAsset: fields[4] as String?,
      defaultDailyCount: fields[5] as int? ?? 1,
      defaultTimeSlot: TimeSlot.values[fields[6] as int? ?? 0],
      defaultRewardValue: fields[7] as int? ?? 10,
      defaultTargetStreakDays: fields[8] as int? ?? 14,
      sortOrder: fields[9] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, HabitTemplate obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.category.index)
      ..writeByte(3)
      ..write(obj.iconEmoji)
      ..writeByte(4)
      ..write(obj.iconAsset)
      ..writeByte(5)
      ..write(obj.defaultDailyCount)
      ..writeByte(6)
      ..write(obj.defaultTimeSlot.index)
      ..writeByte(7)
      ..write(obj.defaultRewardValue)
      ..writeByte(8)
      ..write(obj.defaultTargetStreakDays)
      ..writeByte(9)
      ..write(obj.sortOrder);
  }
}

// ===================================================================
// PetDialogue -- typeId 11
// ===================================================================
class PetDialogueAdapter extends TypeAdapter<PetDialogue> {
  @override
  final int typeId = 11;

  @override
  PetDialogue read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PetDialogue(
      id: fields[0] as String,
      text: fields[1] as String,
      moodState: fields[2] == null
          ? null
          : PetMoodState.values[fields[2] as int],
      triggerType: fields[3] as String? ?? PetDialogueTrigger.idle,
      priority: fields[4] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, PetDialogue obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.moodState?.index)
      ..writeByte(3)
      ..write(obj.triggerType)
      ..writeByte(4)
      ..write(obj.priority);
  }
}

// ===================================================================
// DailyNote -- typeId 12
// ===================================================================
class DailyNoteAdapter extends TypeAdapter<DailyNote> {
  @override
  final int typeId = 12;

  @override
  DailyNote read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyNote(
      id: fields[0] as String,
      childId: fields[1] as String,
      dateKey: fields[2] as String,
      content: fields[3] as String? ?? '',
      moodEmoji: fields[4] as String? ?? '😊',
      updatedAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DailyNote obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.childId)
      ..writeByte(2)
      ..write(obj.dateKey)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(4)
      ..write(obj.moodEmoji)
      ..writeByte(5)
      ..write(obj.updatedAt);
  }
}

// ===================================================================
// PomodoroSession -- typeId 13
// ===================================================================
class PomodoroSessionAdapter extends TypeAdapter<PomodoroSession> {
  @override
  final int typeId = 13;

  @override
  PomodoroSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PomodoroSession(
      id: fields[0] as String,
      childId: fields[1] as String,
      taskId: fields[2] as String?,
      planMinutes: fields[3] as int? ?? 25,
      actualMinutes: fields[4] as int? ?? 0,
      startTime: fields[5] as DateTime,
      endTime: fields[6] as DateTime,
      isCompleted: fields[7] as bool? ?? false,
      isAbandoned: fields[8] as bool? ?? false,
      abandonReason: fields[9] as String? ?? '',
      whiteNoiseType: fields[10] == null
          ? null
          : WhiteNoiseType.values[fields[10] as int],
      rewardType: fields[11] == null
          ? null
          : RewardType.values[fields[11] as int],
      rewardValue: fields[12] as int? ?? 0,
      expGained: fields[13] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, PomodoroSession obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.childId)
      ..writeByte(2)
      ..write(obj.taskId)
      ..writeByte(3)
      ..write(obj.planMinutes)
      ..writeByte(4)
      ..write(obj.actualMinutes)
      ..writeByte(5)
      ..write(obj.startTime)
      ..writeByte(6)
      ..write(obj.endTime)
      ..writeByte(7)
      ..write(obj.isCompleted)
      ..writeByte(8)
      ..write(obj.isAbandoned)
      ..writeByte(9)
      ..write(obj.abandonReason)
      ..writeByte(10)
      ..write(obj.whiteNoiseType?.index)
      ..writeByte(11)
      ..write(obj.rewardType?.index)
      ..writeByte(12)
      ..write(obj.rewardValue)
      ..writeByte(13)
      ..write(obj.expGained);
  }
}

// ===================================================================
// AppSettings -- typeId 14
// ===================================================================
class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 14;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      parentPinHash: fields[0] as String? ?? '',
      parentPinSalt: fields[1] as String? ?? '',
      hasSetPin: fields[2] as bool? ?? false,
      defaultPomodoroMinutes: fields[3] as int? ?? 25,
      breakMinutes: fields[4] as int? ?? 5,
      allowAbandonMinutes: fields[5] as int? ?? 5,
      selectedWhiteNoiseIndex: fields[6] as int?,
      whiteNoiseVolume: fields[7] as double? ?? 0.6,
      autoStartWhiteNoise: fields[8] as bool? ?? false,
      refreshIntervalMinutes: fields[9] as int? ?? 5,
      hasCompletedOnboarding: fields[10] as bool? ?? false,
      lastOpenTime: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.parentPinHash)
      ..writeByte(1)
      ..write(obj.parentPinSalt)
      ..writeByte(2)
      ..write(obj.hasSetPin)
      ..writeByte(3)
      ..write(obj.defaultPomodoroMinutes)
      ..writeByte(4)
      ..write(obj.breakMinutes)
      ..writeByte(5)
      ..write(obj.allowAbandonMinutes)
      ..writeByte(6)
      ..write(obj.selectedWhiteNoiseIndex)
      ..writeByte(7)
      ..write(obj.whiteNoiseVolume)
      ..writeByte(8)
      ..write(obj.autoStartWhiteNoise)
      ..writeByte(9)
      ..write(obj.refreshIntervalMinutes)
      ..writeByte(10)
      ..write(obj.hasCompletedOnboarding)
      ..writeByte(11)
      ..write(obj.lastOpenTime);
  }
}

// ===================================================================
// Recording -- typeId 15（朗读录音）
// ===================================================================
//
// 音频字节以 `Uint8List` 存在 `bytes` 字段（Hive 原生支持二进制），
// 不落地到文件系统 —— 删除记录即释放音频。
class RecordingAdapter extends TypeAdapter<Recording> {
  @override
  final int typeId = 15;

  @override
  Recording read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Recording(
      id: fields[0] as String,
      childId: fields[1] as String,
      habitId: fields[2] as String?,
      dateKey: fields[3] as String,
      durationMs: fields[4] as int? ?? 0,
      // Hive 的 bytes 字段通常读回 Uint8List，但个别路径可能是 List<int>，
      // 这里做一次兼容转换，避免 as Uint8List 直接抛类型错误。
      bytes: _asBytes(fields[5]),
      mimeType: fields[6] as String? ?? 'audio/mp4',
      label: fields[7] as String? ?? '',
      createdAt: fields[8] as DateTime,
    );
  }

  /// 兼容 `Uint8List` / `List<int>` / `null` 三种读回形态
  static Uint8List _asBytes(dynamic raw) {
    if (raw == null) return Uint8List(0);
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    if (raw is List) {
      return Uint8List.fromList(raw.cast<int>());
    }
    return Uint8List(0);
  }

  @override
  void write(BinaryWriter writer, Recording obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.childId)
      ..writeByte(2)
      ..write(obj.habitId)
      ..writeByte(3)
      ..write(obj.dateKey)
      ..writeByte(4)
      ..write(obj.durationMs)
      ..writeByte(5)
      ..write(obj.bytes)
      ..writeByte(6)
      ..write(obj.mimeType)
      ..writeByte(7)
      ..write(obj.label)
      ..writeByte(8)
      ..write(obj.createdAt);
  }
}
