import 'package:hive/hive.dart';

import 'enums.dart';


/// 商店商品表（全局配置，**无 childId**）
///
/// 对应截图：「心愿商店 ❤️」（现实奖励）与「怪兽商店 🐾」（宠物食物/皮肤/道具）。
@HiveType(typeId: 8)
class ShopItem extends HiveObject {
  ShopItem({
    required this.id,
    required this.name,
    this.iconEmoji = '🎁',
    this.imageAsset,
    required this.shopType,
    required this.itemType,
    required this.price,
    required this.coinType,
    this.specLabel = '',
    this.unlockLevel = 1,
    this.isEnabled = true,
    this.sortOrder = 0,
  });

  @HiveField(0)
  String id;

  /// 商品名称（对应截图：「玩游戏」）
  @HiveField(1)
  String name;

  /// 图标 Emoji 占位
  @HiveField(2)
  String iconEmoji;

  /// 商品图片资源路径（用户后续提供）
  @HiveField(3)
  String? imageAsset;

  /// 所属商店（心愿商店 / 怪兽商店）
  @HiveField(4)
  ShopType shopType;

  /// 商品类型（食物 / 皮肤 / 道具 / 现实奖励）
  @HiveField(5)
  ShopItemType itemType;

  /// 售价（对应截图：🪙50）
  @HiveField(6)
  int price;

  /// 支付币种
  @HiveField(7)
  RewardType coinType;

  /// 规格说明（对应截图：「30分钟」）
  @HiveField(8)
  String specLabel;

  /// 解锁所需宠物等级
  @HiveField(9)
  int unlockLevel;

  /// 是否上架
  @HiveField(10)
  bool isEnabled;

  /// 排序权重
  @HiveField(11)
  int sortOrder;
}

/// 背包 / 持有记录表（多孩隔离：通过 [childId] 关联 Child）
///
/// 为什么需要：孩子在怪兽商店买了食物、皮肤、道具，**买完得有个地方存**，
/// 否则「喂食消耗食物」无从实现。
@HiveType(typeId: 9)
class InventoryItem extends HiveObject {
  InventoryItem({
    required this.id,
    required this.childId,
    required this.shopItemId,
    required this.itemName,
    this.itemIcon = '🎁',
    required this.itemType,
    this.quantity = 1,
    this.isEquipped = false,
    required this.acquiredAt,
  });

  @HiveField(0)
  String id;

  /// 外键 → Child.id
  @HiveField(1)
  String childId;

  /// 外键 → ShopItem.id
  @HiveField(2)
  String shopItemId;

  /// 冗余商品名，避免商品下架后无法展示
  @HiveField(3)
  String itemName;

  @HiveField(4)
  String itemIcon;

  /// 商品类型
  @HiveField(5)
  ShopItemType itemType;

  /// 持有数量
  @HiveField(6)
  int quantity;

  /// 是否已装备（皮肤的当前使用状态）
  @HiveField(7)
  bool isEquipped;

  /// 获得时间
  @HiveField(8)
  DateTime acquiredAt;

  InventoryItem copyWith({
    String? id,
    String? childId,
    String? shopItemId,
    String? itemName,
    String? itemIcon,
    ShopItemType? itemType,
    int? quantity,
    bool? isEquipped,
    DateTime? acquiredAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      shopItemId: shopItemId ?? this.shopItemId,
      itemName: itemName ?? this.itemName,
      itemIcon: itemIcon ?? this.itemIcon,
      itemType: itemType ?? this.itemType,
      quantity: quantity ?? this.quantity,
      isEquipped: isEquipped ?? this.isEquipped,
      acquiredAt: acquiredAt ?? this.acquiredAt,
    );
  }
}
