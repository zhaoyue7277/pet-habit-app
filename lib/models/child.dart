import 'package:hive/hive.dart';


/// 孩子档案表
///
/// 多孩数据隔离的**根表**：其他所有业务表都通过 `childId` 关联到本表，
/// 查询时一律先按 `childId` 过滤，保证数据完全隔离。
@HiveType(typeId: 0)
class Child extends HiveObject {
  Child({
    required this.id,
    required this.name,
    this.wishCoin = 0,
    this.petCoin = 0,
    this.currentPetId,
    this.avatarIndex = 0,
    this.grade = 1,
    required this.createdAt,
    this.isActive = false,
  });

  /// 主键：使用 UUID 而非自增，避免多端合并与迁移时冲突
  @HiveField(0)
  String id;

  /// 孩子名字（对应截图：首页「乐乐」）
  @HiveField(1)
  String name;

  /// 心愿币余额（用于兑换现实奖励）
  @HiveField(2)
  int wishCoin;

  /// 宠物币余额（用于购买宠物食物 / 皮肤 / 道具）
  @HiveField(3)
  int petCoin;

  /// 当前选中的宠物 ID（用于首页展示，可为空表示尚未领养）
  @HiveField(4)
  String? currentPetId;

  /// 头像索引（占位方案：0-7 对应 8 个内置 Emoji 头像）
  @HiveField(5)
  int avatarIndex;

  /// 年级（1-6），用于后续按年龄调整内容难度
  @HiveField(6)
  int grade;

  /// 建档时间（用于「使用天数」类成就统计）
  @HiveField(7)
  DateTime createdAt;

  /// 是否为当前激活的孩子（多孩切换时使用）
  @HiveField(8)
  bool isActive;

  /// 头像 Emoji 占位（后续可替换为图片资源）
  static const List<String> avatarEmojis = [
    '🐱', '🐶', '🐰', '🐼', '🦊', '🐻', '🦁', '🐨',
  ];

  String get avatarEmoji => avatarEmojis[avatarIndex % avatarEmojis.length];

  /// 两份余额的统一读取入口，便于 UI 泛化渲染
  int coinOf(RewardTypeCoin type) =>
      type == RewardTypeCoin.wish ? wishCoin : petCoin;

  Child copyWith({
    String? id,
    String? name,
    int? wishCoin,
    int? petCoin,
    String? currentPetId,
    int? avatarIndex,
    int? grade,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return Child(
      id: id ?? this.id,
      name: name ?? this.name,
      wishCoin: wishCoin ?? this.wishCoin,
      petCoin: petCoin ?? this.petCoin,
      currentPetId: currentPetId ?? this.currentPetId,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      grade: grade ?? this.grade,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// 简化版币种枚举（仅用于 Child 内部读写，避免与 enums.dart 循环依赖）
enum RewardTypeCoin { wish, pet }
