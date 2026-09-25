import 'package:hive/hive.dart';

import 'enums.dart';


/// 兑换记录表
///
/// 多孩隔离：通过 [childId] 关联 Child。
///
/// 流程（对应需求模块 3）：
/// 孩子兑换 → 余额不足则直接宠物卖萌拒绝 → 余额足则家长 PIN 校验
/// → 扣币 → 写入本表（status = pending）→ 家长审批后置为 done。
@HiveType(typeId: 5)
class ExchangeLog extends HiveObject {
  ExchangeLog({
    required this.id,
    required this.childId,
    required this.itemName,
    this.itemIcon = '🎁',
    required this.coinType,
    required this.costCoin,
    required this.exchangeTime,
    this.status = ExchangeStatus.pending,
    this.shopItemId,
    this.approvedAt,
    this.note = '',
  });

  @HiveField(0)
  String id;

  /// 外键 → Child.id
  @HiveField(1)
  String childId;

  /// 兑换物品名称（对应截图：「玩游戏」）
  @HiveField(2)
  String itemName;

  /// 物品图标 Emoji 占位
  @HiveField(3)
  String itemIcon;

  /// 消耗的币种（心愿币 / 宠物币）—— 兼顾两种商店
  @HiveField(4)
  RewardType coinType;

  /// 消耗数量
  @HiveField(5)
  int costCoin;

  /// 兑换时间
  @HiveField(6)
  DateTime exchangeTime;

  /// 状态（待审批 / 已完成 / 已拒绝）
  @HiveField(7)
  ExchangeStatus status;

  /// 关联的商店商品 ID（可为空，表示自定义兑换）
  @HiveField(8)
  String? shopItemId;

  /// 家长审批时间
  @HiveField(9)
  DateTime? approvedAt;

  /// 备注（家长可填写）
  @HiveField(10)
  String note;

  ExchangeLog copyWith({
    String? id,
    String? childId,
    String? itemName,
    String? itemIcon,
    RewardType? coinType,
    int? costCoin,
    DateTime? exchangeTime,
    ExchangeStatus? status,
    String? shopItemId,
    DateTime? approvedAt,
    String? note,
  }) {
    return ExchangeLog(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      itemName: itemName ?? this.itemName,
      itemIcon: itemIcon ?? this.itemIcon,
      coinType: coinType ?? this.coinType,
      costCoin: costCoin ?? this.costCoin,
      exchangeTime: exchangeTime ?? this.exchangeTime,
      status: status ?? this.status,
      shopItemId: shopItemId ?? this.shopItemId,
      approvedAt: approvedAt ?? this.approvedAt,
      note: note ?? this.note,
    );
  }
}
